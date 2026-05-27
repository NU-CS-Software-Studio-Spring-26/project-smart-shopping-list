namespace :lululemon do
  desc "Rewrite legacy Lululemon PDP URLs (bare lowercase style ids) to the current -md form"
  task upgrade_urls: :environment do
    scope = Product.where("source_url ILIKE ?", "%lululemon.com%")
    updated = 0

    scope.find_each do |product|
      canonical = PriceScrapers::LululemonUrl.upgrade_source_url!(product.source_url)
      next if canonical == product.source_url

      product.update_column(:source_url, canonical)
      updated += 1
      puts "Product ##{product.id}: #{product.source_url}"
    end

    puts "Updated #{updated} product(s)."
  end
end
