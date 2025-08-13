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
end
