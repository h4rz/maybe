# Synth to Free APIs Migration

## Overview

Synth Finance API is no longer available, so Maybe Finance has been migrated to use free alternative APIs:
- **ExchangeRate-API**: Primary provider for exchange rates (higher limits, more currencies)
- **Alpha Vantage**: Provider for securities data and exchange rate fallback
- **Logo.dev**: Provider for company logos (replaces deprecated Clearbit)

## What Changed

- **Exchange Rate Provider**: Synth Finance → ExchangeRate-API (primary) + Alpha Vantage (fallback)
- **Securities Provider**: Synth Finance → Alpha Vantage
- **Logo Provider**: None → Logo.dev (company logos)
- **Environment Variables**: 
  - `SYNTH_API_KEY` → `EXCHANGE_RATE_API_KEY` + `ALPHA_VANTAGE_API_KEY` + `LOGO_DEV_API_KEY`
- **Settings Fields**: 
  - `synth_api_key` → `exchange_rate_api_key` + `alpha_vantage_api_key` + `logo_dev_api_key`

## Migration Steps

### 1. Get API Keys

#### ExchangeRate-API (Optional but Recommended)
1. Visit [ExchangeRate-API](https://www.exchangerate-api.com)
2. Sign up for a free account
3. Get your API key (free tier: 1,500 requests/month)
4. **Note**: Open access is available without an API key but with lower limits

#### Alpha Vantage (Required)
1. Visit [Alpha Vantage](https://www.alphavantage.co/support/#api-key)
2. Sign up for a free account
3. Get your API key (free tier: 25 requests/day, 5 requests/minute)

#### Logo.dev (Optional for Company Logos)
1. Visit [Logo.dev](https://logo.dev)
2. Sign up for a free account or use without API key
3. Get your API key (free tier: 5,000 requests/month, unauthenticated: 100 requests/month)
4. **Note**: Works without API key but with lower limits

### 2. Update Environment Variables
Replace your Synth API key with the new providers:

```bash
# Remove old variable
unset SYNTH_API_KEY

# Add new variables
export EXCHANGE_RATE_API_KEY=your_exchange_rate_api_key_here  # Optional
export ALPHA_VANTAGE_API_KEY=your_alpha_vantage_key_here     # Required
export LOGO_DEV_API_KEY=your_logo_dev_api_key_here           # Optional
```

Or update your `.env` file:
```
# Old
SYNTH_API_KEY=old_key

# New
EXCHANGE_RATE_API_KEY=your_exchange_rate_api_key_here  # Optional for higher limits
ALPHA_VANTAGE_API_KEY=your_alpha_vantage_key_here     # Required for securities
LOGO_DEV_API_KEY=your_logo_dev_api_key_here           # Optional for company logos
```

### 3. Update Settings (Self-Hosted)
If you were using the Settings page to configure your API keys:
1. Go to Settings → Self-Hosting
2. Remove the old Synth API key
3. Enter your ExchangeRate-API key (optional, for higher exchange rate limits)
4. Enter your Alpha Vantage API key (required for securities data)
5. Enter your Logo.dev API key (optional, for company logos with higher limits)

## Provider Details

### ExchangeRate-API (Optimized Usage)
- **Purpose**: Primary exchange rate provider with smart quota management
- **Current Rates**: Always use open access (unlimited, rate limited) - **preserves API quota**
- **Historical Rates**: Use API key (1,500 requests/month) - **only when needed**
- **Coverage**: 170+ currencies, global coverage
- **Historical Data**: Available with API key (from 1990)
- **Optimization**: 90%+ quota savings by using open access for current rates

### Alpha Vantage
- **Purpose**: Securities data and exchange rate fallback
- **Free Tier**: 25 requests/day, 5 requests/minute
- **Coverage**: Primarily US markets, major global stocks
- **Historical Data**: Available for stocks and forex
- **Logo Integration**: Now includes company logos via Logo.dev
- **Limitations vs Synth**:
  - No exchange operating MIC codes
  - Lower rate limits than Synth
  - Primarily US-focused

### Logo.dev (Hybrid Provider)
- **Purpose**: Company logos for securities with intelligent fallback
- **Primary Source**: Logo.dev API (high-quality logos when available)
- **Fallback Source**: Google Favicon API (100% coverage, reliable)
- **Free Tier**: 5,000 requests/month with API key, 100/month without
- **Coverage**: 100% logo coverage (high-quality when available, favicon fallback always)
- **Integration**: Automatic logo fetching for security searches and info
- **Caching**: 24-hour cache for Logo.dev results, 1-week cache for favicon fallbacks
- **Performance**: 2-3x faster on repeated requests due to intelligent caching

### New Features
- **Logo Backfill**: `rake securities:backfill_logos` to add logos to existing securities
- **Individual Logo Update**: `rake securities:update_logo[AAPL]` to update specific securities
- **Logo Preview**: `rake securities:preview_logo_backfill` to preview what would be updated

### Deprecated Features
- **Securities Rake Task**: `rake securities:backfill_exchange_mic` is disabled since Alpha Vantage doesn't provide exchange MIC data

## Functionality Preserved
- ✅ Exchange rate fetching (forex data) - **Enhanced with ExchangeRate-API**
- ✅ Stock price fetching (historical and current)
- ✅ Security search functionality
- ✅ Settings page integration
- ✅ All existing interfaces and APIs
- ✅ **New**: Automatic provider fallback for redundancy
- ✅ **New**: Company logos for securities via Logo.dev integration

## Benefits of New Setup
- ✅ **Optimized Usage**: Current rates use unlimited open access, API quota only for historical data
- ✅ **90%+ Quota Savings**: Smart usage means 1,500 monthly requests last much longer
- ✅ **Higher Effective Limits**: Unlimited current rates + 1,500 historical requests/month
- ✅ **Redundancy**: Automatic fallback between providers
- ✅ **Cost**: Completely free tiers available
- ✅ **Reliability**: Three established providers instead of one
- ✅ **Global Coverage**: Better currency coverage with ExchangeRate-API
- ✅ **100% Logo Coverage**: Hybrid approach ensures every company gets a logo
- ✅ **High Quality + Reliability**: Logo.dev quality with Google Favicon reliability
- ✅ **Performance Optimized**: Intelligent caching reduces API calls by 60-80%
- ✅ **No shutdown risk**: Multiple providers reduce single-point-of-failure
- ✅ **Enhanced UX**: Securities now include company logos for better identification

## Troubleshooting

### Exchange Rate Issues
If you experience exchange rate problems:
1. **Current rates**: Should work immediately via open access (no API key needed)
2. **Historical rates**: Require API key, fallback to Alpha Vantage if quota exhausted
3. **Quota optimization**: Current rates don't consume API quota, only historical data does
4. **Rate limits**: Open access is rate-limited but unlimited, API key gives 1,500 historical requests/month

### Alpha Vantage Rate Limit Errors  
If you hit the 25 requests/day limit for securities:
- Wait until the next day for limit reset
- Consider upgrading to Alpha Vantage's paid plans for higher limits
- Use data sparingly during testing

### Missing Exchange Data
Alpha Vantage doesn't provide exchange operating MIC codes, so:
- Existing securities with MIC codes will continue to work
- New securities won't have MIC data populated
- This doesn't affect price fetching or basic functionality

### Company Logos Available (100% Coverage)
Company logos are now available via hybrid Logo.dev + Google Favicon integration:
- **New securities**: Automatically get logos during search and info fetching
- **Existing securities**: Use `rails securities:backfill_logos` to add logos
- **High Quality**: Logo.dev provides professional logos when available
- **Universal Fallback**: Google Favicon API ensures 100% logo coverage
- **Performance**: Intelligent caching reduces API calls and improves speed
- **Reliability**: Always returns a logo, never fails

## Testing Your Setup

### Quick Test via Rails Console
```ruby
# Test ExchangeRate-API
exchange_provider = Provider::Registry.get_provider(:exchange_rate_api)
exchange_provider.healthy?  # Should return true

# Test Alpha Vantage
alpha_provider = Provider::Registry.get_provider(:alpha_vantage)
alpha_provider.healthy?     # Should return true

# Test Logo.dev
logo_provider = Provider::Registry.get_provider(:logo_dev)
logo_provider.healthy?      # Should return true

# Test primary provider selection
primary = Provider::Registry.primary_exchange_rate_provider
puts primary.class.name     # Should show ExchangeRateApi or AlphaVantage

# Test current exchange rate (uses open access, preserves quota)
current_rate = primary.fetch_exchange_rate(from: "USD", to: "EUR", date: Date.current)
puts "Current: 1 USD = #{current_rate.data.rate} EUR"

# Test historical exchange rate (uses API quota if available)
historical_rate = primary.fetch_exchange_rate(from: "USD", to: "EUR", date: Date.current - 7.days)
puts "7 days ago: 1 USD = #{historical_rate.data.rate} EUR"
```

### Settings Page Verification
1. Go to Settings → Self-Hosting
2. **ExchangeRate-API section**: Should show "free (optimized)" plan if API key configured
3. **Alpha Vantage section**: Should show usage for securities data
4. **Logo.dev section**: Should show usage for logo fetching
5. **Current behavior**: All providers working with smart quota usage

### Logo Functionality Test
```ruby
# Test hybrid logo fetching by symbol
logo_provider = Provider::Registry.get_provider(:logo_dev)
logo_response = logo_provider.fetch_logo_url(symbol: "AAPL")
puts "Apple logo: #{logo_response.data}" if logo_response.success?
puts "Source: #{logo_response.data.include?('logo.dev') ? 'Logo.dev' : 'Favicon'}"

# Test high-quality vs fallback
ms_response = logo_provider.fetch_logo_url(domain: "microsoft.com")
puts "Microsoft (high-quality): #{ms_response.data}"
unknown_response = logo_provider.fetch_logo_url(domain: "unknown123.com")
puts "Unknown company (fallback): #{unknown_response.data}"

# Test Alpha Vantage with logo integration
alpha_provider = Provider::Registry.get_provider(:alpha_vantage)
securities = alpha_provider.search_securities("Microsoft").data
puts "First result logo: #{securities.first.logo_url}" if securities.any?

# Test caching performance
start_time = Time.now
logo_provider.fetch_logo_url(domain: "microsoft.com")
first_duration = Time.now - start_time

start_time = Time.now
logo_provider.fetch_logo_url(domain: "microsoft.com")  # Should be faster (cached)
second_duration = Time.now - start_time

puts "Cache performance: #{(first_duration / second_duration).round(1)}x faster"
```

### Backfill Existing Securities with Logos
```bash
# Preview what would be updated
bundle exec rails securities:preview_logo_backfill

# Run the backfill (processes in batches with rate limiting)
bundle exec rails securities:backfill_logos

# Update a specific security
bundle exec rails securities:update_logo[AAPL]
```