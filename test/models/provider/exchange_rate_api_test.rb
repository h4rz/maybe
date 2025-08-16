require "test_helper"
require "ostruct"

class Provider::ExchangeRateApiTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest

  setup do
    @subject = @exchange_rate_api = Provider::ExchangeRateApi.new(ENV["EXCHANGE_RATE_API_KEY"])
  end

  test "health check with API key" do
    VCR.use_cassette("exchange_rate_api/health_with_key") do
      provider_with_key = Provider::ExchangeRateApi.new("test_api_key")
      assert provider_with_key.healthy?
    end
  end

  test "health check without API key (open access)" do
    VCR.use_cassette("exchange_rate_api/health_open_access") do
      provider_open_access = Provider::ExchangeRateApi.new(nil)
      assert provider_open_access.healthy?
    end
  end

  test "usage info with API key shows optimized plan" do
    VCR.use_cassette("exchange_rate_api/usage_with_key") do
      provider_with_key = Provider::ExchangeRateApi.new("test_api_key")
      usage = provider_with_key.usage.data
      
      assert_equal 0, usage.used
      assert_equal 1500, usage.limit
      assert_equal 0, usage.utilization
      assert_includes usage.plan, "optimized"
      assert_includes usage.plan, "open access"
    end
  end

  test "usage info without API key shows open access only" do
    VCR.use_cassette("exchange_rate_api/usage_open_access") do
      provider_open_access = Provider::ExchangeRateApi.new(nil)
      usage = provider_open_access.usage.data
      
      assert_equal 0, usage.used
      assert_equal Float::INFINITY, usage.limit
      assert_equal 0, usage.utilization
      assert_includes usage.plan, "open"
      assert_includes usage.plan, "current rates only"
    end
  end

  test "fetches current exchange rate using open access (preserves API quota)" do
    VCR.use_cassette("exchange_rate_api/current_rate_open_access") do
      # Even with API key, current rates should use open access
      provider_with_key = Provider::ExchangeRateApi.new("test_api_key")
      rate = provider_with_key.fetch_exchange_rate(
        from: "USD",
        to: "EUR",
        date: Date.current
      ).data

      assert_equal "USD", rate.from
      assert_equal "EUR", rate.to
      assert_equal Date.current, rate.date
      assert rate.rate.is_a?(Float)
      assert rate.rate > 0
    end
  end

  test "current rates work without API key" do
    VCR.use_cassette("exchange_rate_api/current_rate_no_key") do
      provider_no_key = Provider::ExchangeRateApi.new(nil)
      rate = provider_no_key.fetch_exchange_rate(
        from: "USD",
        to: "EUR",
        date: Date.current
      ).data

      assert_equal "USD", rate.from
      assert_equal "EUR", rate.to
      assert_equal Date.current, rate.date
      assert rate.rate.is_a?(Float)
      assert rate.rate > 0
    end
  end

  test "fetches historical exchange rate with API key" do
    skip "Requires API key for historical data" unless ENV["EXCHANGE_RATE_API_KEY"].present?
    
    VCR.use_cassette("exchange_rate_api/historical_rate") do
      rate = @exchange_rate_api.fetch_exchange_rate(
        from: "USD",
        to: "EUR", 
        date: Date.parse("2024-01-01")
      ).data

      assert_equal "USD", rate.from
      assert_equal "EUR", rate.to
      assert_equal Date.parse("2024-01-01"), rate.date
      assert rate.rate.is_a?(Float)
      assert rate.rate > 0
    end
  end

  test "raises error for historical data without API key" do
    provider_open_access = Provider::ExchangeRateApi.new(nil)
    
    VCR.use_cassette("exchange_rate_api/historical_rate_no_key") do
      assert_raises Provider::ExchangeRateApi::InvalidExchangeRateError do
        provider_open_access.fetch_exchange_rates(
          from: "USD",
          to: "EUR",
          start_date: Date.parse("2024-01-01"),
          end_date: Date.parse("2024-01-07")
        )
      end
    end
  end

  test "fetches exchange rate range with optimized quota usage" do
    skip "Requires API key for historical data" unless ENV["EXCHANGE_RATE_API_KEY"].present?
    
    VCR.use_cassette("exchange_rate_api/rate_range_optimized") do
      # Test a range that includes both historical and current dates
      yesterday = Date.current - 1.day
      tomorrow = Date.current + 1.day
      
      rates = @exchange_rate_api.fetch_exchange_rates(
        from: "USD",
        to: "EUR",
        start_date: yesterday,
        end_date: tomorrow
      ).data

      assert_equal 3, rates.count
      rates.each do |rate|
        assert_equal "USD", rate.from
        assert_equal "EUR", rate.to
        assert rate.date.is_a?(Date)
        assert rate.rate.is_a?(Float)
        assert rate.rate > 0
      end
      
      # Verify rates are sorted by date
      assert_equal rates.sort_by(&:date), rates
      
      # Historical dates should use API quota, current/future dates should use open access
      # (This is implicit in the implementation, hard to test directly without mocking)
    end
  end

  test "fetches exchange rate range for historical dates only" do
    skip "Requires API key for historical data" unless ENV["EXCHANGE_RATE_API_KEY"].present?
    
    VCR.use_cassette("exchange_rate_api/rate_range_historical") do
      rates = @exchange_rate_api.fetch_exchange_rates(
        from: "USD",
        to: "EUR",
        start_date: Date.parse("2024-01-01"),
        end_date: Date.parse("2024-01-03")
      ).data

      assert_equal 3, rates.count
      rates.each do |rate|
        assert_equal "USD", rate.from
        assert_equal "EUR", rate.to
        assert rate.date.is_a?(Date)
        assert rate.rate.is_a?(Float)
        assert rate.rate > 0
      end
      
      # Verify rates are sorted by date
      assert_equal rates.sort_by(&:date), rates
    end
  end

  test "handles API errors gracefully" do
    VCR.use_cassette("exchange_rate_api/api_error") do
      provider_with_invalid_key = Provider::ExchangeRateApi.new("invalid_key")
      
      response = provider_with_invalid_key.fetch_exchange_rate(
        from: "USD",
        to: "EUR",
        date: Date.current
      )
      
      assert_not response.success?
      assert response.error.is_a?(Provider::ExchangeRateApi::Error)
    end
  end

  test "handles network errors gracefully" do
    # Simulate network error by stubbing Faraday to raise error
    faraday_stub = stub
    faraday_stub.stubs(:get).raises(Faraday::ConnectionFailed.new("Connection failed"))
    @exchange_rate_api.stubs(:client).returns(faraday_stub)
    
    response = @exchange_rate_api.fetch_exchange_rate(
      from: "USD",
      to: "EUR", 
      date: Date.current
    )
    
    assert_not response.success?
    assert response.error.is_a?(Provider::ExchangeRateApi::Error)
  end

  test "handles invalid currency pairs" do
    VCR.use_cassette("exchange_rate_api/invalid_currency") do
      response = @exchange_rate_api.fetch_exchange_rate(
        from: "INVALID",
        to: "EUR",
        date: Date.current
      )
      
      assert_not response.success?
      assert response.error.is_a?(Provider::ExchangeRateApi::Error)
    end
  end
end