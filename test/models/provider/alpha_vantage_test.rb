require "test_helper"
require "ostruct"

class Provider::AlphaVantageTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest, SecurityProviderInterfaceTest

  setup do
    @subject = @alpha_vantage = Provider::AlphaVantage.new(ENV["ALPHA_VANTAGE_API_KEY"])
  end

  test "health check" do
    VCR.use_cassette("alpha_vantage/health") do
      assert @alpha_vantage.healthy?
    end
  end

  test "usage info" do
    VCR.use_cassette("alpha_vantage/usage") do
      usage = @alpha_vantage.usage.data
      assert usage.used.present?
      assert usage.limit.present?
      assert usage.utilization.present?
      assert usage.plan.present?
    end
  end
end