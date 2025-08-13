class Provider::AlphaVantage < Provider
  include ExchangeRateConcept, SecurityConcept

  # Subclass so errors caught in this provider are raised as Provider::AlphaVantage::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  InvalidSecurityPriceError = Class.new(Error)

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      # Test with a simple stock quote
      response = client.get(base_url) do |req|
        req.params["function"] = "GLOBAL_QUOTE"
        req.params["symbol"] = "AAPL"
        req.params["apikey"] = api_key
      end

      data = JSON.parse(response.body)
      # Check if we get a valid response (not an error message)
      data.dig("Global Quote").present? && !data.key?("Error Message")
    end
  end

  def usage
    with_provider_response do
      # Alpha Vantage doesn't provide usage API, return default values
      # Free tier: 25 requests/day, 5 requests/minute
      UsageData.new(
        used: 0,
        limit: 25,
        utilization: 0,
        plan: "free"
      )
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      # For historical rates, we need to use FX_DAILY and find the specific date
      response = client.get(base_url) do |req|
        req.params["function"] = "FX_DAILY"
        req.params["from_symbol"] = from
        req.params["to_symbol"] = to
        req.params["apikey"] = api_key
        req.params["outputsize"] = "compact"
      end

      data = JSON.parse(response.body)
      
      if data.key?("Error Message")
        raise InvalidExchangeRateError.new(data["Error Message"])
      end

      time_series = data.dig("Time Series FX (Daily)")
      
      if time_series.nil?
        raise InvalidExchangeRateError.new("No exchange rate data found")
      end

      # Find the closest date (Alpha Vantage may not have data for weekends/holidays)
      target_date = date.to_s
      rate_data = time_series[target_date] || time_series.values.first

      if rate_data.nil?
        raise InvalidExchangeRateError.new("No rate data found for date #{date}")
      end

      rate = rate_data["4. close"].to_f

      Rate.new(date: date.to_date, from: from, to: to, rate: rate)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      response = client.get(base_url) do |req|
        req.params["function"] = "FX_DAILY"
        req.params["from_symbol"] = from
        req.params["to_symbol"] = to
        req.params["apikey"] = api_key
        req.params["outputsize"] = "full"
      end

      data = JSON.parse(response.body)
      
      if data.key?("Error Message")
        raise InvalidExchangeRateError.new(data["Error Message"])
      end

      time_series = data.dig("Time Series FX (Daily)")
      
      if time_series.nil?
        raise InvalidExchangeRateError.new("No exchange rate data found")
      end

      rates = []
      time_series.each do |date_str, rate_data|
        date = Date.parse(date_str)
        
        # Filter by date range
        next if date < start_date.to_date || date > end_date.to_date
        
        rate = rate_data["4. close"]&.to_f
        
        if rate.nil?
          Rails.logger.warn("#{self.class.name} returned invalid rate data for pair from: #{from} to: #{to} on: #{date}")
          next
        end

        rates << Rate.new(date: date, from: from, to: to, rate: rate)
      end

      rates.sort_by(&:date)
    end
  end

  # ================================
  #           Securities
  # ================================

  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      response = client.get(base_url) do |req|
        req.params["function"] = "SYMBOL_SEARCH"
        req.params["keywords"] = symbol
        req.params["apikey"] = api_key
      end

      data = JSON.parse(response.body)
      
      if data.key?("Error Message")
        raise Error.new(data["Error Message"])
      end

      best_matches = data.dig("bestMatches") || []

      securities = best_matches.map do |match|
        Security.new(
          symbol: match["1. symbol"],
          name: match["2. name"],
          logo_url: nil, # Alpha Vantage doesn't provide logos
          exchange_operating_mic: nil, # Not provided by Alpha Vantage
          country_code: match["4. region"]
        )
      end

      # Filter by country_code if provided
      if country_code.present?
        securities = securities.select { |s| s.country_code == country_code }
      end

      securities.take(25) # Limit to 25 results like Synth
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      # Alpha Vantage doesn't have a dedicated company info endpoint in free tier
      # We'll use the overview function or return basic info from quote
      response = client.get(base_url) do |req|
        req.params["function"] = "GLOBAL_QUOTE"
        req.params["symbol"] = symbol
        req.params["apikey"] = api_key
      end

      data = JSON.parse(response.body)
      
      if data.key?("Error Message")
        raise Error.new(data["Error Message"])
      end

      quote = data.dig("Global Quote")
      
      if quote.nil?
        raise Error.new("No security info found for symbol #{symbol}")
      end

      SecurityInfo.new(
        symbol: symbol,
        name: quote["01. symbol"], # Alpha Vantage doesn't provide company name in quote
        links: nil,
        logo_url: nil,
        description: nil,
        kind: "stock", # Default to stock
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      historical_data = fetch_security_prices(symbol: symbol, exchange_operating_mic: exchange_operating_mic, start_date: date, end_date: date)

      if historical_data.data.empty?
        raise Error.new("No prices found for security #{symbol} on date #{date}")
      end

      historical_data.data.first
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      response = client.get(base_url) do |req|
        req.params["function"] = "TIME_SERIES_DAILY"
        req.params["symbol"] = symbol
        req.params["apikey"] = api_key
        req.params["outputsize"] = "full"
      end

      data = JSON.parse(response.body)
      
      if data.key?("Error Message")
        raise InvalidSecurityPriceError.new(data["Error Message"])
      end

      time_series = data.dig("Time Series (Daily)")
      
      if time_series.nil?
        raise InvalidSecurityPriceError.new("No price data found for symbol #{symbol}")
      end

      prices = []
      time_series.each do |date_str, price_data|
        date = Date.parse(date_str)
        
        # Filter by date range
        next if date < start_date.to_date || date > end_date.to_date
        
        close_price = price_data["4. close"]&.to_f
        
        if close_price.nil?
          Rails.logger.warn("#{self.class.name} returned invalid price data for security #{symbol} on: #{date}")
          next
        end

        prices << Price.new(
          symbol: symbol,
          date: date,
          price: close_price,
          currency: "USD", # Alpha Vantage primarily uses USD
          exchange_operating_mic: exchange_operating_mic
        )
      end

      prices.sort_by(&:date)
    end
  end

  private
    attr_reader :api_key

    def base_url
      "https://www.alphavantage.co/query"
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