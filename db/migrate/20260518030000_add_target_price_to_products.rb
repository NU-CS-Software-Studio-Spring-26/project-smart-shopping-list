class AddTargetPriceToProducts < ActiveRecord::Migration[8.1]
  # Adds the two columns needed for "notify me when the price drops" alerts.
  #
  # - target_price    : user-chosen threshold. nil means "no alert configured"
  #                      and is the default (alerts are fully opt-in).
  # - last_alerted_at : when we last emailed the owner about a drop on this
  #                     product. PriceAlerter uses this as a 24-hour cooldown
  #                     so a steadily falling price doesn't spam the user.
  def change
    add_column :products, :target_price,    :decimal,  precision: 10, scale: 2
    add_column :products, :last_alerted_at, :datetime
  end
end
