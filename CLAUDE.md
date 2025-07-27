# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Security Rules

**CRITICAL: Financial Data Protection**
- NEVER read, access, display, or modify transaction amounts or financial values unless explicitly given permission by the user
- When working with transaction data, focus only on transaction descriptions, dates, and categories
- Do not query or display amount fields from the database without explicit user consent
- When showing transaction examples, use placeholder amounts like "$XXX.XX" instead of real values

**Database Security**
- NEVER modify database credentials or connection strings in .env or compose.yml without explicit permission
- Do not expose database passwords or connection details in logs or output
- Always use environment variables for sensitive configuration
- Never hardcode passwords, API keys, or secrets in any scripts

**Personal Information Protection**
- NEVER display, log, or modify personal information from Zelle payments, bank details, or account names without permission
- Treat all transaction descriptions as potentially containing sensitive information
- Do not extract or analyze personal identifiers (names, phone numbers, account numbers) from transaction data
- When referencing transactions, use sanitized examples or ask for permission first

**Code Modification Safety**
- ALWAYS create backups before modifying existing working scripts
- Test all database operations in dry-run mode before applying changes
- Never modify core Docker Compose services without explicit approval
- Validate all SQL queries for potential data corruption before execution

**Access Control**
- Only connect to databases using the established docker exec method
- Never attempt to bypass existing connection patterns or security measures
- Do not create new database users or modify permissions without explicit permission
- Respect the principle of least privilege - only access data necessary for the specific task

**Audit Trail**
- Document all significant changes made to scripts or database schema
- Preserve original functionality when making improvements
- Never delete data or categories without explicit confirmation from the user
- Maintain clear separation between read-only operations and data modifications

## Project Overview

This is a self-hosted Maybe Finance instance running via Docker Compose with custom Python scripts for automated transaction categorization. The setup includes the core Maybe Finance application (Rails), PostgreSQL database, Redis, and custom Python tooling for AI-powered transaction categorization.

## Architecture

**Core Services (Docker Compose):**
- `web`: Maybe Finance Rails application (ghcr.io/maybe-finance/maybe:latest)
- `worker`: Background job processing (Sidekiq)
- `db`: PostgreSQL 16 database with exposed port 5432
- `redis`: Redis for background jobs and caching

**Custom Transaction Categorization System:**
- `transaction-categorizer-simple.py`: Main categorization script that connects to PostgreSQL via docker exec
- `add-categories.py`, `add-final-categories.py`: Scripts to manage category setup
- `cleanup-categories.py`: Script to remove unused/vague categories

## Database Schema Notes

The Maybe Finance database uses a complex transaction structure:
- `entries` table: Contains all financial entries with `entryable_type` and `entryable_id` polymorphism
- `transactions` table: Links to entries where `entryable_type = 'Transaction'`
- `categories` table: Requires `family_id`, `classification`, and `lucide_icon` fields
- All categories must belong to an existing family (UUID reference)

## Essential Commands

**Docker Management:**
```bash
# Start the stack
docker compose up -d

# Restart with new configuration
docker compose down && docker compose up -d

# Check service status
docker ps

# View logs
docker logs maybe-web-1
```

**Database Access:**
```bash
# Connect to database inside container
docker exec maybe-db-1 psql -U maybe_user -d maybe_production

# Check transaction count
docker exec maybe-db-1 psql -U maybe_user -d maybe_production -c "SELECT COUNT(*) FROM entries WHERE entryable_type = 'Transaction';"
```

**Transaction Categorization:**
```bash
# Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install psycopg2-binary

# Load environment and run categorizer
export $(cat .env | xargs)

# Dry run (default 10 transactions)
python3 transaction-categorizer-simple.py

# Process more transactions
python3 transaction-categorizer-simple.py --batch-size 100

# Actually apply changes
python3 transaction-categorizer-simple.py --apply --batch-size 50
```

**Category Management:**
```bash
# Add new categories
python3 add-categories.py

# Remove vague categories
python3 cleanup-categories.py
```

## Environment Configuration

Required environment variables in `.env`:
- `SECRET_KEY_BASE`: Rails secret key
- `POSTGRES_PASSWORD`: Database password (default: "simplepass123")
- `OPENAI_ACCESS_TOKEN`: Optional for AI features

Database defaults (can be overridden):
- `POSTGRES_USER`: maybe_user
- `POSTGRES_DB`: maybe_production
- `DB_HOST`: db (internal Docker network)

## Transaction Categorization Logic

The categorization system uses pattern matching against transaction descriptions with these category mappings:
- **Savings Transfer**: Goldman Sachs transfers, savings movements
- **Account Transfer**: Zelle, Western Union, person-to-person transfers
- **Loan Payments**: Credit card autopay, car loans, mortgage payments
- **Investments**: Robinhood, Coinbase, Fidelity transactions
- **Subscriptions**: Recurring services (Netflix, gym memberships)
- **Rent & Utilities**: Phone, internet, utility bills
- **Income**: Salary deposits (Copart, payroll)
- **Taxes**: IRS payments
- **Transportation**: Car services, gas, rideshares

## Common Issues

**Database Connection:**
- The PostgreSQL port 5432 must be exposed in compose.yml
- Scripts connect via docker exec, not direct host connection
- Ensure container name is 'maybe-db-1'

**Category Management:**
- All categories require a valid family_id UUID
- Categories referenced by budget_categories must be removed from budgets before deletion
- New categories need: id, name, color, family_id, classification, lucide_icon

**Transaction Data:**
- Maybe Finance uses polymorphic associations: entries -> transactions via entryable_type/entryable_id
- Uncategorized transactions have NULL category_id in the transactions table
- Updates must target the transactions table, not entries table

## Memorized Wisdom
- to memorize