#!/bin/bash

# Production startup script for Maybe Finance
# Load production environment variables
if [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
    echo "✅ Loaded production environment from .env.production"
else
    echo "❌ Warning: .env.production file not found!"
    exit 1
fi

echo "Starting Maybe Finance in Production Mode..."
echo "Database: $POSTGRES_DB"
echo "Environment: $RAILS_ENV"
echo "URL: http://localhost:3000"

# Start Sidekiq worker in background
bundle exec sidekiq &
SIDEKIQ_PID=$!

# Start Rails server
bundle exec puma -C config/puma.rb

# Cleanup on exit
trap "kill $SIDEKIQ_PID" EXIT