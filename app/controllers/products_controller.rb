class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :fetch_price, :export, :toggle_favorite ]

  def index
    @favorites_only = ActiveModel::Type::Boolean.new.cast(params[:favorites])

    scope = Current.user.products
    scope = scope.favorited if @favorites_only
    scope = fuzzy_search(scope, params[:search]) if params[:search].present?
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.where("? = ANY(tags)", params[:tag].to_s.downcase) if params[:tag].present?
    scope = sort_products(scope, params[:sort])

    # The "price_asc/price_desc" sort path uses GROUP BY products.id, which
    # would make Pagy's default count(:all) return per-group counts. Override
    # with the underlying filtered product count so pagination math is right.
    count_scope = Current.user.products
    count_scope = count_scope.favorited if @favorites_only
    count_scope = fuzzy_search(count_scope, params[:search]) if params[:search].present?
    count_scope = count_scope.where(category: params[:category]) if params[:category].present?
    count_scope = count_scope.where("? = ANY(tags)", params[:tag].to_s.downcase) if params[:tag].present?

    @pagy, @products = pagy(scope, count: count_scope.count, limit: 24)
    @products.load
    @categories = Current.user.products.distinct.pluck(:category).compact.sort
    @tags = Current.user.products.pluck(:tags).flatten.uniq.sort

    # Favorites row shown above the grid (quick access). Skipped while the
    # "favorites only" filter is active, since the grid is already favorites.
    @favorites = unless @favorites_only
      Current.user.products.favorited.includes(:price_records).order(:name).to_a
    end
  end

  def show
    all_price_records = @product.price_records.order(recorded_at: :desc)
    @price_records_pagy, @price_records = pagy(all_price_records, limit: 20)
    @chart_data = build_chart_data(all_price_records)
    @lowest_price_record = @product.lowest_price_record
    @deal_advice = DealAdvisor.call(@product)
    # Powers the "🎉 Price alert triggered" banner. Only populated when the
    # most recent alert is within the banner display window (7 days), so
    # the show view can render unconditionally on a non-nil value.
    @alert_trigger_record = @product.alert_trigger_record if @product.recent_alert?
  end

  def new
    @product = Current.user.products.build
    @manual  = ActiveModel::Type::Boolean.new.cast(params[:manual])
  end

  def create
    @product = Current.user.products.build(create_params)
    @manual  = ActiveModel::Type::Boolean.new.cast(params[:manual])

    # Manual mode: user filled in name/details by hand, skip the scraper.
    if @manual || @product.name.present?
      @manual = true
      @product.auto_refresh = false
      @product.last_fetch_error = nil
      if @product.save
        return redirect_to @product, notice: "Product added."
      else
        return render :new, status: :unprocessable_entity
      end
    end

    if @product.source_url.blank?
      @product.errors.add(:source_url, "can't be blank")
      return render :new, status: :unprocessable_entity
    end

    begin
      result = PriceScrapers.fetch(@product.source_url, timeout: 5)
    rescue PriceScrapers::Error => e
      @manual = true
      flash.now[:alert] = friendly_scrape_error(e) +
        " You can fill in the product details below to add it manually."
      return render :new, status: :unprocessable_entity
    end

    @product.name      = result.title.presence || fallback_name_from(@product.source_url)
    @product.image_url = result.image_url if result.image_url.present?
    @product.stock_status = result.availability if result.availability.present?
    @product.source_url = result.resolved_url.presence || @product.source_url

    if @product.save
      if result.price.present?
        @product.price_records.create!(
          price:       result.price,
          store_name:  result.store_name,
          url:         @product.source_url,
          recorded_at: result.fetched_at,
          source:      "scraped"
        )
      end
      @product.update_columns(
        last_fetched_at: Time.current,
        last_fetch_error: nil,
        auto_refresh: true
      )
      redirect_to @product, notice: "Product added! We grabbed its details from the page."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(update_params)
      redirect_to @product, notice: "Product updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_url, notice: "Product deleted."
  end

  def export
    respond_to do |format|
      format.csv do
        send_data PriceHistoryExport.to_csv(@product),
                  filename: "#{export_filename(@product)}-price-history.csv",
                  type: "text/csv; charset=utf-8",
                  disposition: "attachment"
      end
      format.pdf do
        send_data PriceHistoryExport.to_pdf(@product),
                  filename: "#{export_filename(@product)}-price-history.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  def export_watchlist
    products = Current.user.products.includes(:price_records).order(:category, :name)
    send_data WatchlistExport.to_csv(products),
              filename: "price-tracker-watchlist.csv",
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  # Synchronous "Fetch latest price" button on the product detail page.
  # Blocks the request for up to ~5s while we hit the source URL.
  def fetch_price
    unless @product.auto_refresh? && @product.scrapeable?
      return redirect_to @product, alert: "Automatic refresh is off for this product. Log a price manually instead."
    end

    PriceFetcher.call(@product)
    @product.reload

    if @product.last_fetch_error.present?
      redirect_to @product, alert: "Couldn't refresh: #{@product.last_fetch_error}"
    else
      redirect_to @product, notice: "Price refreshed."
    end
  end

  # Toggle the favorite flag. set_product scopes to Current.user.products, so a
  # request for another user's product raises RecordNotFound (404) — a user can
  # never flip someone else's favorite.
  def toggle_favorite
    @product.update!(favorite: !@product.favorite?)
    notice = @product.favorite? ? "Added to favorites." : "Removed from favorites."
    redirect_back fallback_location: @product, notice: notice
  end

  private

  # Group price records by store for the price-history chart. A store with a
  # single observation gets that point duplicated at the chart's overall date
  # range so the chart still draws a flat horizontal line, same convention as
  # Newegg / CamelCamelCamel. When the product itself has only one record
  # (so all dates are the same), extend the range to today (with a 1-day
  # minimum span) so the line still has somewhere to draw.
  def build_chart_data(records)
    return [] if records.empty?

    # Special case: a single observation across the whole product. Plot it
    # as one real point so the chart shows one dot at the actual recorded
    # date — duplicating it onto a synthetic "today" point was confusing
    # users into thinking two prices had been logged.
    if records.size == 1
      r = records.first
      return [ {
        name: r.store_name.presence || "Unknown",
        data: [ [ r.recorded_at.to_date.iso8601, r.price.to_f ] ]
      } ]
    end

    dates = records.map { |r| r.recorded_at.to_date }
    range_start, range_end = dates.min, dates.max

    records.group_by(&:store_name).map do |store, recs|
      points = recs.sort_by(&:recorded_at).map { |r| [ r.recorded_at.to_date.iso8601, r.price.to_f ] }

      # If a store has only one observation but the chart spans multiple
      # dates, duplicate that observation at the chart's start and end so
      # the store still draws as a flat horizontal line. This is only safe
      # when the product overall has multiple observations — otherwise we
      # would re-create the "two-dots-for-one-price" bug we just fixed.
      if points.size == 1
        _, y = points.first
        points = [ [ range_start.iso8601, y ], [ range_end.iso8601, y ] ]
      end

      { name: store.presence || "Unknown", data: points }
    end
  end

  def set_product
    @product = Current.user.products.find(params[:id])
  end

  # New form: source_url + category by default. When the scraper fails or the
  # user opts into manual mode, name/description/image_url are also accepted
  # so the user can finish onboarding without a working scrape.
  # target_price is optional — users may set it now or via the edit form later.
  def create_params
    params.require(:product).permit(:category, :source_url, :name, :description, :image_url, :target_price, :tags_input)
  end

  # Map scraper exceptions to a single user-facing sentence. We deliberately
  # don't surface raw exception text (DNS errors, "getaddrinfo(3)", HTTP codes)
  # to end users — those belong in logs, not in a flash banner.
  # Retailers known to block all automated scraping with bot-defence tooling
  # (Cloudflare / Akamai / PerimeterX). We can't fetch them server-side at
  # all, so we tell the user up front rather than letting them retry forever.
  BLOCKED_RETAILER_HOSTS = {
    "apple.com"    => "Apple",
    "target.com"   => "Target",
    "homedepot.com" => "The Home Depot",
    "nordstrom.com" => "Nordstrom"
  }.freeze

  def friendly_scrape_error(error)
    host = begin
      URI.parse(@product.source_url).host.to_s.sub(/\Awww\./, "").downcase
    rescue URI::InvalidURIError
      ""
    end

    blocked = BLOCKED_RETAILER_HOSTS.find { |suffix, _| host.end_with?(suffix) }
    if blocked
      return "#{blocked.last} blocks automated lookups, so we can't auto-fetch this product. Fill in the details below and we'll still save the link so you can log prices manually."
    end

    case error
    when PriceScrapers::TransientError
      "We couldn't reach that site right now — try again in a moment, or fill in the details below to add it manually."
    when PriceScrapers::PermanentError
      "That URL didn't work — the page may not exist or the site may be blocking automated lookups. Use the form below to add the product manually."
    else
      "We couldn't read product details from that page. The form is pre-filled in manual mode below — finish entering the details and we'll save it."
    end
  end

  # Edit form keeps everything editable so users can correct scraped values.
  # target_price is editable here so users can revise their alert threshold
  # at any time (or clear it by submitting blank).
  def update_params
    params.require(:product).permit(:name, :category, :description, :image_url, :source_url, :target_price, :auto_refresh, :tags_input)
  end

  def export_filename(product)
    product.name.to_s.parameterize.presence || "product"
  end

  # Used when the page returns no schema.org "name" — gives the model
  # something readable so :name presence validation passes.
  def fallback_name_from(url)
    uri = URI.parse(url)
    last_segment = uri.path.to_s.split("/").reject(&:empty?).last
    [ uri.host.to_s.sub(/\Awww\./, ""), last_segment ].reject(&:blank?).join(" — ").presence || uri.to_s
  end
end
