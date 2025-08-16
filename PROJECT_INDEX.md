# Maybe Finance - Project Index & Documentation

## 📋 Project Overview

**Maybe Finance** is a self-hosted personal finance application built with Ruby on Rails. This repository contains the complete application stack, including Docker configurations and custom Python scripts for automated transaction categorization.

⚠️ **Important**: This repository is no longer actively maintained by Maybe Finance Inc. (see [final release](https://github.com/maybe-finance/maybe/releases/tag/v0.6.0))

## 🏗️ Architecture

### Core Technology Stack
- **Backend**: Ruby on Rails (see `.ruby-version` for version)
- **Database**: PostgreSQL 16
- **Background Jobs**: Sidekiq with Redis
- **Frontend**: Turbo + Stimulus (Hotwire)
- **Styling**: Tailwind CSS v4
- **Containerization**: Docker & Docker Compose

### System Components

#### 1. Rails Application (`app/`)
- **MVC Structure**: Standard Rails application structure
- **Controllers**: 40+ controllers handling accounts, transactions, investments, etc.
- **Models**: Complex financial data models with polymorphic associations
- **Views**: ERB templates with Turbo integration
- **Components**: ViewComponent-based design system (`app/components/`)

#### 2. Docker Services (`compose.yml`)
```yaml
web:     # Rails application server (port 3000)
worker:  # Sidekiq background job processor
db:      # PostgreSQL 16 database (port 5432)
redis:   # Redis for jobs and caching
```

#### 3. Custom Transaction Categorization (`scripts/transaction-processing/`)
- **Primary Script**: `transaction-categorizer-simple.py` - Main categorization engine
- **Category Management**: `add-categories.py`, `add-final-categories.py`
- **Cleanup Tools**: `cleanup-categories.py`

## 📊 Database Schema

### Key Tables
- **`families`**: User family/household units
- **`users`**: Individual user accounts
- **`accounts`**: Financial accounts (bank, investment, etc.)
- **`entries`**: Polymorphic transaction entries
- **`transactions`**: Specific transaction records
- **`categories`**: Transaction categorization
- **`balances`**: Account balance history
- **`holdings`**: Investment holdings
- **`securities`**: Investment securities data

### Data Flow
```
Entries (polymorphic) → Transactions → Categories
                    ↘ Valuations
                    ↘ Trades
                    ↘ Transfers
```

## 🐍 Python Transaction Categorization System

### Overview
Custom AI-powered transaction categorization system that connects to PostgreSQL via Docker exec.

### Core Components

#### `transaction-categorizer-simple.py`
- **Purpose**: Automatically categorize uncategorized transactions
- **Connection**: Docker exec to PostgreSQL container
- **Features**: Pattern matching, batch processing, dry-run mode

#### Key Categories
- **Income**: Salary, payroll (Copart, Continental Exc)
- **Transfers**: Zelle, Western Union, Goldman Sachs savings
- **Loans**: Credit card autopay, mortgage payments
- **Investments**: Robinhood, Coinbase, Fidelity
- **Food & Groceries**: Restaurants, supermarkets, groceries
- **Utilities**: Phone, internet, electric bills
- **Transportation**: Gas, rideshares, car services

#### Usage Examples
```bash
# Dry run (default)
python3 transaction-categorizer-simple.py --batch-size 50

# Apply changes
python3 transaction-categorizer-simple.py --apply --batch-size 100

# Process all uncategorized
python3 transaction-categorizer-simple.py --all --apply
```

## 🚀 Deployment & Operations

### Development Setup
```bash
# Clone and setup
git clone [repo]
cd maybe
cp .env.local.example .env.local
bin/setup
bin/dev

# Visit http://localhost:3000
# Login: user@maybe.local / password
```

### Docker Self-Hosting
```bash
# Download compose file
curl -o compose.yml https://raw.githubusercontent.com/maybe-finance/maybe/main/compose.example.yml

# Start services
docker compose up -d

# Visit http://localhost:3000
```

### Environment Configuration
Required environment variables:
- `SECRET_KEY_BASE`: Rails application secret
- `POSTGRES_PASSWORD`: Database password
- `OPENAI_ACCESS_TOKEN`: Optional for AI features

## 📁 Directory Structure

```
maybe/
├── app/                    # Rails application
│   ├── controllers/        # Request handlers
│   ├── models/            # Data models
│   ├── views/             # Templates
│   ├── components/        # ViewComponents
│   ├── javascript/        # Stimulus controllers
│   └── assets/            # Static assets
├── config/                # Application configuration
├── db/                    # Database migrations & schema
├── scripts/               # Custom Python tools
│   └── transaction-processing/
├── docs/                  # Documentation
├── test/                  # Test suite
├── compose.yml           # Docker Compose config
├── Dockerfile.dev        # Development Docker image
└── CLAUDE.md            # AI assistant instructions
```

## 🔧 Key Features

### Financial Management
- **Multi-Account Support**: Bank accounts, investments, loans, properties
- **Transaction Tracking**: Automated categorization and analysis
- **Investment Portfolio**: Holdings, trades, performance tracking
- **Budget Management**: Category-based budgeting
- **Net Worth Tracking**: Historical balance tracking

### Data Import/Export
- **CSV Import**: Bank transaction imports
- **Plaid Integration**: Automated bank connections
- **Data Export**: Family data export functionality
- **Migration Tools**: Import from Mint and other platforms

### Security & Privacy
- **Self-Hosted**: Complete data control
- **Encryption**: Rails encrypted attributes
- **Authentication**: Multi-factor authentication support
- **API Access**: OAuth2 with Doorkeeper

## 🛠️ Development Tools

### Testing
- **Framework**: Rails test suite
- **Coverage**: Model, controller, system tests
- **Fixtures**: Comprehensive test data

### Code Quality
- **Linting**: Standard Rails conventions
- **Security**: Brakeman security scanning
- **Performance**: Mini Profiler integration

### Background Jobs
- **Queue**: Sidekiq with Redis
- **Jobs**: Import processing, data synchronization, market data updates

## 📚 Documentation

### Existing Docs
- `README.md`: Basic setup and overview
- `CLAUDE.md`: AI assistant guidelines and security rules
- `docs/hosting/docker.md`: Detailed Docker hosting guide
- `docs/api/`: API documentation

### Wiki Resources
- Mac Dev Setup Guide
- Linux Dev Setup Guide  
- Windows Dev Setup Guide
- Contributing Guidelines

## 🔒 Security Considerations

### Data Protection
- **Financial Data**: Strict rules against exposing transaction amounts
- **Personal Information**: Protection of account details and PII
- **Database Security**: Environment-based credentials only
- **Access Control**: Principle of least privilege

### Development Safety
- **Backup Requirements**: Always backup before modifications
- **Dry Run Mode**: Test database operations before applying
- **Audit Trail**: Document all significant changes

## 🔗 External Integrations

### Financial Services
- **Plaid**: Bank account connectivity
- **Market Data**: Security price feeds
- **Exchange Rates**: Currency conversion

### Third-Party Services
- **Stripe**: Payment processing (for hosted version)
- **Intercom**: Customer support integration
- **Sentry**: Error monitoring

## 📈 Monitoring & Observability

### Application Monitoring
- **Logs**: Rails logging with configurable levels
- **Performance**: Mini Profiler for request analysis
- **Health Checks**: Database and Redis connectivity

### Database Monitoring
- **Connection Health**: PostgreSQL connection monitoring
- **Query Performance**: Slow query identification
- **Data Integrity**: Foreign key constraints and validations

## 🚨 Common Issues & Troubleshooting

### Database Connection Issues
- **ActiveRecord::DatabaseConnectionError**: Reset database volume
- **Permission Errors**: Check PostgreSQL user configuration
- **Migration Failures**: Verify database state before migrations

### Docker Issues
- **Container Startup**: Check service dependencies
- **Volume Mounting**: Verify persistent storage configuration
- **Network Connectivity**: Ensure proper Docker network setup

### Transaction Categorization
- **Category Mapping**: Verify category existence before assignment
- **Pattern Matching**: Update categorization patterns for new merchants
- **Batch Processing**: Monitor processing performance and errors

---

**License**: AGPLv3  
**Trademark**: "Maybe" is a trademark of Maybe Finance Inc.  
**Status**: Community-maintained fork (original repository archived)