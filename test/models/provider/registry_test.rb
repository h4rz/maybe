require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "alpha_vantage configured with ENV" do
    Setting.stubs(:alpha_vantage_api_key).returns(nil)

    with_env_overrides ALPHA_VANTAGE_API_KEY: "123" do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "alpha_vantage configured with Setting" do
    Setting.stubs(:alpha_vantage_api_key).returns("123")

    with_env_overrides ALPHA_VANTAGE_API_KEY: nil do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "alpha_vantage not configured" do
    Setting.stubs(:alpha_vantage_api_key).returns(nil)

    with_env_overrides ALPHA_VANTAGE_API_KEY: nil do
      assert_nil Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "exchange_rate_api configured with ENV" do
    Setting.stubs(:exchange_rate_api_key).returns(nil)

    with_env_overrides EXCHANGE_RATE_API_KEY: "123" do
      assert_instance_of Provider::ExchangeRateApi, Provider::Registry.get_provider(:exchange_rate_api)
    end
  end

  test "exchange_rate_api configured with Setting" do
    Setting.stubs(:exchange_rate_api_key).returns("123")

    with_env_overrides EXCHANGE_RATE_API_KEY: nil do
      assert_instance_of Provider::ExchangeRateApi, Provider::Registry.get_provider(:exchange_rate_api)
    end
  end

  test "exchange_rate_api works without configuration (open access)" do
    Setting.stubs(:exchange_rate_api_key).returns(nil)

    with_env_overrides EXCHANGE_RATE_API_KEY: nil do
      assert_instance_of Provider::ExchangeRateApi, Provider::Registry.get_provider(:exchange_rate_api)
    end
  end

  test "primary_exchange_rate_provider returns ExchangeRate-API when available" do
    Setting.stubs(:exchange_rate_api_key).returns("123")
    Setting.stubs(:alpha_vantage_api_key).returns("456")

    provider = Provider::Registry.primary_exchange_rate_provider
    assert_instance_of Provider::ExchangeRateApi, provider
  end

  test "primary_exchange_rate_provider falls back to Alpha Vantage" do
    Setting.stubs(:exchange_rate_api_key).returns(nil)
    Setting.stubs(:alpha_vantage_api_key).returns("456")

    with_env_overrides EXCHANGE_RATE_API_KEY: nil do
      provider = Provider::Registry.primary_exchange_rate_provider
      assert_instance_of Provider::AlphaVantage, provider
    end
  end

  test "exchange_rates concept includes both providers" do
    registry = Provider::Registry.for_concept(:exchange_rates)
    provider_names = registry.send(:available_providers)
    
    assert_includes provider_names, :exchange_rate_api
    assert_includes provider_names, :alpha_vantage
    assert_equal :exchange_rate_api, provider_names.first # ExchangeRate-API should be first (higher priority)
  end
end
