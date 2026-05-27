module PriceScrapers
  # Lululemon occasionally migrates PDP style IDs (e.g. dsn0kocspb → dsn0kocspb-md).
  # Legacy saved URLs without the suffix return HTTP 400/404 from their CDN.
  module LululemonUrl
    HOST = /(\A|\.)lululemon\.com\z/i

    module_function

    def host?(url)
      URI.parse(url.to_s).host.to_s.match?(HOST)
    rescue URI::InvalidURIError
      false
    end

    def candidates(url)
      list = [ url.to_s ]
      fallback = md_style_fallback(url)
      list << fallback if fallback.present? && fallback != url.to_s
      list.uniq
    end

    # Append "-md" to a bare lowercase style id in the final path segment.
    # Mixed-case ids (e.g. LU9CBHS) are left alone — they still use the legacy path shape.
    def md_style_fallback(url)
      uri = URI.parse(url.to_s)
      segments = uri.path.split("/")
      style_id = segments.last
      return nil if style_id.blank?
      return nil unless style_id.match?(/\A[a-z0-9]+\z/)
      return nil if style_id.include?("-")

      segments[-1] = "#{style_id}-md"
      uri.path = segments.join("/")
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    def upgrade_source_url!(url)
      fallback = md_style_fallback(url)
      fallback.presence || url.to_s
    end
  end
end
