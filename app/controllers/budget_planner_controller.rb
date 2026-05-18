class BudgetPlannerController < ApplicationController
  def index
    @budget = params[:budget].presence&.to_f

    all = Current.user.products
      .joins(:price_records)
      .select("products.*, MIN(price_records.price) AS lowest_price_seen")
      .group("products.id")
      .order(Arel.sql("lowest_price_seen ASC"))

    if @budget&.positive?
      @affordable  = all.having("MIN(price_records.price) <= ?", @budget)
      @over_budget = all.having("MIN(price_records.price) > ?",  @budget)
      @total_if_all = @affordable.sum { |p| p.lowest_price_seen.to_f }
      @remaining    = @budget - @total_if_all

      # AI-picked top deals from the affordable list. Returns [] if there
      # are fewer than 2 candidates; otherwise an array of DealPicker::Pick
      # structs, sourced from the LLM when reachable and a deterministic
      # heuristic otherwise. The view always renders the panel using
      # whatever comes back.
      @deal_picks = DealPicker.call(@affordable.to_a, budget: @budget)
    end
  end
end
