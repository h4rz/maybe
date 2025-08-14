require "test_helper"
require "ostruct"

class Provider::AlphaVantageTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest, SecurityProviderInterfaceTest
  # Disable fixtures for this test
  self.use_transactional_tests = false
  fixtures :none

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

  test "search securities includes logos from Logo.dev" do
    # Mock the Logo.dev provider
    logo_provider = mock
    Provider::Registry.stubs(:get_provider).with(:logo_dev).returns(logo_provider)
    
    # Mock logo responses
    logo_response = mock
    logo_response.stubs(:success?).returns(true)
    logo_response.stubs(:data).returns("https://img.logo.dev/apple.com?token=test&size=200&format=png")
    logo_provider.stubs(:fetch_logo_url).returns(logo_response)
    
    VCR.use_cassette("alpha_vantage/search_with_logos") do
      securities = @alpha_vantage.search_securities("AAPL").data
      
      assert securities.any?
      securities.each do |security|
        assert security.logo_url.present?, "Security should have logo URL"
        assert security.logo_url.include?("logo.dev"), "Logo URL should be from Logo.dev"
      end
    end
  end

  test "search securities handles logo fetch failures gracefully" do
    # Mock the Logo.dev provider to fail
    logo_provider = mock
    Provider::Registry.stubs(:get_provider).with(:logo_dev).returns(logo_provider)
    
    # Mock logo failure
    logo_provider.stubs(:fetch_logo_url).raises(StandardError.new("Logo fetch failed"))
    
    VCR.use_cassette("alpha_vantage/search_with_logo_failures") do
      securities = @alpha_vantage.search_securities("AAPL").data
      
      assert securities.any?
      securities.each do |security|
        assert_nil security.logo_url, "Logo URL should be nil when fetch fails"
      end
    end
  end

  test "fetch security info includes logo from Logo.dev" do
    # Mock the Logo.dev provider
    logo_provider = mock
    Provider::Registry.stubs(:get_provider).with(:logo_dev).returns(logo_provider)
    
    # Mock logo response
    logo_response = mock
    logo_response.stubs(:success?).returns(true)
    logo_response.stubs(:data).returns("https://img.logo.dev/apple.com?token=test&size=200&format=png")
    logo_provider.stubs(:fetch_logo_url).returns(logo_response)
    
    VCR.use_cassette("alpha_vantage/security_info_with_logo") do
      security_info = @alpha_vantage.fetch_security_info(symbol: "AAPL", exchange_operating_mic: nil).data
      
      assert security_info.logo_url.present?, "Security info should have logo URL"
      assert security_info.logo_url.include?("logo.dev"), "Logo URL should be from Logo.dev"
    end
  end

  test "handles missing Logo.dev provider gracefully" do
    # Mock missing logo provider
    Provider::Registry.stubs(:get_provider).with(:logo_dev).returns(nil)
    
    VCR.use_cassette("alpha_vantage/search_no_logo_provider") do
      securities = @alpha_vantage.search_securities("AAPL").data
      
      assert securities.any?
      securities.each do |security|
        assert_nil security.logo_url, "Logo URL should be nil when no provider available"
      end
    end
  end
end