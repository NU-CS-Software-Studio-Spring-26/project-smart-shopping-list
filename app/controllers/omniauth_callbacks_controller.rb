class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def create
    user = User.from_omniauth(auth_hash)
    start_new_session_for user
    redirect_to after_authentication_url, notice: "Signed in with #{provider_name}."
  rescue User::OauthError => e
    redirect_to new_session_path, alert: e.message
  end

  def failure
    redirect_to new_session_path, alert: "Google sign-in was cancelled or could not be completed."
  end

  private

  def auth_hash
    request.env.fetch("omniauth.auth")
  end

  def provider_name
    auth_hash.provider.to_s.titleize
  end
end
