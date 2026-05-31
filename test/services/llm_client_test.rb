require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  def client
    LlmClient.new(prompt: "hi", max_tokens: 10, temperature: 0.2, request_timeout: 5)
  end

  test "falls through to the next provider when a response is only <thought>" do
    c = client
    calls = []
    c.define_singleton_method(:providers) do
      [ { name: "gemini", enabled: true }, { name: "openrouter", enabled: true } ]
    end
    c.define_singleton_method(:call_provider) do |provider|
      calls << provider[:name]
      # Gemma-style: the entire reply is a reasoning block, empty once stripped.
      provider[:name] == "gemini" ? "<thought>thinking…</thought>" : "Real answer"
    end

    assert_equal "Real answer", c.complete
    assert_equal %w[gemini openrouter], calls, "should try openrouter after gemini stripped to empty"
  end

  test "raises when every provider yields empty-after-strip text" do
    c = client
    c.define_singleton_method(:providers) { [ { name: "gemini", enabled: true } ] }
    c.define_singleton_method(:call_provider) { |_p| "<thought>only thinking</thought>" }

    error = assert_raises(LlmClient::Error) { c.complete }
    assert_match(/no usable text/i, error.message)
  end
end
