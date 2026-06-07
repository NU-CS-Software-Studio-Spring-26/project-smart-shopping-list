Feature: Add a product manually
  Signed-in users can track products without auto-fetch.

  Background:
    Given I am signed in as "one@example.com"

  Scenario: Create a manual product
    When I add a manual product named "Cucumber Test Headphones" in category "Electronics"
    Then I should see the product "Cucumber Test Headphones"
