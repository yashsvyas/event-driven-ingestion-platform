# Event-Driven Data Ingestion Platform

A 12-week personal project building an event-driven data ingestion platform in C# (.NET 8), modelling a simplified buy-side trading environment at a sovereign wealth fund.

**Status**: Week 2 Complete - Snowflake Infrastructure

## Project Overview

This platform ingests trading data (trades, positions, cash movements) from SQL Server via Change Data Capture (CDC), converts to Parquet format, stores in Azure Blob Storage, and auto-loads into Snowflake using Snowpipe.

### Current Architecture

```
┌─────────────────┐
│  SQL Server     │  ← Week 1: CDC enabled on 3 tables
│  (Azure SQL     │
│   Edge)         │
│                 │
│  ┌───────────┐  │
│  │   CDC     │  │
│  │  Change   │  │
│  │  Tables   │  │
│  └───────────┘  │
└────────┬────────┘
         │
         │ fn_cdc_get_net_changes
         │
         ▼
┌─────────────────┐
│  CdcReader      │  ← Week 1: .NET 8 console app
│  (.NET 8)       │     Reading CDC changes
│                 │
│  ┌───────────┐  │     Week 3 TODO: Write Parquet files
│  │ LSN Track │  │
│  │   File    │  │
│  └───────────┘  │
└─────────────────┘
         │
         ▼ (Week 3: TODO)
┌─────────────────┐
│  Azure Blob     │  ← Week 2: Infrastructure ready
│  Storage        │     Parquet files
│                 │
│  bronze/        │
│  ├── trades/    │
│  ├── positions/ │
│  └── cash_movs/ │
└────────┬────────┘
         │
         │ Event Grid (auto-trigger)
         │
         ▼
┌─────────────────┐
│   Snowpipe      │  ← Week 2: Terraform provisioned
│  (Auto-Ingest)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Snowflake      │  ← Week 2: Bronze tables ready
│  Bronze Layer   │     TRADES, POSITIONS, CASH_MOVEMENTS
│                 │
│  INGESTION_     │
│  PLATFORM DB    │
└─────────────────┘
```

---

## 🖥️ New Machine Setup Guide

Follow this checklist to set up the project on a fresh development machine.

### Prerequisites

#### 1. Operating System
- **macOS** (Apple Silicon M-series) - current setup
- **Windows** - requires SQL Server container adjustments
- **Linux** - fully compatible

#### 2. Required Software

Install these before cloning the repo:

```bash
# 1. Docker Desktop
# Download: https://www.docker.com/products/docker-desktop
# Verify:
docker --version
docker compose version

# 2. .NET 8 SDK
# Download: https://dotnet.microsoft.com/download/dotnet/8.0
# Verify:
dotnet --version  # Should be 8.0.x

# 3. Git
# macOS: brew install git
# Verify:
git --version

# 4. dotnet-script (for SQL utilities)
dotnet tool install -g dotnet-script
# Verify:
dotnet script --version

# 5. Azure CLI (for Week 2+)
# macOS: brew install azure-cli
# Download: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
# Verify:
az --version

# 6. Make (usually pre-installed on macOS/Linux)
make --version
```

#### 3. Optional (Recommended)

```bash
# VS Code with extensions
# - C# Dev Kit
# - MSSQL (for database queries)
# - Terraform
# - Docker

# SQL Client (choose one)
# - Azure Data Studio: https://aka.ms/azuredatastudio
# - DBeaver: https://dbeaver.io/
```

### Clone Repository

```bash
# Clone the repo
git clone https://github.com/yashsvyas/event-driven-ingestion-platform.git
cd event-driven-ingestion-platform

# Verify structure
ls -la
```

---

## 🚀 Quick Start (Local Development)

### Part 1: SQL Server + CDC Reader (Week 1)

#### 1. Start SQL Server

```bash
# Start Azure SQL Edge container
docker compose up -d

# Verify container is running
docker ps
# Should see: mcr.microsoft.com/azure-sql-edge

# Wait 10 seconds for SQL Server to initialize
sleep 10
```

#### 2. Initialize Database

```bash
# Create database and seed data
dotnet script init-db.csx

# Expected output:
# "Database TradingPlatform initialised successfully"
```

#### 3. Enable CDC

```bash
# Enable Change Data Capture on all tables
dotnet script enable-cdc.csx

# Expected output:
# "CDC enabled successfully on trades"
# "CDC enabled successfully on positions"
# "CDC enabled successfully on cash_movements"
```

#### 4. Run CDC Reader

```bash
# Build and run the .NET app
cd CdcReader
dotnet run

# Expected output:
# "Connected to TradingPlatform database"
# "Processing LSN range: From: ... To: ..."
# Shows INSERT/UPDATE operations on trades table

# Stop with Ctrl+C
cd ..
```

#### 5. Test CDC with Mutations

```bash
# Simulate daily trading activity (inserts/updates)
dotnet script simulate-changes.csx

# Run CDC reader again to see incremental changes
cd CdcReader
dotnet run

# Should show only new changes (not full table scan)
cd ..
```

#### 6. Verify CDC is Working

```bash
# Check LSN checkpoint file
cat CdcReader/last-processed-lsn.txt
# Should contain hex value like: 0000002700000D18000C

# Query CDC directly (optional)
dotnet script verify-cdc-functions.csx
```

### Part 2: Snowflake Infrastructure (Week 2)

#### Prerequisites for Deployment

Before running Terraform, you need:

1. **Snowflake Trial Account**
   - Sign up: https://signup.snowflake.com/
   - Choose **Enterprise** edition (30 days, $400 credits)
   - Note your account identifier (e.g., `xy12345.us-east-1`)

2. **Azure Storage Account**
   ```bash
   # Login to Azure
   az login

   # Create resource group
   az group create \
     --name ingestion-platform-rg \
     --location eastus

   # Create storage account
   az storage account create \
     --name <your-unique-name> \
     --resource-group ingestion-platform-rg \
     --location eastus \
     --sku Standard_LRS

   # Create container
   az storage container create \
     --name ingestion-data \
     --account-name <your-unique-name>

   # Get tenant ID
   az account show --query tenantId -o tsv
   ```

3. **Terraform Cloud Account**
   - Sign up: https://app.terraform.io/signup
   - Create organization
   - Create workspace: `event-driven-ingestion-platform`
   - Generate API token: Settings → Tokens

4. **Snowflake Service Account**
   ```sql
   -- Run in Snowflake UI
   USE ROLE ACCOUNTADMIN;

   CREATE USER terraform_user
     PASSWORD = 'YourStrongPassword123!'
     DEFAULT_ROLE = ACCOUNTADMIN
     MUST_CHANGE_PASSWORD = FALSE;

   GRANT ROLE ACCOUNTADMIN TO USER terraform_user;
   ```

#### 1. Configure Terraform Variables

```bash
cd infra

# Copy template
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
# Fill in:
# - snowflake_account
# - snowflake_user
# - snowflake_password
# - azure_tenant_id
# - azure_storage_account_name
# - azure_resource_group
```

#### 2. Update Terraform Cloud Organization

```bash
# Edit infra/main.tf line 15
vim main.tf

# Change:
organization = "YOUR_ORG_NAME"  # ← Your Terraform Cloud org name
```

#### 3. Export Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc
export TF_VAR_snowflake_account="xy12345.us-east-1"
export TF_VAR_snowflake_user="terraform_user"
export TF_VAR_snowflake_password="YourPassword"
export TF_VAR_snowflake_role="ACCOUNTADMIN"
export TF_VAR_azure_tenant_id="your-tenant-id"
export TF_VAR_azure_storage_account_name="yourstorageacct"
export TF_VAR_azure_storage_container_name="ingestion-data"
export TF_VAR_azure_resource_group="ingestion-platform-rg"

# Reload
source ~/.bashrc
```

#### 4. Login to Terraform Cloud

```bash
cd ..  # Back to project root
make tf-login

# Follow prompts to authenticate
```

#### 5. Deploy Infrastructure

```bash
# Initialize Terraform
make tf-init

# Validate configuration
make tf-validate

# Preview changes
make tf-plan

# Apply (creates all Snowflake resources)
make tf-apply
# Type 'yes' when prompted

# Expected output:
# "Apply complete! Resources: 20 added, 0 changed, 0 destroyed"
```

#### 6. Grant Azure Consent

```bash
# Copy the azure_consent_url from terraform output
# Open in browser (while logged into Azure)
# Click "Accept" to grant Snowflake access

# The URL looks like:
# https://login.microsoftonline.com/.../oauth2/authorize?...
```

#### 7. Configure Azure Event Grid

```bash
cd infra/scripts
./setup-azure-eventgrid.sh

# Follow prompts
# Or use manual steps in AZURE_EVENTGRID_MANUAL_STEPS.md
```

---

## 📁 Project Structure

```
event-driven-ingestion-platform/
├── README.md                       # This file - setup guide
├── docker-compose.yml              # SQL Server container
├── Makefile                        # Terraform commands (Docker-based)
│
├── sql/                            # Database setup
│   ├── init.sql                    # Schema + seed data
│   ├── enable-cdc.sql              # CDC configuration
│   ├── simulate_daily_changes.sql  # Test mutations
│   └── entrypoint.sh               # Container init script
│
├── CdcReader/                      # .NET 8 CDC extraction app
│   ├── Program.cs                  # Main CDC logic
│   ├── CdcReader.csproj            # Project file
│   ├── bin/                        # Build output (gitignored)
│   ├── obj/                        # Build cache (gitignored)
│   └── last-processed-lsn.txt      # LSN checkpoint (gitignored)
│
├── infra/                          # Snowflake infrastructure (Terraform)
│   ├── README.md                   # Detailed Terraform docs
│   ├── main.tf                     # Provider config + backend
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── database.tf                 # Database + schemas
│   ├── warehouse.tf                # Compute warehouse
│   ├── roles.tf                    # RBAC + grants
│   ├── storage.tf                  # Azure integration + stage
│   ├── tables.tf                   # Bronze layer tables
│   ├── pipes.tf                    # Snowpipe auto-ingest
│   ├── terraform.tfvars.example    # Template for credentials
│   ├── terraform.tfvars            # Your values (gitignored)
│   └── scripts/
│       ├── setup-azure-eventgrid.sh        # Event Grid automation
│       └── AZURE_EVENTGRID_MANUAL_STEPS.md # Manual setup guide
│
├── .github/workflows/
│   └── snowflake-infra.yml         # Terraform CI/CD pipeline
│
├── *.csx                           # dotnet-script utilities
│   ├── init-db.csx                 # Initialize database
│   ├── enable-cdc.csx              # Enable CDC
│   ├── simulate-changes.csx        # Generate test data
│   ├── verify-cdc-functions.csx    # Test CDC functions
│   └── test-cdc-call.csx           # Manual CDC query test
│
└── .gitignore                      # Git exclusions
```

---

## 🛠️ Common Commands

### SQL Server Operations

```bash
# Start SQL Server
docker compose up -d

# Stop SQL Server
docker compose down

# View logs
docker compose logs -f

# Connect to SQL Server (via Azure Data Studio)
# Server: localhost,1433
# User: sa
# Password: YourStrong@Passw0rd
# Database: TradingPlatform

# Restart from scratch (destroys data!)
docker compose down -v
docker compose up -d
dotnet script init-db.csx
dotnet script enable-cdc.csx
```

### CDC Reader Operations

```bash
# Run CDC reader
cd CdcReader
dotnet run

# Build release version
dotnet build -c Release

# Clean build artifacts
dotnet clean

# Reset LSN checkpoint (start from beginning)
rm last-processed-lsn.txt
dotnet run
```

### Terraform Operations

```bash
# All commands run from project root

# View help
make help

# Initialize Terraform
make tf-init

# Format Terraform files
make tf-fmt

# Validate configuration
make tf-validate

# Plan changes
make tf-plan

# Apply changes
make tf-apply

# Destroy infrastructure (WARNING: destructive!)
make tf-destroy

# Open Terraform shell (for debugging)
make tf-shell
```

### Snowflake Queries

```sql
-- Connect to Snowflake via UI or SnowSQL

-- View databases
SHOW DATABASES;

-- Use the platform database
USE INGESTION_PLATFORM.BRONZE;

-- Check tables
SHOW TABLES;

-- View data
SELECT * FROM TRADES LIMIT 10;
SELECT * FROM POSITIONS LIMIT 10;
SELECT * FROM CASH_MOVEMENTS LIMIT 10;

-- Check Snowpipe status
SELECT * FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
  DATE_RANGE_START => DATEADD('day', -7, CURRENT_DATE())
));

-- Check load history
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'INGESTION_PLATFORM.BRONZE.TRADES',
  START_TIME => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;

-- Manually refresh pipe (forces check for new files)
ALTER PIPE TRADES_PIPE REFRESH;
```

---

## 🐛 Troubleshooting

### SQL Server Issues

**Problem**: Container won't start
```bash
# Check logs
docker compose logs

# Common fix: Remove old volumes
docker compose down -v
docker compose up -d
```

**Problem**: "Login failed for user 'sa'"
```bash
# Verify password in docker-compose.yml matches connection string
# Default: YourStrong@Passw0rd
```

**Problem**: CDC not working
```bash
# Verify CDC is enabled
dotnet script verify-cdc-functions.csx

# Check if SQL Agent is running (required for CDC)
# Note: Azure SQL Edge has limitations - only first table works fully
```

### .NET Issues

**Problem**: `dotnet: command not found`
```bash
# Install .NET 8 SDK
# macOS: brew install --cask dotnet-sdk
# Download: https://dotnet.microsoft.com/download
```

**Problem**: `dotnet script: command not found`
```bash
dotnet tool install -g dotnet-script
# Then restart terminal
```

**Problem**: Build errors
```bash
cd CdcReader
dotnet clean
dotnet restore
dotnet build
```

### Terraform Issues

**Problem**: "Invalid credentials" on tf-init
```bash
# Ensure you've logged in
make tf-login

# Verify environment variables are set
echo $TF_VAR_snowflake_account
```

**Problem**: "Workspace not found"
```bash
# Create workspace in Terraform Cloud first
# https://app.terraform.io

# Update organization name in infra/main.tf
```

**Problem**: Provider version conflicts
```bash
# Delete lock file and re-init
rm infra/.terraform.lock.hcl
make tf-init
```

### Snowflake Issues

**Problem**: Storage integration permission denied
```bash
# Grant Azure consent (one-time)
# Visit the azure_consent_url from terraform output
```

**Problem**: Snowpipe not ingesting files
```sql
-- Check pipe status
SHOW PIPES IN SCHEMA BRONZE;

-- Manually refresh
ALTER PIPE TRADES_PIPE REFRESH;

-- Check for errors
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'INGESTION_PLATFORM.BRONZE.TRADES',
  START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
));
```

---

## 🔐 Security Notes

**Never commit these files:**
- `infra/terraform.tfvars` (contains passwords)
- `infra/.terraform/` (provider cache)
- `CdcReader/last-processed-lsn.txt` (runtime state)

**Gitignored automatically:**
✅ All sensitive files are already in `.gitignore`

**GitHub Secrets needed for CI/CD:**
- `TF_API_TOKEN`
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD`
- `SNOWFLAKE_ROLE`
- `AZURE_TENANT_ID`
- `AZURE_STORAGE_ACCOUNT_NAME`
- `AZURE_STORAGE_CONTAINER_NAME`
- `AZURE_RESOURCE_GROUP`

---

## 📖 Documentation

- **Terraform Setup**: [infra/README.md](infra/README.md)
- **Azure Event Grid**: [infra/scripts/AZURE_EVENTGRID_MANUAL_STEPS.md](infra/scripts/AZURE_EVENTGRID_MANUAL_STEPS.md)
- **Snowflake Docs**: https://docs.snowflake.com/
- **Terraform Provider**: https://registry.terraform.io/providers/Snowflake-Labs/snowflake/

---

## 📈 Project Roadmap

| Week | Milestone | Status |
|------|-----------|--------|
| 1 | SQL Server CDC Extraction | ✅ Complete |
| 2 | Snowflake Infrastructure (Terraform) | ✅ Complete |
| 3-4 | Parquet Output + Azure Blob Integration | 📋 Next |
| 5-6 | dbt (Bronze → Silver Transformations) | 📋 Planned |
| 7-9 | Event-Driven Orchestration | 📋 Planned |
| 10-12 | Governance + Monitoring | 📋 Planned |

---

## 🤝 Contributing

This is a personal learning project, but issues and suggestions are welcome!

1. Fork the repo
2. Create feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -m 'Add feature'`
4. Push: `git push origin feature/my-feature`
5. Open pull request

---

## 📄 License

MIT License - see LICENSE file for details

---

## ✅ Quick Verification Checklist

Use this to verify your setup is complete:

### Week 1 (SQL Server + CDC)
- [ ] Docker Desktop running
- [ ] SQL Server container started: `docker ps`
- [ ] Database initialized: `dotnet script init-db.csx`
- [ ] CDC enabled: `dotnet script enable-cdc.csx`
- [ ] CDC Reader runs successfully: `cd CdcReader && dotnet run`
- [ ] LSN checkpoint file created: `cat CdcReader/last-processed-lsn.txt`

### Week 2 (Snowflake Infrastructure)
- [ ] Snowflake trial account created
- [ ] Azure storage account created
- [ ] Terraform Cloud account created
- [ ] `infra/terraform.tfvars` configured
- [ ] Environment variables exported
- [ ] Terraform login: `make tf-login`
- [ ] Infrastructure deployed: `make tf-apply`
- [ ] Azure consent granted
- [ ] Event Grid configured: `./infra/scripts/setup-azure-eventgrid.sh`
- [ ] Can query Snowflake tables: `SELECT * FROM INGESTION_PLATFORM.BRONZE.TRADES;`

---

**Ready to deploy?** Follow the [Quick Start](#-quick-start-local-development) guide above!

For questions or issues, open a GitHub issue.
