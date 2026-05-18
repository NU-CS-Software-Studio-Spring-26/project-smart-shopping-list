class PriceAlertMailer < ApplicationMailer
  # Sends a "price dropped" email to the owner of a tracked product.
  #
  # PriceAlerter is the only intended caller. Reasons should be a subset of
  # [:target_hit, :history_low]; the templates use the boolean helpers
  # (@target_hit / @history_low) to decide which lines to show.
  #
  # We deliberately keep the URL helper inside the templates (not in the
  # mailer action) so anyone reading the action sees pure data prep.
  def price_drop(product, price_record, reasons: [])
    @product      = product
    @price_record = price_record
    @reasons      = Array(reasons)
    @target_hit   = @reasons.include?(:target_hit)
    @history_low  = @reasons.include?(:history_low)
    @user         = product.user

    mail subject: build_subject, to: @user.email_address
  end

  private

  # Pick the most specific headline available so the user's inbox preview
  # carries the most useful signal:
  #   target_hit  > history_low  > generic drop
  def build_subject
    if @target_hit
      "🎯 Your target price was hit on #{@product.name}"
    elsif @history_low
      "📉 New all-time low for #{@product.name}"
    else
      "Price update on #{@product.name}"
    end
  end
end
