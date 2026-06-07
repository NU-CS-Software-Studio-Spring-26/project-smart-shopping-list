When("I add a manual product named {string} in category {string}") do |name, category|
  post products_path, params: {
    manual: "1",
    product: {
      name: name,
      category: category
    }
  }
  follow_redirect! while response.redirect?
  raise "Product create failed with #{response.status}" unless response.successful?
end

Then("I should see the product {string}") do |name|
  raise "Expected product #{name.inspect} on page" unless response.body.to_s.include?(name)
end
