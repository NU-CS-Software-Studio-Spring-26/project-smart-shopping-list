module PriceScrapers
  # Retailers whose sites reliably reject server-side automated lookups behind
  # bot management (Cloudflare / Akamai / PerimeterX) or CDNs that 400/403 every
  # datacenter request. Because our scrape always runs from the app server's IP
  # — never the user's browser — these can only ever fail. We detect them up
  # front so product creation skips the guaranteed-to-fail 5s request and sends
  # the user straight to manual entry with a calm "heads up".
  #
  # Keyed by registrable domain suffix -> display label. Subdomains match, so
  # "shop.lululemon.com" resolves to "Lululemon". See docs/scrapers.md §6.D.
  module BlockedSites
    HOSTS = {
      "lululemon.com"       => "Lululemon",
      "nordstrom.com"       => "Nordstrom",
      "sephora.com"         => "Sephora",
      "asos.com"            => "ASOS",
      "freepeople.com"      => "Free People",
      "urbanoutfitters.com" => "Urban Outfitters",
      "anthropologie.com"   => "Anthropologie"
    }.freeze

    module_function

    # Display label if the URL's host is a known blocker, otherwise nil.
    def label_for(url)
      host = host_for(url)
      return nil if host.blank?

      _suffix, label = HOSTS.find do |suffix, _|
        host == suffix || host.end_with?(".#{suffix}")
      end
      label
    end

    def blocked?(url)
      label_for(url).present?
    end

    def host_for(url)
      URI.parse(url.to_s).host.to_s.downcase.sub(/\Awww\./, "").presence
    rescue URI::InvalidURIError
      nil
    end
  end
end
