# Free-text shopping assistant. Takes a natural-language question from the
# user ("what should I buy under $200?", "show me good headphone deals",
# "anything dropped recently?") plus a snapshot of their watchlist and asks
# an LLM via LlmClient (Gemini → OpenRouter → heuristic) to surface 3
# specific picks from that watchlist with one-line reasoning each.
#
# Graceful degradation: if every provider is unreachable, disabled, or
# returns an unparseable body, we fall back to keyword matching against
# product names + categories so the user still gets a useful answer. The
# view always renders an Answer struct.
class AiAssistant
  Pick   = Data.define(:product, :reason)
  Answer = Data.define(:summary, :picks, :source)

  MAX_PICKS = 3
  MAX_CANDIDATES_FOR_PROMPT = 30

  def self.call(query:, products:)
    new(query: query, products: products).call
  end

  def initialize(query:, products:)
    @query    = query.to_s.strip
    @products = Array(products)
  end

  def call
    return empty_answer if @query.blank?
    return empty_answer if @products.empty?

    return heuristic_answer unless ai_enabled?

    ai_answer
  rescue StandardError => e
    Rails.logger.info("[AiAssistant] Falling back to heuristic: #{e.class}: #{e.message}")
    heuristic_answer
  end

  private

  def ai_enabled?
    LlmClient.enabled?
  end

  def empty_answer
    Answer.new(summary: nil, picks: [], source: "empty")
  end

  def candidates
    @candidates ||= @products.first(MAX_CANDIDATES_FOR_PROMPT).filter_map do |product|
      latest = product.latest_price
      lowest = product.lowest_price
      next if latest.nil?

      {
        product: product,
        name: product.name,
        category: product.category,
        latest: latest.to_f,
        lowest: lowest.to_f,
        target: product.target_price&.to_f,
        # How many prices we've logged. With only one, latest == lowest by
        # definition, so "lowest ever" is meaningless — track this so neither
        # the heuristic nor the AI calls a brand-new product a record low.
        points: product.price_records.size
      }
    end
  end

  # True when we have enough history for "lowest ever" to mean anything.
  def has_history?(candidate)
    candidate[:points].to_i > 1
  end

  def ai_answer
    text = LlmClient.complete(prompt: prompt, max_tokens: 320, temperature: 0.3, request_timeout: 28)
    parsed = parse(text)
    raise "No matchable picks in AI response" if parsed.picks.empty?

    parsed
  end

  def prompt
    lines = candidates.map do |c|
      target_part = c[:target] ? ", target $#{format('%.2f', c[:target])}" : ""
      history_part =
        if has_history?(c)
          ", lowest ever $#{format('%.2f', c[:lowest])}"
        else
          " (only one price logged, no history yet)"
        end
      "- \"#{c[:name]}\" (#{c[:category]}): latest $#{format('%.2f', c[:latest])}#{history_part}#{target_part}"
    end

    <<~PROMPT
      You are a shopping assistant. Answer the user's question using ONLY the products in their watchlist below. Pick the #{MAX_PICKS} most relevant products and explain why each fits the question.

      User question:
      "#{@query}"

      Watchlist:
      #{lines.join("\n")}

      Reply in this EXACT format, no extra commentary outside the structure:
      SUMMARY: <one sentence answering the question at a high level>
      PICK: <product name copied verbatim from the watchlist> | <one short sentence citing real numbers from that product>
      PICK: <product name> | <reason>
      PICK: <product name> | <reason>

      Rules:
      - Do NOT describe a product as a "record low", "lowest ever", or "best price yet" unless it has more than one price logged AND its latest price equals that lowest. A product with only one logged price has no history — never call it a deal on that basis.
      - If the question can't be reasonably answered from the watchlist, return a SUMMARY line that says so and no PICK lines.
      - Never invent products.
    PROMPT
  end

  def parse(text)
    by_name = candidates.index_by { |c| c[:name] }

    summary_line = text[/SUMMARY:\s*(.+)/i, 1]&.strip&.gsub(/\s+/, " ")
    picks = text.scan(/^PICK:\s*(.+?)\s*\|\s*(.+)$/).filter_map do |name, reason|
      candidate = by_name[name.strip]
      next unless candidate

      Pick.new(product: candidate[:product], reason: reason.strip.gsub(/\s+/, " "))
    end.first(MAX_PICKS)

    Answer.new(summary: summary_line, picks: picks, source: "ai")
  end

  # Naive keyword overlap between the query and each product's name +
  # category. Returns the top MAX_PICKS by overlap; if nothing matches,
  # returns the candidates with the biggest savings from peak so the
  # user still sees *something* useful.
  def heuristic_answer
    keywords = @query.downcase.scan(/[a-z0-9$]+/).reject { |w| w.length < 3 || STOPWORDS.include?(w) }
    keyword_set = keywords.to_set

    scored = candidates.map do |c|
      haystack = "#{c[:name]} #{c[:category]}".downcase
      score = keyword_set.count { |k| haystack.include?(k) }
      [ score, c ]
    end

    top = scored.select { |s, _| s.positive? }.sort_by { |s, c| [ -s, c[:latest] ] }.first(MAX_PICKS).map(&:last)

    if top.empty?
      top = candidates.sort_by { |c| c[:latest] }.first(MAX_PICKS)
      summary = "I couldn't directly match your question, so here are the lowest-priced products on your watchlist:"
    else
      summary = "Top #{top.size} #{'match'.pluralize(top.size)} from your watchlist:"
    end

    picks = top.map do |c|
      reason =
        if c[:target] && c[:latest] <= c[:target]
          "Latest $#{format('%.2f', c[:latest])} is at or below your target of $#{format('%.2f', c[:target])}."
        elsif !has_history?(c)
          "Latest $#{format('%.2f', c[:latest])} — only one price logged so far, so no history to compare yet."
        elsif c[:latest] <= c[:lowest] + 0.01
          "Latest $#{format('%.2f', c[:latest])} matches the lowest you've ever seen."
        else
          "Latest $#{format('%.2f', c[:latest])}; lowest recorded $#{format('%.2f', c[:lowest])}."
        end

      Pick.new(product: c[:product], reason: reason)
    end

    Answer.new(summary: summary, picks: picks, source: "local")
  end

  STOPWORDS = %w[
    the and any can you what show give find tell help with this that have for any
    some are best good great cheap cheapest worth recently under over from about
    please now buy item items product products thing things which when where why
  ].to_set
end
