require "net/http"
require "json"

class DealAdvisor
  Advice = Data.define(:label, :summary, :source)

  MODEL = ENV.fetch("OPENAI_DEAL_ADVISOR_MODEL", "gpt-5.4-mini")

  def self.call(product)
    new(product).call
  end

  def initialize(product)
    @product = product
  end

  def call
    return heuristic_advice unless ai_enabled?

    ai_advice
  rescue StandardError => e
    Rails.logger.info("[DealAdvisor] Falling back to heuristic advice: #{e.class}: #{e.message}")
    heuristic_advice
  end

  private

  attr_reader :product

  def ai_enabled?
    ENV["OPENAI_API_KEY"].present? && ActiveModel::Type::Boolean.new.cast(ENV["ENABLE_AI_DEAL_ADVICE"])
  end

  def ai_advice
    uri = URI("https://api.openai.com/v1/responses")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch('OPENAI_API_KEY')}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: MODEL,
      input: prompt,
      max_output_tokens: 120
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 4) do |http|
      http.request(request)
    end

    raise "OpenAI request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    text = extract_text(JSON.parse(response.body)).presence
    raise "OpenAI response did not include text" if text.blank?

    Advice.new(label: "AI deal read", summary: text.squish, source: "ai")
  end

  def extract_text(payload)
    return payload["output_text"] if payload["output_text"].present?

    payload.fetch("output", []).flat_map { |item| item.fetch("content", []) }
           .filter_map { |content| content["text"] }
           .join(" ")
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
