# Synth to Alpha Vantage Migration

## Overview

Synth Finance API is no longer available, so Maybe Finance has been migrated to use Alpha Vantage as the financial data provider for exchange rates and stock prices.

## What Changed

- **Provider**: Synth Finance → Alpha Vantage
- **Environment Variable**: `SYNTH_API_KEY` → `ALPHA_VANTAGE_API_KEY`
- **Settings Field**: `synth_api_key` → `alpha_vantage_api_key`

## Migration Steps

### 1. Get Alpha Vantage API Key
1. Visit [Alpha Vantage](https://www.alphavantage.co/support/#api-key)
2. Sign up for a free account
3. Get your API key (free tier: 25 requests/day, 5 requests/minute)

### 2. Update Environment Variables
Replace your Synth API key with Alpha Vantage:

```bash
# Remove old variable
unset SYNTH_API_KEY

# Add new variable
export ALPHA_VANTAGE_API_KEY=your_alpha_vantage_key_here
```

Or update your `.env` file:
```
# Old
SYNTH_API_KEY=old_key

# New
ALPHA_VANTAGE_API_KEY=your_alpha_vantage_key_here
```

### 3. Update Settings (Self-Hosted)
If you were using the Settings page to configure your API key:
1. Go to Settings → Self-Hosting
2. Remove the old Synth API key
3. Enter your new Alpha Vantage API key

## Limitations

### Alpha Vantage vs Synth Differences
- **Exchange MIC Data**: Alpha Vantage doesn't provide exchange operating MIC codes like Synth did
- **Rate Limits**: Free tier is limited to 25 requests/day (vs Synth's higher limits)
- **Data Coverage**: Primarily focuses on US markets (vs Synth's global coverage)
- **Logo URLs**: Alpha Vantage doesn't provide company logos

### Deprecated Features
- **Securities Rake Task**: `rake securities:backfill_exchange_mic` is disabled since Alpha Vantage doesn't provide exchange MIC data

## Functionality Preserved
- ✅ Exchange rate fetching (forex data)
- ✅ Stock price fetching (historical and current)
- ✅ Security search functionality
- ✅ Settings page integration
- ✅ All existing interfaces and APIs

## Free Alternative Benefits
- ✅ **Cost**: Completely free tier (vs Synth's paid plans)
- ✅ **Reliability**: Well-established provider since 2017
- ✅ **Documentation**: Comprehensive API documentation
- ✅ **No shutdown risk**: Alpha Vantage is an established, profitable company

## Troubleshooting

### Rate Limit Errors
If you hit the 25 requests/day limit:
- Wait until the next day for limit reset
- Consider upgrading to Alpha Vantage's paid plans for higher limits
- Use data sparingly during testing

### Missing Exchange Data
Alpha Vantage doesn't provide exchange operating MIC codes, so:
- Existing securities with MIC codes will continue to work
- New securities won't have MIC data populated
- This doesn't affect price fetching or basic functionality

### No Logo URLs
Company logos won't be available for new securities since Alpha Vantage doesn't provide them.