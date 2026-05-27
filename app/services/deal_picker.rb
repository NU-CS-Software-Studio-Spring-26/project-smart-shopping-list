require "net/http"
require "json"

# AI-curated list of the strongest deals from a user's affordable products.
#
# Given a set of products that fit a budget, asks an LLM (OpenRouter, same
# credentials as DealAdvisor) to pick the 3 most worth grabbing right now,
# with one-sentence reasoning per pick that cites real numbers from each
# product's price history.
#
# Returns an array of Pick structs. Falls back to a deterministic heuristic
# (top 3 by absolute savings from the historical peak) if:
#   - OPENROUTER_API_KEY is missing
#   - ENABLE_AI_DEAL_ADVICE is set to "false"
#   - the LLM call times out, errors, or returns an unparseable body
#   - the candidate list is shorter than 2 products
#
# The view never sees a nil — it always gets at least the heuristic picks
# so the panel renders consistently regardless of the AI's state.
class DealPicker
  Pick = Data.define(:product, :reason, :source)

  ENDPOINT      = "https://openrouter.ai/api/v1/chat/completions"
  # Cascade: try the best model first, fall through 429s automatically via
  # OpenRouter's `models` array routing. Final entry is the always-available
  # tiny Liquid model so the AI label fires even under heavy load.
  DEFAULT_MODEL = "google/gemma-4-26b-a4b-it:free,meta-llama/llama-3.3-70b-instruct:free,liquid/lfm-2.5-1.2b-instruct:free"
  MAX_PICKS     = 3
  MAX_CANDIDATES_FOR_PROMPT = 20

  def self.call(products, budget:)
    new(products, budget: budget).call
  end

  def initialize(products, budget:)
    @products = Array(products)
    @budget   = budget.to_f
  end

  def call
    return [] if @products.size < 2

    return heuristic_picks unless ai_enabled?

    ai_picks
  rescue StandardError => e
    Rails.logger.info("[DealPicker] Falling back to heuristic: #{e.class}: #{e.message}")
    heuristic_picks
  end

  private

  def ai_enabled?
    return false if ENV["OPENROUTER_API_KEY"].blank?

    flag = ENV["ENABLE_AI_DEAL_ADVICE"]
    flag.blank? || ActiveModel::Type::Boolean.new.cast(flag)
  end

  def model_list
    raw = ENV["OPENROUTER_MODEL"].presence || DEFAULT_MODEL
    list = raw.split(",").map(&:strip).reject(&:empty?)
    list.empty? ? [ DEFAULT_MODEL.split(",").first ] : list
  end

  def ai_picks
    uri = URI(ENDPOINT)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
    request["Content-Type"]  = "application/json"
    request["HTTP-Referer"]  = ENV.fetch("APP_URL", "https://smart-shoppinglist-6ae31171e85c.herokuapp.com")
    request["X-Title"]       = "PriceTracker"
    request.body = {
      models: model_list,
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 280,
      temperature: 0.2
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 10) do |http|
      http.request(request)
    end

    raise "OpenRouter request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    text = JSON.parse(response.body).dig("choices", 0, "message", "content").to_s.strip
    raise "OpenRouter response did not include text" if text.blank?

    parsed = parse(text)
    raise "Could not match any AI picks to products" if parsed.empty?

    parsed
  end

  # Build a short, structured snapshot of each candidate so the model has
  # actual numbers to cite. We cap at MAX_CANDIDATES_FOR_PROMPT so the
  # prompt stays small on large watchlists.
  def candidates
    @candidates ||= @products.first(MAX_CANDIDATES_FOR_PROMPT).map do |product|
      records = product.price_records.order(recorded_at: :desc).limit(20).to_a
      prices  = records.map { |r| r.price.to_f }
      next if prices.empty?

      latest  = prices.first
      lowest  = prices.min
      peak    = prices.max
      latest_store = records.first.store_name
      target  = product.target_price&.to_f

      {
        product: product,
        name: product.name,
        category: product.category,
        latest: latest,
        latest_store: latest_store,
        lowest: lowest,
        peak: peak,
        savings_from_peak: (peak - latest).round(2),
        target: target,
        target_hit: target.present? && latest <= target
      }
    end.compact
  end

  def prompt
    lines = candidates.map do |c|
      target_part = c[:target] ? ", target $#{format('%.2f', c[:target])}#{' (HIT)' if c[:target_hit]}" : ""
      "- \"#{c[:name]}\" (#{c[:category]}): latest $#{format('%.2f', c[:latest])} @ #{c[:latest_store] || 'unknown'}; lowest ever $#{format('%.2f', c[:lowest])}; peak $#{format('%.2f', c[:peak])}; saved $#{format('%.2f', c[:savings_from_peak])} from peak#{target_part}"
    end

    <<~PROMPT
      You are a shopping deal curator. From this watchlist of products that fit the user's $#{format('%.2f', @budget)} budget, pick the #{MAX_PICKS} BEST deals worth grabbing right now.

      Prefer products where the latest price is near or at the lowest-ever recorded price, the savings from the historical peak are large, or the target price has been hit.

      Watchlist:
      #{lines.join("\n")}

      Reply with exactly #{MAX_PICKS} picks, one per line, in this EXACT format:
      PICK: <product name copied verbatim from the watchlist> | <one short sentence citing real numbers from that product>

      Do not invent products. Do not invent prices. Do not add commentary outside the PICK lines.
    PROMPT
  end

  # Robust parser: matches "PICK: <name> | <reason>" lines and looks up
  # the product by exact name in the candidate set. Tolerates extra prose
  # before/after the PICK lines.
  def parse(text)
    by_name = candidates.index_by { |c| c[:name] }

    text.scan(/^PICK:\s*(.+?)\s*\|\s*(.+)$/).filter_map do |name, reason|
      candidate = by_name[name.strip]
      next unless candidate

      Pick.new(product: candidate[:product], reason: reason.strip.gsub(/\s+/, " "), source: "ai")
    end.first(MAX_PICKS)
  end

  # Fallback: rank by absolute dollar savings from peak, then by latest
  # price. Always returns up to MAX_PICKS items so the UI never goes blank.
  def heuristic_picks
    ranked = candidates.sort_by { |c| [ -c[:savings_from_peak], c[:latest] ] }.first(MAX_PICKS)

    ranked.map do |c|
      reason =
        if c[:target_hit]
          "Latest $#{format('%.2f', c[:latest])} is at or below your target — buy now."
        elsif c[:latest] <= c[:lowest] + 0.01
          "Latest $#{format('%.2f', c[:latest])} matches the lowest you've ever seen."
        elsif c[:savings_from_peak] > 0
          "Latest $#{format('%.2f', c[:latest])} is $#{format('%.2f', c[:savings_from_peak])} below the historical peak of $#{format('%.2f', c[:peak])}."
        else
          "Currently $#{format('%.2f', c[:latest])} at #{c[:latest_store] || 'unknown'}."
        end

      Pick.new(product: c[:product], reason: reason, source: "local")
    end
  end
end
