Onboarding complete. Key findings:

- **Project Purpose**: "Maybe" is a self-hostable personal finance application.
- **Tech Stack**: Ruby on Rails (v7.2.2), PostgreSQL, Redis, Tailwind CSS, Stimulus.js, Turbo.js, ViewComponent, Biome (JS/TS linting/formatting), Sidekiq, ruby-openai, Plaid, Stripe.
- **Code Style & Conventions**: Follows Rails conventions, uses Biome for JS/TS, Minitest for testing. Strong emphasis on security (financial data, credentials, PII) as per `CLAUDE.md`.
- **Testing**: Minitest framework, SimpleCov for coverage, VCR for HTTP mocking, parallel testing enabled.
- **Entry Points**: `bin/dev` starts the development server using Foreman; `bundle exec rake test` runs tests.
- **Project Structure**: Standard Rails structure with `app/` containing models, controllers, views, etc., `test/` for tests, `config/` for configuration, `lib/tasks/` for custom rake tasks.
- **Security Guidelines**: Detailed in `CLAUDE.md`, focusing on data protection and secure coding practices.
