module PriceScrapers
  # Lululemon JSON-LD pages with automatic retry when a legacy style id 404s/400s.
  # See LululemonUrl for the -md suffix migration pattern.
  class LululemonAdapter < JsonLdAdapter
    RETRYABLE_HTTP = /\AHTTP (400|404) from/i

    def fetch(url, timeout: 5)
      candidates = LululemonUrl.candidates(url)
      last_error = nil

      candidates.each_with_index do |candidate, index|
        begin
          result = super(candidate, timeout: timeout)
          result.resolved_url = candidate if candidate != url.to_s
          return result
        rescue PermanentError => e
          last_error = e
          raise e if index == candidates.length - 1
          raise e unless e.message.match?(RETRYABLE_HTTP)
        end
      end

      raise last_error if last_error
    end
  end
end
