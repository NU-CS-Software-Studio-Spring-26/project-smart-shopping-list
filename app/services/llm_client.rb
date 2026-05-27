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

  GEMINI_DEFAULT_MODEL     = "gemma-4-26b-a4b-it"
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
        text = call_provider(provider)
        return strip_thought(text) if text.present?
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
  # OpenRouter supports a `models` array natively. Gemini only takes a
  # single `model`, so when we have a cascade we walk it one model at a time.
  def call_provider(provider)
    if provider[:name] == "openrouter"
      post_chat(provider, body: {
        models: provider[:models],
        messages: [ { role: "user", content: @prompt } ],
        max_tokens: @max_tokens,
        temperature: @temperature
      })
    else
      last = nil
      provider[:models].each do |model|
        begin
          return post_chat(provider, body: {
            model: model,
            messages: [ { role: "user", content: @prompt } ],
            max_tokens: @max_tokens,
            temperature: @temperature
          })
        rescue StandardError => e
          last = e
          next
        end
      end
      raise last || Error.new("no gemini model succeeded")
    end
  end

  def post_chat(provider, body:)
    uri = URI(provider[:endpoint])
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{provider[:api_key]}"
    request["Content-Type"]  = "application/json"
    (provider[:extra_headers] || {}).each { |k, v| request[k] = v }
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: @request_timeout) do |http|
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
