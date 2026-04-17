require "test_helper"

class PriceRecordsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get price_records_index_url
    assert_response :success
  end

  test "should get show" do
    get price_records_show_url
    assert_response :success
  end

  test "should get new" do
    get price_records_new_url
    assert_response :success
  end

  test "should get edit" do
    get price_records_edit_url
    assert_response :success
  end
end
