class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  SORT_OPTIONS = {
    "newest"     => "products.created_at DESC",
    "oldest"     => "products.created_at ASC",
    "name_asc"   => "LOWER(products.name) ASC",
    "name_desc"  => "LOWER(products.name) DESC",
    "price_asc"  => "latest_price ASC NULLS LAST",
    "price_desc" => "latest_price DESC NULLS LAST"
  }.freeze

  def sort_products(scope, key)
    order_clause = SORT_OPTIONS[key] || SORT_OPTIONS["newest"]
    if order_clause.start_with?("latest_price")
      scope
        .left_joins(:price_records)
        .select("products.*, MAX(price_records.price) AS latest_price")
        .group("products.id")
        .order(Arel.sql(order_clause))
    else
      scope.order(Arel.sql(order_clause))
    end
  end

  def fuzzy_search(scope, query)
    tokens = query.to_s.downcase.split(/\s+/).reject(&:blank?)
    return scope if tokens.empty?
    tokens.inject(scope) do |s, token|
      pattern = "%#{token}%"
      s.where(
        "LOWER(name) LIKE ? OR LOWER(category) LIKE ? OR LOWER(description) LIKE ? OR array_to_string(tags, ' ') LIKE ?",
        pattern, pattern, pattern, pattern
      )
    end
  end

  def paginate(scope, per_page: 24)
    page = params.fetch(:page, 1).to_i
    page = 1 if page < 1

    total_count = scope.count
    total_count = total_count.length if total_count.respond_to?(:length) && !total_count.is_a?(Numeric)
    total_pages = [ (total_count / per_page.to_f).ceil, 1 ].max
    page = total_pages if page > total_pages

    offset = (page - 1) * per_page
    records = scope.limit(per_page).offset(offset)

    metadata = {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      from: total_count.zero? ? 0 : offset + 1,
      to: [ offset + per_page, total_count ].min
    }

    [ records, metadata ]
  end
end
