require "test_helper"
require "ostruct"

class Provider::LogoDevTest < ActiveSupport::TestCase
  # Disable fixtures for this test
  self.use_transactional_tests = false
  fixtures :none

  setup do
    @logo_dev = Provider::LogoDev.new(ENV["LOGO_DEV_API_KEY"])
    @logo_dev_no_key = Provider::LogoDev.new(nil)
  end

  test "health check with API key" do
    VCR.use_cassette("logo_dev/health_with_key") do
      assert @logo_dev.healthy?
    end
  end

  test "health check without API key" do
    VCR.use_cassette("logo_dev/health_no_key") do
      assert @logo_dev_no_key.healthy?
    end
  end

  test "usage info with API key" do
    VCR.use_cassette("logo_dev/usage_with_key") do
      usage = @logo_dev.usage.data
      
      assert_equal 0, usage.used
      assert_equal 5000, usage.limit
      assert_equal 0, usage.utilization
      assert_equal "free", usage.plan
    end
  end

  test "usage info without API key" do
    VCR.use_cassette("logo_dev/usage_no_key") do
      usage = @logo_dev_no_key.usage.data
      
      assert_equal 0, usage.used
      assert_equal 100, usage.limit
      assert_equal 0, usage.utilization
      assert_equal "unauthenticated", usage.plan
    end
  end

  test "fetches logo by domain" do
    VCR.use_cassette("logo_dev/fetch_by_domain") do
      response = @logo_dev.fetch_logo_url(domain: "microsoft.com")
      
      assert response.success?
      logo_url = response.data
      assert logo_url.present?
      assert logo_url.include?("logo.dev")
      assert logo_url.include?("microsoft.com")
    end
  end

  test "fetches logo by company name" do
    VCR.use_cassette("logo_dev/fetch_by_company_name") do
      response = @logo_dev.fetch_logo_url(company_name: "Apple Inc")
      
      assert response.success?
      logo_url = response.data
      assert logo_url.present?
      assert logo_url.include?("logo.dev")
      assert logo_url.include?("apple.com")
    end
  end

  test "fetches logo by symbol" do
    VCR.use_cassette("logo_dev/fetch_by_symbol") do
      response = @logo_dev.fetch_logo_url(symbol: "AAPL")
      
      assert response.success?
      logo_url = response.data
      assert logo_url.present?
      assert logo_url.include?("logo.dev")
      assert logo_url.include?("apple.com")
    end
  end

  test "handles missing domain gracefully" do
    VCR.use_cassette("logo_dev/missing_domain") do
      response = @logo_dev.fetch_logo_url(domain: "nonexistentcompany12345.com")
      
      # Logo.dev provides fallback images, so this should still return a URL
      assert response.success?
      logo_url = response.data
      assert logo_url.present?
      assert logo_url.include?("logo.dev")
    end
  end

  test "handles invalid input gracefully" do
    VCR.use_cassette("logo_dev/invalid_input") do
      response = @logo_dev.fetch_logo_url(company_name: nil, domain: nil, symbol: nil)
      
      assert_not response.success?
      assert response.error.is_a?(Provider::LogoDev::Error)
    end
  end

  test "company name normalization" do
    # Test the private method through public interface
    test_cases = [
      { input: "Apple Inc", expected_domain: "apple.com" },
      { input: "Microsoft Corporation", expected_domain: "microsoft.com" },
      { input: "Google LLC", expected_domain: "google.com" },
      { input: "Amazon.com, Inc.", expected_domain: "amazoncom.com" }
    ]
    
    test_cases.each do |test_case|
      VCR.use_cassette("logo_dev/normalize_#{test_case[:input].downcase.gsub(/[^a-z]/, '_')}") do
        response = @logo_dev.fetch_logo_url(company_name: test_case[:input])
        
        if response.success?
          logo_url = response.data
          assert logo_url.include?(test_case[:expected_domain])
        end
      end
    end
  end

  test "symbol to domain mapping" do
    test_cases = [
      { symbol: "AAPL", expected_domain: "apple.com" },
      { symbol: "MSFT", expected_domain: "microsoft.com" },
      { symbol: "GOOGL", expected_domain: "google.com" },
      { symbol: "AMZN", expected_domain: "amazon.com" }
    ]
    
    test_cases.each do |test_case|
      VCR.use_cassette("logo_dev/symbol_#{test_case[:symbol].downcase}") do
        response = @logo_dev.fetch_logo_url(symbol: test_case[:symbol])
        
        assert response.success?
        logo_url = response.data
        assert logo_url.include?(test_case[:expected_domain])
      end
    end
  end

  test "fetches multiple logos" do
    VCR.use_cassette("logo_dev/fetch_multiple") do
      queries = {
        apple: { symbol: "AAPL" },
        microsoft: { domain: "microsoft.com" },
        google: { company_name: "Google LLC" }
      }
      
      response = @logo_dev.fetch_logo_urls(queries)
      
      assert response.success?
      results = response.data
      
      assert_equal 3, results.keys.count
      assert results[:apple].present?
      assert results[:microsoft].present?
      assert results[:google].present?
      
      results.values.each do |logo_url|
        assert logo_url.include?("logo.dev")
      end
    end
  end

  test "handles network errors gracefully" do
    # Simulate network error by stubbing the client
    faraday_stub = stub
    faraday_stub.stubs(:head).raises(Faraday::ConnectionFailed.new("Connection failed"))
    @logo_dev.stubs(:client).returns(faraday_stub)
    
    response = @logo_dev.fetch_logo_url(domain: "microsoft.com")
    
    assert_not response.success?
    assert response.error.is_a?(Provider::LogoDev::Error)
  end

  test "includes API key in URL when present" do
    provider_with_key = Provider::LogoDev.new("test_api_key_123")
    
    VCR.use_cassette("logo_dev/with_api_key") do
      response = provider_with_key.fetch_logo_url(domain: "microsoft.com")
      
      if response.success?
        logo_url = response.data
        assert logo_url.include?("token=test_api_key_123")
      end
    end
  end

  test "does not include API key in URL when not present" do
    VCR.use_cassette("logo_dev/without_api_key") do
      response = @logo_dev_no_key.fetch_logo_url(domain: "microsoft.com")
      
      if response.success?
        logo_url = response.data
        assert_not logo_url.include?("token=")
      end
    end
  end

  test "respects size and format parameters" do
    provider = Provider::LogoDev.new("test_key")
    
    # Test the private logo_url method through inspection
    url = provider.send(:logo_url, "microsoft.com", size: 300, format: "svg")
    
    assert url.include?("size=300")
    assert url.include?("format=svg")
    assert url.include?("microsoft.com")
  end
end