# Maybe Finance - Database Schema Documentation

## 📊 Database Overview

**Database**: PostgreSQL 16  
**Schema Version**: 2025_07_24_115507  
**Total Tables**: 59  
**Extensions**: pgcrypto, plpgsql  

## 🔑 Key Design Patterns

### UUID Primary Keys
All tables use UUID primary keys with `gen_random_uuid()` default values for enhanced privacy and distributed system compatibility.

### Polymorphic Associations
The schema extensively uses polymorphic associations, particularly in the `entries` table which serves as a central transaction ledger.

### Soft Deletes & Status Fields
Many tables include status fields and soft delete patterns for data retention and audit trails.

## 📋 Core Tables

### User & Family Management

#### `families`
- **Purpose**: Household/family units (multi-user support)
- **Key Fields**: 
  - `id` (UUID, primary key)
  - `name` (family name)
  - `currency` (base currency)
  - `timezone` (family timezone)
  - `auto_sync_enabled` (boolean)
- **Relationships**: Has many users, accounts, categories

#### `users`
- **Purpose**: Individual user accounts
- **Key Fields**:
  - `id` (UUID, primary key)
  - `email` (unique identifier)
  - `encrypted_password` (authentication)
  - `role` (user role enum)
  - `locale` (user language preference)
  - `theme` (UI theme preference)
- **Relationships**: Belongs to family

### Account Management

#### `accounts`
- **Purpose**: Financial accounts (bank, investment, loan, etc.)
- **Key Fields**:
  - `id` (UUID, primary key)
  - `family_id` (foreign key)
  - `accountable_type` & `accountable_id` (polymorphic)
  - `name` (account name)
  - `balance` (current balance, precision 19, scale 4)
  - `currency` (account currency)
  - `classification` (virtual: asset/liability)
  - `status` (active/inactive)
- **Polymorphic Types**: Depository, Investment, Loan, CreditCard, Crypto, Property, Vehicle, OtherAsset, OtherLiability

#### Account Subtypes
- **`depositories`**: Bank accounts, checking, savings
- **`investments`**: Investment accounts, brokerage
- **`credit_cards`**: Credit card accounts
- **`loans`**: Loan accounts, mortgages
- **`cryptos`**: Cryptocurrency wallets
- **`properties`**: Real estate properties
- **`vehicles`**: Vehicle assets
- **`other_assets`**: Miscellaneous assets
- **`other_liabilities`**: Miscellaneous liabilities

### Transaction System

#### `entries`
- **Purpose**: Central transaction ledger (polymorphic)
- **Key Fields**:
  - `id` (UUID, primary key)
  - `account_id` (foreign key)
  - `name` (transaction description)
  - `date` (transaction date)
  - `amount` (transaction amount)
  - `currency` (transaction currency)
  - `entryable_type` & `entryable_id` (polymorphic)
  - `excluded` (boolean, exclude from analysis)
- **Polymorphic Types**: Transaction, Valuation, Trade, Transfer

#### `transactions`
- **Purpose**: Standard financial transactions
- **Key Fields**:
  - `id` (UUID, primary key)
  - `category_id` (foreign key to categories)
  - `merchant_id` (foreign key to merchants)
  - `kind` (transaction type)
  - `notes` (user notes)
- **Relationships**: Belongs to category, merchant

#### `categories`
- **Purpose**: Transaction categorization
- **Key Fields**:
  - `id` (UUID, primary key)
  - `family_id` (foreign key)
  - `name` (category name)
  - `color` (UI color code)
  - `parent_id` (hierarchical categories)
  - `classification` (income/expense/transfer)
  - `lucide_icon` (icon identifier)

#### `merchants`
- **Purpose**: Transaction merchant/vendor data
- **Key Fields**:
  - `id` (UUID, primary key)
  - `name` (merchant name)  
  - `enriched_name` (processed name)
  - `logo_url` (merchant logo)

### Investment Management

#### `securities`
- **Purpose**: Investment securities (stocks, bonds, etc.)
- **Key Fields**:
  - `id` (UUID, primary key)
  - `symbol` (ticker symbol)
  - `name` (security name)
  - `country_code` (country)
  - `logo_url` (security logo)
  - `exchange_operating_mic` (exchange identifier)

#### `holdings`
- **Purpose**: Investment portfolio holdings
- **Key Fields**:
  - `id` (UUID, primary key)
  - `account_id` (foreign key)
  - `security_id` (foreign key)
  - `quantity` (shares/units held)
  - `cost_basis` (original cost)
  - `currency` (holding currency)

#### `trades`
- **Purpose**: Investment trade transactions
- **Key Fields**:
  - `id` (UUID, primary key)
  - `security_id` (foreign key)
  - `qty` (quantity traded)
  - `price` (trade price)
  - `type` (buy/sell)
  - `date` (trade date)

### Transfer System

#### `transfers`
- **Purpose**: Money transfers between accounts
- **Key Fields**:
  - `id` (UUID, primary key)
  - `inflow_entry_id` (receiving entry)
  - `outflow_entry_id` (sending entry)
  - `amount` (transfer amount)
  - `currency` (transfer currency)

#### `rejected_transfers`
- **Purpose**: Track rejected transfer matches
- **Key Fields**:
  - `id` (UUID, primary key)
  - `inflow_entry_id` (proposed inflow)
  - `outflow_entry_id` (proposed outflow)

### Balance Tracking

#### `balances`
- **Purpose**: Historical account balance snapshots
- **Key Fields**:
  - `id` (UUID, primary key)
  - `account_id` (foreign key)
  - `date` (balance date)
  - `balance` (account balance)
  - `currency` (balance currency)
  - `start_date` & `end_date` (period validity)

#### `valuations`
- **Purpose**: Manual account valuations
- **Key Fields**:
  - `id` (UUID, primary key)
  - `account_id` (foreign key)
  - `value` (valuation amount)
  - `date` (valuation date)
  - `kind` (valuation type)

### Data Import System

#### `imports`
- **Purpose**: Track data import jobs
- **Key Fields**:
  - `id` (UUID, primary key)
  - `family_id` (foreign key)
  - `type` (import type)
  - `raw_file_str` (uploaded file data)
  - `col_sep` (CSV separator)
  - `number_format` (number format)

#### Import Mapping Tables
- **`account_mappings`**: Map CSV accounts to system accounts
- **`category_mappings`**: Map CSV categories to system categories
- **`tag_mappings`**: Map CSV tags to system tags

### Budget Management

#### `budgets`
- **Purpose**: Family budgets
- **Key Fields**:
  - `id` (UUID, primary key)
  - `family_id` (foreign key)
  - `name` (budget name)
  - `period` (budget period)
  - `start_date` & `end_date` (budget period)

#### `budget_categories`
- **Purpose**: Budget category allocations
- **Key Fields**:
  - `id` (UUID, primary key)
  - `budget_id` (foreign key)
  - `category_id` (foreign key)
  - `assigned` (budgeted amount)

### Authentication & API

#### `sessions`
- **Purpose**: User session management
- **Key Fields**:
  - `id` (UUID, primary key)
  - `user_id` (foreign key)
  - `user_agent` (client info)
  - `ip_address` (session IP)

#### `api_keys`
- **Purpose**: API authentication
- **Key Fields**:
  - `id` (UUID, primary key)
  - `user_id` (foreign key)
  - `name` (key name)
  - `scopes` (JSON permissions)
  - `expires_at` (expiration)

#### OAuth Tables (Doorkeeper)
- **`oauth_applications`**: OAuth client applications
- **`oauth_access_grants`**: OAuth authorization grants
- **`oauth_access_tokens`**: OAuth access tokens

### Plaid Integration

#### `plaid_items`
- **Purpose**: Plaid connection items
- **Key Fields**:
  - `id` (UUID, primary key)
  - `family_id` (foreign key)
  - `access_token` (encrypted)
  - `status` (connection status)
  - `products` (enabled products)

#### `plaid_accounts`
- **Purpose**: Plaid account mappings
- **Key Fields**:
  - `id` (UUID, primary key)
  - `account_id` (foreign key)
  - `plaid_item_id` (foreign key)
  - `plaid_id` (Plaid account ID)

### System Tables

#### `syncs`
- **Purpose**: Track synchronization jobs
- **Key Fields**:
  - `id` (UUID, primary key)
  - `syncable_type` & `syncable_id` (polymorphic)
  - `status` (sync status)
  - `error` (error message)
  - `last_ran_at` (last execution)

#### `subscriptions`
- **Purpose**: Webhook subscriptions
- **Key Fields**:
  - `id` (UUID, primary key)
  - `family_id` (foreign key)
  - `webhook_url` (callback URL)
  - `events` (subscribed events)

## 🔍 Key Relationships

### Data Flow Hierarchy
```
Family
├── Users
├── Accounts
│   ├── Entries (polymorphic)
│   │   ├── Transactions → Categories
│   │   ├── Valuations
│   │   ├── Trades → Securities
│   │   └── Transfers
│   ├── Balances
│   └── Holdings → Securities
├── Categories
├── Budgets → Budget Categories
└── Imports
```

### Polymorphic Associations

#### `entries.entryable`
- **Transaction**: Standard financial transactions
- **Valuation**: Manual account valuations  
- **Trade**: Investment trades
- **Transfer**: Money transfers (internal reference)

#### `accounts.accountable`
- **Depository**: Bank accounts
- **Investment**: Investment accounts
- **CreditCard**: Credit card accounts
- **Loan**: Loan accounts
- **Crypto**: Cryptocurrency wallets
- **Property**: Real estate
- **Vehicle**: Vehicle assets
- **OtherAsset/OtherLiability**: Miscellaneous accounts

## 🔧 Technical Features

### Database Extensions
- **pgcrypto**: UUID generation and encryption
- **plpgsql**: Stored procedures and functions

### Data Types
- **UUID**: All primary and foreign keys
- **DECIMAL(19,4)**: Monetary amounts with precision
- **JSONB**: Flexible data storage (metadata, preferences)
- **ENUM**: Status fields and classifications

### Constraints & Indexes
- **Unique Constraints**: Email uniqueness, security symbols
- **Foreign Key Constraints**: Referential integrity
- **Partial Indexes**: Status-based and conditional indexing
- **Composite Indexes**: Multi-column query optimization

### Security Features
- **Encrypted Attributes**: Sensitive data encryption
- **Audit Fields**: created_at, updated_at on all tables
- **Soft Deletes**: Status fields for data retention
- **Access Control**: Family-based data isolation

---

**Note**: This schema represents a complex financial application with comprehensive tracking of accounts, transactions, investments, and budgets. The polymorphic design provides flexibility while maintaining data integrity through proper constraints and relationships.