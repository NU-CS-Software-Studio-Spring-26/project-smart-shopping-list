class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create create_omniauth ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Signed in."
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  # Hit by Google after the user approves the consent screen. The auth hash
  # is placed in env by OmniAuth; we hand it to User.from_omniauth which
  # find-or-creates by (provider, uid) and then by email.
  def create_omniauth
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    if user&.persisted?
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Signed in with #{auth.provider.to_s.titleize}."
    else
      redirect_to new_session_path, alert: "Could not sign you in with that account."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other, notice: "Signed out."
  end
end
