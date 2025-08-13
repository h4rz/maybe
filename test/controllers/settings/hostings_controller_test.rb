require "test_helper"
require "ostruct"

class Settings::HostingsControllerTest < ActionDispatch::IntegrationTest
  include ProviderTestHelper

  setup do
    sign_in users(:family_admin)

    @alpha_vantage_provider = mock
    @exchange_rate_api_provider = mock
    Provider::Registry.stubs(:get_provider).with(:alpha_vantage).returns(@alpha_vantage_provider)
    Provider::Registry.stubs(:get_provider).with(:exchange_rate_api).returns(@exchange_rate_api_provider)
    
    @alpha_vantage_usage_response = provider_success_response(
      OpenStruct.new(
        used: 10,
        limit: 25,
        utilization: 40,
        plan: "free",
      )
    )
    
    @exchange_rate_api_usage_response = provider_success_response(
      OpenStruct.new(
        used: 50,
        limit: 1500,
        utilization: 3.3,
        plan: "free",
      )
    )
  end

  test "cannot edit when self hosting is disabled" do
    with_env_overrides SELF_HOSTED: "false" do
      get settings_hosting_url
      assert_response :forbidden

      patch settings_hosting_url, params: { setting: { require_invite_for_signup: true } }
      assert_response :forbidden
    end
  end

  test "should get edit when self hosting is enabled" do
    @alpha_vantage_provider.expects(:usage).returns(@alpha_vantage_usage_response)
    @exchange_rate_api_provider.expects(:usage).returns(@exchange_rate_api_usage_response)

    with_self_hosting do
      get settings_hosting_url
      assert_response :success
    end
  end

  test "can update alpha vantage settings when self hosting is enabled" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { alpha_vantage_api_key: "1234567890" } }

      assert_equal "1234567890", Setting.alpha_vantage_api_key
    end
  end

  test "can update exchange rate api settings when self hosting is enabled" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { exchange_rate_api_key: "test_api_key_123" } }

      assert_equal "test_api_key_123", Setting.exchange_rate_api_key
    end
  end

  test "can clear data cache when self hosting is enabled" do
    account = accounts(:investment)
    holding = account.holdings.first
    exchange_rate = exchange_rates(:one)
    security_price = holding.security.prices.first
    account_balance = account.balances.create!(date: Date.current, balance: 1000, currency: "USD")

    with_self_hosting do
      perform_enqueued_jobs(only: DataCacheClearJob) do
        delete clear_cache_settings_hosting_url
      end
    end

    assert_redirected_to settings_hosting_url
    assert_equal I18n.t("settings.hostings.clear_cache.cache_cleared"), flash[:notice]

    assert_not ExchangeRate.exists?(exchange_rate.id)
    assert_not Security::Price.exists?(security_price.id)
    assert_not Holding.exists?(holding.id)
    assert_not Balance.exists?(account_balance.id)
  end

  test "can clear data only when admin" do
    with_self_hosting do
      sign_in users(:family_member)

      assert_no_enqueued_jobs do
        delete clear_cache_settings_hosting_url
      end

      assert_redirected_to settings_hosting_url
      assert_equal I18n.t("settings.hostings.not_authorized"), flash[:alert]
    end
  end
end
