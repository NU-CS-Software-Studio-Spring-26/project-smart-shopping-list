class RecommendationsController < ApplicationController
  def index
    @budget = params[:budget].presence&.to_f

    if @budget.present? && @budget > 0
      # Find products whose lowest recorded price is within the budget,
      # ordered by lowest price ascending so the most affordable come first.
      # Products with no price records are excluded since we can't compare them.
      @recommendations = Current.user.products
        .joins(:price_records)
        .select("products.*, MIN(price_records.price) AS lowest_price_seen")
        .group("products.id")
        .having("MIN(price_records.price) <= ?", @budget)
        .order(Arel.sql("lowest_price_seen ASC"))

      @over_budget = Current.user.products
        .joins(:price_records)
        .select("products.*, MIN(price_records.price) AS lowest_price_seen")
        .group("products.id")
        .having("MIN(price_records.price) > ?", @budget)
        .order(Arel.sql("lowest_price_seen ASC"))
    end
  end
end
