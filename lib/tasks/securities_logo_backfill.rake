namespace :securities do
  desc "Backfill logo URLs for existing securities using Logo.dev provider"
  task backfill_logos: :environment do
    # Check if Logo.dev provider is available
    logo_provider = Provider::Registry.get_provider(:logo_dev)
    unless logo_provider
      puts "❌ Logo.dev provider not available. Please configure your Logo.dev API key."
      exit 1
    end

    puts "🚀 Starting logo backfill for existing securities..."
    puts "📊 Using Logo.dev provider: #{logo_provider.class.name}"

    # Find securities without logo URLs
    securities_without_logos = Security.where(logo_url: [nil, ""])
    total_count = securities_without_logos.count

    if total_count == 0
      puts "✅ All securities already have logos!"
      exit 0
    end

    puts "📈 Found #{total_count} securities without logos"

    # Batch processing to avoid rate limits
    batch_size = ENV.fetch("BATCH_SIZE", 10).to_i
    delay_between_batches = ENV.fetch("DELAY_SECONDS", 2).to_i
    
    puts "⚙️ Processing in batches of #{batch_size} with #{delay_between_batches}s delay"

    successful_count = 0
    failed_count = 0
    skipped_count = 0

    securities_without_logos.find_in_batches(batch_size: batch_size) do |batch|
      puts "\n🔄 Processing batch of #{batch.size} securities..."

      batch.each do |security|
        begin
          # Try to fetch logo using ticker first, then name
          logo_response = if security.ticker.present?
            logo_provider.fetch_logo_url(symbol: security.ticker)
          elsif security.name.present?
            logo_provider.fetch_logo_url(company_name: security.name)
          else
            puts "⏭️ Skipping #{security.id}: No ticker or name available"
            skipped_count += 1
            next
          end

          if logo_response&.success? && logo_response.data.present?
            security.update!(logo_url: logo_response.data)
            puts "✅ #{security.ticker || security.name}: #{logo_response.data}"
            successful_count += 1
          else
            puts "⚠️ #{security.ticker || security.name}: No logo found"
            failed_count += 1
          end

        rescue => e
          puts "❌ #{security.ticker || security.name}: Error - #{e.message}"
          failed_count += 1
        end
      end

      # Delay between batches to respect rate limits
      if delay_between_batches > 0
        puts "⏳ Waiting #{delay_between_batches} seconds before next batch..."
        sleep(delay_between_batches)
      end
    end

    puts "\n📊 Backfill Summary:"
    puts "✅ Successful: #{successful_count}"
    puts "❌ Failed: #{failed_count}"
    puts "⏭️ Skipped: #{skipped_count}"
    puts "📈 Total processed: #{successful_count + failed_count + skipped_count}"

    if successful_count > 0
      puts "\n🎉 Logo backfill completed successfully!"
    else
      puts "\n⚠️ No logos were successfully added. Check your Logo.dev configuration."
    end
  end

  desc "Preview securities that would be updated by logo backfill"
  task preview_logo_backfill: :environment do
    securities_without_logos = Security.where(logo_url: [nil, ""])
    total_count = securities_without_logos.count

    puts "📊 Logo Backfill Preview"
    puts "========================"
    puts "Total securities without logos: #{total_count}"

    if total_count > 0
      puts "\nFirst 20 securities that would be updated:"
      puts "Symbol".ljust(10) + "Name".ljust(40) + "Exchange"
      puts "-" * 60

      securities_without_logos.limit(20).each do |security|
        symbol = (security.ticker || "N/A").ljust(10)
        name = (security.name || "N/A")[0..35].ljust(40)
        exchange = security.exchange_operating_mic || "N/A"
        puts "#{symbol}#{name}#{exchange}"
      end

      if total_count > 20
        puts "\n... and #{total_count - 20} more securities"
      end

      puts "\nTo run the backfill:"
      puts "bundle exec rails securities:backfill_logos"
      puts "\nOptional environment variables:"
      puts "BATCH_SIZE=10        # Securities per batch (default: 10)"
      puts "DELAY_SECONDS=2      # Delay between batches (default: 2)"
    else
      puts "\n✅ All securities already have logos!"
    end
  end

  desc "Update logo URL for a specific security by symbol"
  task :update_logo, [:symbol] => :environment do |task, args|
    unless args[:symbol]
      puts "❌ Please provide a security symbol:"
      puts "bundle exec rails securities:update_logo[AAPL]"
      exit 1
    end

    symbol = args[:symbol].upcase
    security = Security.find_by(ticker: symbol)

    unless security
      puts "❌ Security with symbol '#{symbol}' not found"
      exit 1
    end

    logo_provider = Provider::Registry.get_provider(:logo_dev)
    unless logo_provider
      puts "❌ Logo.dev provider not available. Please configure your Logo.dev API key."
      exit 1
    end

    puts "🔄 Fetching logo for #{symbol}..."

    begin
      logo_response = logo_provider.fetch_logo_url(symbol: symbol)

      if logo_response&.success? && logo_response.data.present?
        old_logo = security.logo_url
        security.update!(logo_url: logo_response.data)
        
        puts "✅ Logo updated successfully!"
        puts "   Symbol: #{symbol}"
        puts "   Name: #{security.name}"
        puts "   Old logo: #{old_logo || 'None'}"
        puts "   New logo: #{logo_response.data}"
      else
        puts "⚠️ No logo found for #{symbol}"
      end

    rescue => e
      puts "❌ Error fetching logo: #{e.message}"
      exit 1
    end
  end
end