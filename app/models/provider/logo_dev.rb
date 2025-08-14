class Provider::LogoDev < Provider
  # Subclass so errors caught in this provider are raised as Provider::LogoDev::Error
  Error = Class.new(Provider::Error)
  InvalidLogoError = Class.new(Error)

  def initialize(api_key = nil)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      # Test with a well-known domain
      response = client.get(logo_url("microsoft.com"))
      
      # Logo.dev returns 200 even for missing logos (with fallback), so check content type
      response.success? && response.headers["content-type"]&.start_with?("image/")
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

      # Test if the logo exists by making a HEAD request
      logo_endpoint = logo_url(lookup_domain)
      response = client.head(logo_endpoint)
      
      if response.success? && response.headers["content-type"]&.start_with?("image/")
        logo_endpoint
      else
        # Logo.dev provides fallback images, but we might want to return nil for missing logos
        # For now, return the URL as Logo.dev handles missing logos gracefully
        logo_endpoint
      end
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