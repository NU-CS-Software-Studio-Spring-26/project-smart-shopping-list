# AI-powered "should I buy now?" advisor.
#
# Reads a product's price history and asks an LLM (via LlmClient, which
# routes through Gemini → OpenRouter → heuristic) for one of three takes:
# buy now, wait, or watch. When every provider is unreachable / disabled /
# misbehaving the service falls back to a deterministic heuristic that
# compares the latest price to the lowest seen and a recent average. Either
# way the controller always gets a usable Advice struct — the product page
# never breaks.
class DealAdvisor
  Advice = Data.define(:label, :summary, :source)

  CACHE_TTL = 6.hours

  def self.call(product)
    new(product).call
  end

  def initialize(product)
    @product = product
  end

  def call
    # The OpenRouter free tier rate-limits aggressively. If we successfully
    # got an AI answer recently, reuse it instead of burning another call
    # and falling back to the heuristic. Heuristic responses are not cached
    # — they're cheap, and we want each fresh page view to retry the AI.
    cached = cached_ai_advice
    return cached if cached

    return heuristic_advice unless ai_enabled?

    advice = ai_advice
    persist(advice)
    advice
  rescue StandardError => e
    Rails.logger.info("[DealAdvisor] Falling back to heuristic advice: #{e.class}: #{e.message}")
    heuristic_advice
  end

  private

  attr_reader :product

  def ai_enabled?
    LlmClient.enabled?
  end

  # Return a cached AI advice struct iff it exists, is fresh (within
  # CACHE_TTL), and the product hasn't logged a new price since it was
  # generated. The third check matters: a new price record changes the
  # signal, so we invalidate stale advice.
  def cached_ai_advice
    return nil unless product.respond_to?(:advisor_generated_at)
    return nil if product.advisor_source != "ai"
    return nil if product.advisor_summary.blank?
    return nil if product.advisor_generated_at.blank?
    return nil if product.advisor_generated_at < CACHE_TTL.ago

    latest_record = product.price_records.order(recorded_at: :desc).limit(1).first
    return nil if latest_record && latest_record.recorded_at > product.advisor_generated_at

    Advice.new(label: "AI deal read", summary: product.advisor_summary, source: "ai")
  end

  def persist(advice)
    return unless advice.source == "ai"
    return unless product.respond_to?(:advisor_summary)

    product.update_columns(
      advisor_summary:      advice.summary,
      advisor_source:       advice.source,
      advisor_generated_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.info("[DealAdvisor] cache persist failed: #{e.class}: #{e.message}")
  end

  def ai_advice
    text = LlmClient.complete(prompt: prompt, max_tokens: 160, temperature: 0.2, request_timeout: 22)
    Advice.new(label: "AI deal read", summary: text.squish, source: "ai")
  end

  def prompt
    records = product.price_records.order(recorded_at: :desc).limit(12)
    prices = records.map { |record| "$#{format('%.2f', record.price)} at #{record.store_name} on #{record.recorded_at.to_date}" }

    <<~PROMPT
      You are a concise shopping deal advisor. Recommend whether to buy now or wait.
      Product: #{product.name}
      Category: #{product.category}
      Target price: #{product.target_price ? "$#{format('%.2f', product.target_price)}" : "not set"}
      Recent price records:
      #{prices.join("\n")}

      Reply in one sentence under 35 words. Do not invent stores or prices.
    PROMPT
  end

  def heuristic_advice
    records = product.price_records.order(recorded_at: :asc).to_a
    return Advice.new(label: "Deal read", summary: "Log at least two prices to get a buy-or-wait recommendation.", source: "local") if records.size < 2

    latest = records.last.price.to_f
    lowest = records.map { |record| record.price.to_f }.min
    average = records.sum { |record| record.price.to_f } / records.size
    target = product.target_price&.to_f

    if target && latest <= target
      summary = "Buy now: the latest price is at or below your target price."
    elsif latest <= lowest
      summary = "Strong deal: this matches the lowest price you have recorded."
    elsif latest <= average * 0.92
      summary = "Good deal: the latest price is meaningfully below this product's average."
    elsif latest > average * 1.08
      summary = "Wait if you can: the latest price is above this product's usual range."
    else
      summary = "Fair price: the latest price is close to the product's recent average."
    end

    Advice.new(label: "Smart deal read", summary: summary, source: "local")
  end
end
