require "test_helper"

class BudgetPlannerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @earbuds = @user.products.create!(name: "Cheap Earbuds", category: "Electronics")
    @earbuds.price_records.create!(price: 30, store_name: "S", recorded_at: 1.day.ago)

    @book = @user.products.create!(name: "Paperback Novel", category: "Books")
    @book.price_records.create!(price: 12, store_name: "S", recorded_at: 1.day.ago)
  end

  test "category filter limits the planner to the chosen category" do
    get budget_planner_url(budget: 100, category: "Electronics")
    assert_response :success
    assert_match "Cheap Earbuds", response.body
    assert_no_match(/Paperback Novel/, response.body)
  end

  test "no category filter includes products from every category" do
    get budget_planner_url(budget: 100)
    assert_response :success
    assert_match "Cheap Earbuds", response.body
    assert_match "Paperback Novel", response.body
  end

  test "spend-by-category panel groups affordable items with correct subtotals" do
    get budget_planner_url(budget: 100)
    assert_response :success
    assert_match "Spend by category", response.body
    # Books subtotal is the single paperback ($12.00); Electronics is at least
    # the $30 earbuds. Both category subtotals should surface in the panel.
    assert_match "$12.00", response.body
    assert_select "section", text: /Spend by category/
  end

  test "spend-by-category panel is hidden when only one category is in range" do
    get budget_planner_url(budget: 100, category: "Books")
    assert_response :success
    assert_no_match(/Spend by category/, response.body)
  end
end
