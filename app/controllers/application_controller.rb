class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

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
