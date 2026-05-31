class BudgetPlannerController < ApplicationController
  def index
    @budget = params[:budget].presence&.to_f
    @folders = Current.user.folders.order(:name)
    @selected_folder = @folders.find { |f| f.id.to_s == params[:folder_id].to_s } if params[:folder_id].present?

    base_scope = @selected_folder ? @selected_folder.products : Current.user.products

    # Category-based budgeting: options reflect whatever the folder selection
    # leaves available; an explicit category narrows the whole planner to that
    # type of purchase.
    @categories = base_scope.distinct.pluck(:category).compact.sort
    @selected_category = params[:category].presence
    base_scope = base_scope.where(category: @selected_category) if @selected_category

    all = base_scope
      .joins(:price_records)
      .select("products.*, MIN(price_records.price) AS lowest_price_seen")
      .group("products.id")
      .order(Arel.sql("lowest_price_seen ASC"))

    if @budget&.positive?
      # Load the grouped scopes into arrays once so subsequent `.size` /
      # `.any?` calls in the view return Integer instead of the {group => count}
      # Hash that AR returns for GROUP BY + HAVING relations. That mismatch
      # was the source of the Budget Planner 500 reported in issue #46 —
      # calling "product".pluralize(hash) raises NoMethodError on Hash#to_i.
      @affordable  = all.having("MIN(price_records.price) <= ?", @budget).to_a
      @over_budget = all.having("MIN(price_records.price) > ?",  @budget).to_a
      @total_if_all = @affordable.sum { |p| p.lowest_price_seen.to_f }
      @remaining    = @budget - @total_if_all

      # AI-picked top deals from the affordable list. Returns [] if there
      # are fewer than 2 candidates; otherwise an array of DealPicker::Pick
      # structs, sourced from the LLM when reachable and a deterministic
      # heuristic otherwise. The view always renders the panel using
      # whatever comes back.
      @deal_picks = DealPicker.call(@affordable, budget: @budget)

      # Per-category spend among the affordable items, so users managing
      # different types of purchases see where their budget would go.
      @category_breakdown = build_category_breakdown(@affordable)
    end
  end

  private

  def build_category_breakdown(products)
    products
      .group_by(&:category)
      .map do |category, items|
        { category: category.presence || "Uncategorized",
          count: items.size,
          total: items.sum { |p| p.lowest_price_seen.to_f } }
      end
      .sort_by { |row| -row[:total] }
  end
end
