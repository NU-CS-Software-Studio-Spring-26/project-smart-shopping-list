class ReportsController < ApplicationController
  def index
    @products = Current.user.products.includes(:price_records).order(:category, :name).to_a
    @products_with_prices = @products.select { |product| product.latest_price.present? }

    @total_products = @products.size
    @tracked_value = @products_with_prices.sum { |product| product.latest_price.to_f }
    @below_target_count = @products_with_prices.count do |product|
      product.target_price.present? && product.latest_price.to_f <= product.target_price.to_f
    end
    @biggest_drop = biggest_drop
    @category_chart_data = @products.group_by(&:category).transform_values(&:count).sort.to_h
    @tag_chart_data = tag_chart_data
    @best_deals = best_deals
  end

  private

  def biggest_drop
    @products_with_prices.filter_map do |product|
      prices = product.price_records.map { |record| record.price.to_f }
      next if prices.size < 2

      drop = prices.max - product.latest_price.to_f
      next unless drop.positive?

      [ product, drop ]
    end.max_by { |_product, drop| drop }
  end

  def tag_chart_data
    counts = Hash.new(0)
    @products.each do |product|
      product.tags.each { |tag| counts[tag] += 1 }
    end
    counts.sort.to_h
  end

  def best_deals
    @products_with_prices.filter_map do |product|
      lowest = product.lowest_price&.to_f
      latest = product.latest_price&.to_f
      next if lowest.blank? || latest.blank?

      score = if product.target_price.present? && latest <= product.target_price.to_f
        100 + (product.target_price.to_f - latest)
      elsif lowest.positive?
        ((latest - lowest).abs / lowest) * 10
      else
        0
      end

      [ product, score ]
    end.sort_by { |_product, score| -score }.first(5)
  end
end
