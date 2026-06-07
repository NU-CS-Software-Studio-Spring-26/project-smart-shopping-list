module ApplicationHelper
  include Pagy::Frontend

  def user_avatar_tag(user, size: :small)
    css = size == :large ? "pt-user-avatar pt-user-avatar-lg" : "pt-user-avatar"
    alt = user.name.presence || user.email_address

    if user.avatar.attached?
      image_tag user.avatar, class: css, alt: alt
    elsif user.avatar_url.present?
      image_tag user.avatar_url, class: css, alt: alt
    else
      tag.span(user.email_address.first.upcase, class: css, aria: { hidden: true })
    end
  end
end
