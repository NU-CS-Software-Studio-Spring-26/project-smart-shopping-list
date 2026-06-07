class AccountsController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user

    if avatar_params_present?
      update_avatar
    elsif password_params_present?
      update_password
    else
      redirect_to account_path, alert: "Nothing to update."
    end
  end

  def destroy
    @user = Current.user

    unless account_deletion_confirmed?
      redirect_to account_path, alert: deletion_failure_message
      return
    end

    @user.destroy!
    terminate_session
    redirect_to root_path, notice: "Your account and all associated data have been deleted."
  end

  private

  def avatar_params_present?
    params[:user]&.key?(:avatar)
  end

  def password_params_present?
    params[:current_password].present? || params[:password].present?
  end

  def update_avatar
    if params[:remove_avatar].present?
      @user.avatar.purge if @user.avatar.attached?
      return redirect_to account_path, notice: "Profile photo removed."
    end

    uploaded = params.dig(:user, :avatar)
    if uploaded.blank?
      redirect_to account_path, alert: "Choose an image file to upload."
      return
    end

    @user.avatar.attach(uploaded)
    if @user.valid?
      redirect_to account_path, notice: "Profile photo updated."
    else
      @user.avatar.purge
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    if @user.oauth_user?
      redirect_to account_path, alert: "You sign in with Google — password changes are managed by Google."
      return
    end

    unless @user.authenticate(params[:current_password].to_s)
      @user.errors.add(:current_password, "is incorrect")
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      return render :show, status: :unprocessable_entity
    end

    if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      redirect_to account_path, notice: "Password updated successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def account_deletion_confirmed?
    if @user.oauth_user?
      params[:email_confirmation].to_s.strip.downcase == @user.email_address
    else
      @user.authenticate(params[:password_confirmation].to_s)
    end
  end

  def deletion_failure_message
    if @user.oauth_user?
      "Type your email address exactly to confirm account deletion."
    else
      "Current password is incorrect. Account was not deleted."
    end
  end
end
