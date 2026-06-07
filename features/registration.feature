Feature: User registration
  New users must accept the terms before creating an account.

  Scenario: Successful sign-up with terms accepted
    Given I am on the sign-up page
    When I register with a new account and password "Secure!99"
    Then I should be signed in

  Scenario: Sign-up fails without accepting terms
    Given I am on the sign-up page
    When I try to register without accepting terms
    Then I should see a terms acceptance error
