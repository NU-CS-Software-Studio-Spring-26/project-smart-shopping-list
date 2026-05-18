require "faker"

puts "Clearing existing data..."
PriceRecord.destroy_all
Product.destroy_all
User.destroy_all

demo_password = "TrackSave!123"

puts "Creating demo user..."
demo_user = User.create!(
  email_address: "demo@example.com",
  password: demo_password,
  password_confirmation: demo_password
)
puts "  demo login: demo@example.com / #{demo_password}"

categories = [
  "Electronics",
  "Computers & Laptops",
  "TVs & Home Theater",
  "Cameras",
  "Gaming",
  "Appliances",
  "Clothing & Shoes",
  "Books",
  "Sports & Outdoors",
  "Beauty",
  "Other"
]

stores = {
  "Amazon" => "https://www.amazon.com",
  "Walmart" => "https://www.walmart.com",
  "Target" => "https://www.target.com",
  "Best Buy" => "https://www.bestbuy.com",
  "Costco" => "https://www.costco.com",
  "eBay" => "https://www.ebay.com",
  "Newegg" => "https://www.newegg.com",
  "Apple Store" => "https://www.apple.com/shop",
  "Lululemon" => "https://shop.lululemon.com"
}

product_templates = [
  [ "Apple iPhone 15 Pro", "Electronics", 949, 1199 ],
  [ "Samsung 65 inch 4K QLED TV", "TVs & Home Theater", 799, 1299 ],
  [ "Sony WH-1000XM5 Headphones", "Electronics", 279, 399 ],
  [ "Apple MacBook Air M2", "Computers & Laptops", 999, 1299 ],
  [ "PlayStation 5 Console", "Gaming", 449, 549 ],
  [ "Dyson V15 Detect Vacuum", "Appliances", 649, 799 ],
  [ "Nike Air Max 270", "Clothing & Shoes", 89, 150 ],
  [ "Atomic Habits", "Books", 11, 27 ],
  [ "Kindle Paperwhite 16GB", "Electronics", 99, 149 ],
  [ "Instant Pot Duo 7-in-1", "Appliances", 59, 99 ],
  [ "iPad Air M2", "Electronics", 599, 799 ],
  [ "Bose QuietComfort Earbuds II", "Electronics", 199, 299 ],
  [ "LG UltraGear Gaming Monitor", "Computers & Laptops", 279, 399 ],
  [ "Nintendo Switch OLED", "Gaming", 299, 349 ],
  [ "Ninja Foodi Air Fryer", "Appliances", 129, 199 ],
  [ "Lululemon Align Leggings", "Clothing & Shoes", 79, 98 ],
  [ "The Midnight Library", "Books", 10, 18 ],
  [ "Keurig K-Elite Coffee Maker", "Appliances", 129, 189 ],
  [ "GoPro HERO12 Black", "Electronics", 349, 449 ],
  [ "Adidas Ultraboost 22", "Clothing & Shoes", 120, 190 ]
]

notes_options = [
  "Black Friday deal",
  "Holiday sale",
  "Limited time offer",
  "Coupon applied",
  "Regular price",
  "Clearance",
  ""
]

users = [ demo_user ]

puts "Creating load-test users..."
39.times do |i|
  password = "Shopper!#{i + 1}A#{(i % 9) + 1}z"
  users << User.create!(
    email_address: "shopper#{i + 1}@example.com",
    password: password,
    password_confirmation: password
  )
end

puts "Creating products and price histories..."

# Don't fire the price-alerter or its emails during bulk seeding.
PriceRecord.alerter_callback_enabled = false

begin
  users.each_with_index do |user, user_index|
    30.times do |product_index|
      template_name, template_category, low, high = product_templates.sample
      name = "#{template_name} #{Faker::Commerce.color.capitalize} #{user_index + 1}-#{product_index + 1}"
      _store_name, store_url = stores.to_a.sample
      starting_price = rand(low..high) + rand(0..99) / 100.0
      target_price = [ starting_price * rand(0.72..0.92), 1 ].max.round(2)

      product = user.products.create!(
        name: name,
        category: template_category || categories.sample,
        description: Faker::Commerce.product_name,
        source_url: "#{store_url}/search?q=#{ERB::Util.url_encode(name)}",
        target_price: [ nil, target_price ].sample
      )

      rand(6..10).times do |record_index|
        record_store, record_store_url = stores.to_a.sample
        drift = 1.0 + rand(-0.18..0.16)
        price = [ starting_price * drift, 1 ].max.round(2)

        product.price_records.create!(
          price: price,
          store_name: record_store,
          url: "#{record_store_url}/search?q=#{ERB::Util.url_encode(name)}",
          recorded_at: (record_index * rand(3..9) + rand(1..3)).days.ago,
          notes: notes_options.sample,
          source: [ "manual", "scraped" ].sample
        )
      end
    end
  end

  puts "Done. Created #{User.count} users, #{Product.count} products, and #{PriceRecord.count} price records."
  puts "Large enough for pagination/performance checks: #{Product.count >= 1_000 ? 'yes' : 'no'}"
ensure
  PriceRecord.alerter_callback_enabled = true if defined?(PriceRecord)
end
