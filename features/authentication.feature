Feature: Protected pages
  Password-protected areas should not be reachable without signing in.

  Scenario: Guest cannot view the products dashboard
    When I visit the products page while signed out
    Then I should be redirected to sign in
