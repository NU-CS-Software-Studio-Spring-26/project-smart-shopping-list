# frozen_string_literal: true

require "cucumber/rails"

module IntegrationHelpers
  include Rails.application.routes.url_helpers

  def integration
    @integration ||= ActionDispatch::Integration::Session.new(Rails.application)
  end

  def get(path, **options)
    integration.get(path, **options)
  end

  def post(path, **options)
    integration.post(path, **options)
  end

  def response
    integration.response
  end

  def follow_redirect!
    integration.follow_redirect!
  end

  def assert_redirected_to(expected)
    unless response.redirect?
      raise "Expected redirect to #{expected}, got status #{response.status}"
    end

    location = response.headers["Location"].to_s
    expected_path = expected.to_s
    unless location.end_with?(expected_path)
      raise "Expected redirect to #{expected_path}, got #{location}"
    end
  end

  def assert_response(expected)
    code = case expected
    when :success then 200..299
    when Integer then expected
    when :unprocessable_entity, :unprocessable_content then 422
    else Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(expected)
    end

    actual = response.status
    ok = code.is_a?(Range) ? code.cover?(actual) : actual == code
    raise "Expected response #{expected}, got #{actual}" unless ok
  end
end

World(IntegrationHelpers)

Before do
  @integration = nil
  ActiveStorage::Current.url_options = { host: "www.example.com" }
end
