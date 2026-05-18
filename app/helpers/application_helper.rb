module ApplicationHelper
  def pagination_nav(pagination, path_helper_params = {})
    return if pagination[:total_pages] <= 1

    params_for_page = ->(page) do
      request.query_parameters.merge(path_helper_params).merge(page: page)
    end

    content_tag :nav, class: "pt-pagination", aria: { label: "Pagination" } do
      safe_join([
        pagination_link("Previous", params_for_page.call(pagination[:page] - 1), disabled: pagination[:page] == 1),
        content_tag(:span, "Page #{pagination[:page]} of #{pagination[:total_pages]}", class: "pt-pagination-status"),
        pagination_link("Next", params_for_page.call(pagination[:page] + 1), disabled: pagination[:page] == pagination[:total_pages])
      ])
    end
  end

  def pagination_summary(pagination, noun)
    count = pagination[:total_count]
    return "No #{noun.pluralize} yet" if count.zero?

    "Showing #{pagination[:from]}-#{pagination[:to]} of #{count} #{noun.pluralize(count)}"
  end

  private

  def pagination_link(label, params, disabled:)
    if disabled
      content_tag(:span, label, class: "pt-pagination-link is-disabled", aria: { disabled: "true" })
    else
      link_to(label, url_for(params), class: "pt-pagination-link")
    end
  end
end
