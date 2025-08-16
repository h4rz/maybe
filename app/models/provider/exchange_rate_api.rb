class Provider::ExchangeRateApi < Provider
  include ExchangeRateConcept

  # Subclass so errors caught in this provider are raised as Provider::ExchangeRateApi::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      # Test with a simple current rate request
      response = client.get("#{base_url}/latest/USD") do |req|
        req.params["access_key"] = api_key if api_key.present?
      end

      data = JSON.parse(response.body)
      
      # Check if we get a valid response (not an error message)
      data["success"] == true && data.dig("rates").present?
    end
  end

  def usage
    with_provider_response do
      # ExchangeRate-API doesn't provide usage API, return estimated values
      # With optimized usage: API quota only for historical data, open access for current rates
      if api_key.present?
        UsageData.new(
          used: 0, # TODO: Could track historical requests if needed
          limit: 1500, # Monthly limit for historical data only
          utilization: 0,
          plan: "free (optimized: current rates use open access)"
        )
      else
        UsageData.new(
          used: 0,
          limit: Float::INFINITY, # Open access for current rates
          utilization: 0,
          plan: "open (current rates only)"
        )
      end
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      if date < Date.current
        # Historical data - use API key if available for historical endpoint
        if api_key.present?
          fetch_historical_rate(from: from, to: to, date: date)
        else
          # No API key for historical data, let provider response handle fallback to Alpha Vantage
          raise InvalidExchangeRateError.new("Historical data requires API key, falling back to Alpha Vantage")
        end
      else
        # Current data - always use open access to preserve API quota
        fetch_current_rate_open_access(from: from, to: to)
      end
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      rates = []
      current_date = start_date.to_date
      today = Date.current

      # Check if range includes any historical dates
      has_historical_dates = start_date.to_date < today
      
      if has_historical_dates && api_key.blank?
        raise InvalidExchangeRateError.new("Historical data requires API key")
      end

      while current_date <= end_date.to_date
        begin
          if current_date < today
            # Historical data - use API key quota
            rate = fetch_historical_rate(from: from, to: to, date: current_date)
          else
            # Current data - use open access to preserve quota
            rate = fetch_current_rate_open_access(from: from, to: to)
          end
          
          rates << rate if rate
        rescue InvalidExchangeRateError => e
          Rails.logger.warn("#{self.class.name} failed to fetch rate for #{from}/#{to} on #{current_date}: #{e.message}")
          # Continue with next date
        end
        
        current_date += 1.day
        
        # Add small delay to respect rate limits (only when using API key)
        sleep(0.1) if current_date < today && api_key.present?
      end

      rates.sort_by(&:date)
    end
  end

  private
    attr_reader :api_key

    def base_url
      if api_key.present?
        "https://api.exchangerate-api.com/v4"
      else
        # Open access endpoint (no key required)
        "https://api.exchangerate-api.com/v4"
      end
    end

    def fetch_current_rate(from:, to:)
      response = client.get("#{base_url}/latest/#{from}") do |req|
        req.params["access_key"] = api_key if api_key.present?
      end

      data = JSON.parse(response.body)
      
      if data["success"] == false || data["error"].present?
        error_message = data.dig("error", "info") || data["error"] || "Unknown error"
        raise InvalidExchangeRateError.new(error_message)
      end

      rates = data.dig("rates")
      
      if rates.nil? || rates[to].nil?
        raise InvalidExchangeRateError.new("No exchange rate data found for #{from}/#{to}")
      end

      rate = rates[to].to_f

      Rate.new(
        date: Date.current,
        from: from,
        to: to,
        rate: rate
      )
    end

    def fetch_current_rate_open_access(from:, to:)
      # Always use open access (no API key) to preserve quota for historical data
      response = client.get("#{base_url}/latest/#{from}")

      data = JSON.parse(response.body)
      
      if data["success"] == false || data["error"].present?
        error_message = data.dig("error", "info") || data["error"] || "Unknown error"
        raise InvalidExchangeRateError.new(error_message)
      end

      rates = data.dig("rates")
      
      if rates.nil? || rates[to].nil?
        raise InvalidExchangeRateError.new("No exchange rate data found for #{from}/#{to}")
      end

      rate = rates[to].to_f

      Rate.new(
        date: Date.current,
        from: from,
        to: to,
        rate: rate
      )
    end

    def fetch_historical_rate(from:, to:, date:)
      # Historical endpoint format: /YYYY-MM-DD/base_currency
      date_str = date.strftime("%Y-%m-%d")
      
      response = client.get("#{base_url}/#{date_str}/#{from}") do |req|
        req.params["access_key"] = api_key if api_key.present?
      end

      data = JSON.parse(response.body)
      
      if data["success"] == false || data["error"].present?
        error_message = data.dig("error", "info") || data["error"] || "Unknown error"
        raise InvalidExchangeRateError.new(error_message)
      end

      rates = data.dig("rates")
      
      if rates.nil? || rates[to].nil?
        raise InvalidExchangeRateError.new("No exchange rate data found for #{from}/#{to} on #{date}")
      end

      rate = rates[to].to_f

      Rate.new(
        date: date.to_date,
        from: from,
        to: to,
        rate: rate
      )
    end

    def client
      @client ||= Faraday.new do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.response :raise_error
        faraday.headers["User-Agent"] = "Maybe Finance App"
      end
    end
end