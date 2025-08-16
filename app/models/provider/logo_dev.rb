class Provider::LogoDev < Provider
  # Subclass so errors caught in this provider are raised as Provider::LogoDev::Error
  Error = Class.new(Provider::Error)
  InvalidLogoError = Class.new(Error)

  def initialize(api_key = nil)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      # Test the hybrid approach with a well-known domain
      begin
        test_logo = fetch_logo_url(domain: "microsoft.com")
        # Should always succeed with either Logo.dev or favicon fallback
        test_logo.present?
      rescue => e
        Rails.logger.warn("#{self.class.name} health check failed: #{e.message}")
        false
      end
    end
  end

  def usage
    with_provider_response do
      # Logo.dev doesn't provide usage API, return estimated values
      # Free tier has daily limits but they're not publicly specified
      UsageData.new(
        used: 0,
        limit: api_key.present? ? 5000 : 100, # Estimated daily limits
        utilization: 0,
        plan: api_key.present? ? "free" : "unauthenticated"
      )
    end
  end

  # ================================
  #           Logo Fetching
  # ================================

  def fetch_logo_url(company_name: nil, domain: nil, symbol: nil)
    with_provider_response do
      # Determine the best domain to use for logo lookup
      lookup_domain = determine_lookup_domain(company_name: company_name, domain: domain, symbol: symbol)
      
      if lookup_domain.blank?
        raise InvalidLogoError.new("No valid domain found for logo lookup")
      end

      # Check cache first
      cache_key = "logo_provider:#{lookup_domain}:v1"
      cached_result = Rails.cache.read(cache_key)
      if cached_result
        Rails.logger.info("#{self.class.name}: Cache hit for #{lookup_domain}")
        return cached_result
      end
      Rails.logger.info("#{self.class.name}: Cache miss for #{lookup_domain}")

      # Try Logo.dev first (high quality)
      logo_url = try_logo_dev(lookup_domain)
      
      final_url = if logo_url
        Rails.logger.info("#{self.class.name}: Using Logo.dev for #{lookup_domain}")
        logo_url
      else
        # Fallback to Google Favicon API (always works)
        favicon_url = fetch_favicon_fallback(lookup_domain)
        Rails.logger.info("#{self.class.name}: Using favicon fallback for #{lookup_domain}")
        favicon_url
      end
      
      # Cache the result
      cache_duration = logo_url ? 24.hours : 1.week
      Rails.cache.write(cache_key, final_url, expires_in: cache_duration)
      Rails.logger.info("#{self.class.name}: Cached result for #{lookup_domain} (#{cache_duration / 1.hour}h)")
      
      final_url
    end
  end

  def fetch_logo_urls(queries)
    with_provider_response do
      results = {}
      
      queries.each do |key, query_params|
        begin
          logo_url = fetch_logo_url(**query_params)
          results[key] = logo_url
        rescue InvalidLogoError => e
          Rails.logger.warn("#{self.class.name} failed to fetch logo for #{key}: #{e.message}")
          results[key] = nil
        end
        
        # Add small delay to respect rate limits
        sleep(0.1) if api_key.present?
      end
      
      results
    end
  end

  private
    attr_reader :api_key
    
    # Try Logo.dev provider first
    def try_logo_dev(domain)
      logo_endpoint = logo_url(domain)
      response = client.head(logo_endpoint)
      
      # Check if Logo.dev has a real logo (not just a fallback)
      if response.success? && response.headers["content-type"]&.start_with?("image/")
        # For now, trust Logo.dev's response - they handle fallbacks well
        # We can add more sophisticated detection later if needed
        Rails.logger.info("#{self.class.name}: Found logo via Logo.dev for #{domain}")
        return logo_endpoint
      end
      
      Rails.logger.info("#{self.class.name}: No suitable logo found for #{domain}, falling back to favicon")
      nil
    rescue => e
      Rails.logger.warn("#{self.class.name}: Logo.dev request failed for #{domain}: #{e.message}")
      nil
    end
    
    # Google Favicon API fallback (always works)
    def fetch_favicon_fallback(domain)
      # Google's favicon service with higher resolution
      favicon_url = "https://www.google.com/s2/favicons?domain=#{domain}&sz=128"
      
      Rails.logger.info("#{self.class.name}: Using favicon fallback for #{domain}")
      
      favicon_url
    end

    def base_url
      "https://img.logo.dev"
    end

    def logo_url(domain, size: 200, format: "png")
      url = "#{base_url}/#{domain}"
      params = []
      params << "token=#{api_key}" if api_key.present?
      params << "size=#{size}" if size
      params << "format=#{format}" if format
      
      url += "?#{params.join('&')}" if params.any?
      url
    end

    def determine_lookup_domain(company_name: nil, domain: nil, symbol: nil)
      # Priority: explicit domain > derive from company name > derive from symbol
      return domain if domain.present?
      return derive_domain_from_company_name(company_name) if company_name.present?
      return derive_domain_from_symbol(symbol) if symbol.present?
      
      nil
    end

    def derive_domain_from_company_name(company_name)
      # Simple heuristic to derive domain from company name
      # This is not perfect but handles common cases
      normalized_name = company_name.downcase
        .gsub(/\b(inc|corp|corporation|company|co|ltd|limited|llc|plc)\b/, '') # Remove corporate suffixes
        .gsub(/[^a-z0-9\s]/, '') # Remove special characters
        .strip
        .gsub(/\s+/, '') # Remove spaces
      
      return nil if normalized_name.blank?
      
      # For well-known companies, we might want a mapping
      # For now, use simple heuristic
      "#{normalized_name}.com"
    end

    def derive_domain_from_symbol(symbol)
      # For stock symbols, this is very challenging without a mapping
      # Common patterns for major companies
      symbol_to_domain_mapping = {
        "AAPL" => "apple.com",
        "MSFT" => "microsoft.com", 
        "GOOGL" => "google.com",
        "GOOG" => "google.com",
        "AMZN" => "amazon.com",
        "TSLA" => "tesla.com",
        "META" => "meta.com",
        "NVDA" => "nvidia.com",
        "NFLX" => "netflix.com",
        "CRM" => "salesforce.com",
        "ORCL" => "oracle.com",
        "IBM" => "ibm.com",
        "INTC" => "intel.com",
        "AMD" => "amd.com"
      }
      
      mapped_domain = symbol_to_domain_mapping[symbol.upcase]
      return mapped_domain if mapped_domain
      
      # Fallback: try {symbol}.com (often doesn't work but worth trying)
      "#{symbol.downcase}.com"
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