require "net/http"
require "json"

# Provider-chain wrapper for the LLM calls used by DealAdvisor, DealPicker
# and AiAssistant. Tries each configured provider in order and returns the
# first 200-response body text, raising LlmClient::Error if none succeed.
#
# Providers (in cascade order):
#   1. Google AI Studio (Gemini API) — generous free quota (≈ 1500 RPD on
#      gemini-2.5-flash, even higher on the gemma-* tiers). Enabled by
#      setting GEMINI_API_KEY.
#   2. OpenRouter — kept as a secondary because we already had it wired up
#      and its model cascade is independently useful. Enabled by
#      OPENROUTER_API_KEY.
#
# Each provider can be disabled / model-overridden via env. ENABLE_AI_DEAL_ADVICE
# globally gates the whole thing (set to "false" to force heuristic everywhere).
#
# Gemma's "thinking" output is wrapped in <thought>…</thought>. We strip
# that here so callers always get the post-thought response text.
class LlmClient
  class Error < StandardError; end

  GEMINI_ENDPOINT     = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
  OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"

  # Gemini free tier is per-model, ~20 RPM each. Listing two models gives us
  # ~40 RPM headroom on bursty traffic. Flash-lite first because it's the
  # fastest; Gemma-26B is the higher-quality fallback when Flash-lite is
  # temporarily throttled.
  GEMINI_DEFAULT_MODEL     = "gemini-2.5-flash-lite,gemma-4-26b-a4b-it"
  OPENROUTER_DEFAULT_MODEL = "google/gemma-4-26b-a4b-it:free,meta-llama/llama-3.3-70b-instruct:free,liquid/lfm-2.5-1.2b-instruct:free"

  THOUGHT_RE = /<thought>.*?<\/thought>/m

  # Default read_timeout of 25s — Gemma 4 26B routinely takes 8–15s end-to-end,
  # especially on the larger AiAssistant prompts. Callers can raise this further
  # if they're rendering inline on a page that already has heavy work.
  def self.complete(prompt:, max_tokens: 256, temperature: 0.2, request_timeout: 25)
    new(prompt: prompt, max_tokens: max_tokens, temperature: temperature, request_timeout: request_timeout).complete
  end

  def self.enabled?
    return false if ENV.fetch("ENABLE_AI_DEAL_ADVICE", "true").downcase == "false"

    ENV["GEMINI_API_KEY"].present? || ENV["OPENROUTER_API_KEY"].present?
  end

  def initialize(prompt:, max_tokens:, temperature:, request_timeout:)
    @prompt = prompt
    @max_tokens = max_tokens
    @temperature = temperature
    @request_timeout = request_timeout
  end

  def complete
    last_error = nil

    providers.each do |provider|
      next unless provider[:enabled]

      begin
        text = strip_thought(call_provider(provider))
        return text if text.present?

        # A reasoning model (e.g. Gemma) can spend its whole token budget on a
        # <thought> block, leaving nothing once we strip it. That's unusable —
        # record it and fall through to the next provider instead of returning
        # "" to the caller (which silently skipped the OpenRouter fallback).
        last_error = Error.new("#{provider[:name]} returned no usable text after thought-stripping")
        Rails.logger.info("[LlmClient] #{provider[:name]} returned empty after thought-stripping")
      rescue StandardError => e
        last_error = e
        Rails.logger.info("[LlmClient] #{provider[:name]} failed: #{e.class}: #{e.message}")
      end
    end

    raise Error, "all providers failed: #{last_error&.message || 'no provider enabled'}"
  end

  private

  def providers
    [
      {
        name: "gemini",
        enabled: ENV["GEMINI_API_KEY"].present?,
        endpoint: GEMINI_ENDPOINT,
        api_key: ENV["GEMINI_API_KEY"],
        models: gemini_models
      },
      {
        name: "openrouter",
        enabled: ENV["OPENROUTER_API_KEY"].present?,
        endpoint: OPENROUTER_ENDPOINT,
        api_key: ENV["OPENROUTER_API_KEY"],
        models: openrouter_models,
        extra_headers: {
          "HTTP-Referer" => ENV.fetch("APP_URL", "https://smart-shoppinglist-6ae31171e85c.herokuapp.com"),
          "X-Title"      => "PriceTracker"
        }
      }
    ]
  end

  def gemini_models
    raw = ENV["GEMINI_MODEL"].presence || GEMINI_DEFAULT_MODEL
    raw.split(",").map(&:strip).reject(&:empty?)
  end

  def openrouter_models
    raw = ENV["OPENROUTER_MODEL"].presence || OPENROUTER_DEFAULT_MODEL
    raw.split(",").map(&:strip).reject(&:empty?)
  end

  # Both Gemini and OpenRouter accept OpenAI-style chat completion bodies.
  # OpenRouter supports a `models` array natively, so its whole cascade
  # counts as one HTTP request. Gemini only takes a single `model`, so when
  # GEMINI_MODEL contains multiple comma-separated models we walk them one
  # at a time — but the per-model timeout is **halved** so the worst-case
  # Gemini budget stays under @request_timeout. Without this cap, two
  # serial Gemini attempts at the full read_timeout would already exceed
  # Heroku's 30-second router limit before OpenRouter even gets a chance.
  # OpenRouter accepts a `models:` array and handles fallback itself, so its
  # whole cascade is one HTTP request. Gemini only takes a single `model`, so
  # we iterate. The first Gemini model gets a short budget (it's usually fast
  # and we want to fail through to the next quickly if it 429s); the last
  # model gets the remainder so a slow-but-available model can still complete.
  def call_provider(provider)
    if provider[:name] == "openrouter"
      post_chat(provider, body: {
        models: provider[:models],
        messages: [ { role: "user", content: @prompt } ],
        max_tokens: @max_tokens,
        temperature: @temperature
      }, read_timeout: @request_timeout)
    else
      models = provider[:models]
      last = nil
      models.each_with_index do |model, i|
        # Fast-fail every model except the last so we don't burn the whole
        # budget waiting on a single slow model when a fallback is ready.
        is_last = (i == models.size - 1)
        budget = is_last ? @request_timeout : [ (@request_timeout * 0.35).to_i, 6 ].max

        begin
          return post_chat(provider, body: {
            model: model,
            messages: [ { role: "user", content: @prompt } ],
            max_tokens: @max_tokens,
            temperature: @temperature
          }, read_timeout: budget)
        rescue StandardError => e
          last = e
          next
        end
      end
      raise last || Error.new("no gemini model succeeded")
    end
  end

  def post_chat(provider, body:, read_timeout:)
    uri = URI(provider[:endpoint])
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{provider[:api_key]}"
    request["Content-Type"]  = "application/json"
    (provider[:extra_headers] || {}).each { |k, v| request[k] = v }
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: read_timeout) do |http|
      http.request(request)
    end

    raise Error, "#{provider[:name]} returned HTTP #{response.code} #{response.body.to_s[0, 160]}" unless response.is_a?(Net::HTTPSuccess)

    text = JSON.parse(response.body).dig("choices", 0, "message", "content").to_s.strip
    raise Error, "#{provider[:name]} returned empty content" if text.blank?

    text
  end

  def strip_thought(text)
    text.gsub(THOUGHT_RE, "").strip
  end
end
