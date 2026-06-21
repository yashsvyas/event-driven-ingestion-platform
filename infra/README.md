# Snowflake Infrastructure (Terraform)

Infrastructure-as-Code for the event-driven data ingestion platform using Terraform and Snowflake.

## Overview

This Terraform configuration provisions:

- **Snowflake Database** (`INGESTION_PLATFORM`) with bronze/silver/governance schemas
- **Warehouse** (`INGESTION_WH`) for compute with auto-suspend
- **Azure Storage Integration** for secure access to Azure Blob Storage
- **External Stage** pointing to Azure Blob container
- **Bronze Layer Tables** (trades, positions, cash_movements) with ingestion metadata
- **Snowpipe Auto-Ingest** for real-time data loading from Parquet files
- **RBAC** with `INGESTION_ROLE` for service accounts

## Architecture

```
┌─────────────────────────┐
│   Azure Blob Storage    │
│   (Parquet files)       │
│                         │
│   bronze/sqlserver/     │
│   ├── trades/           │
│   ├── positions/        │
│   └── cash_movements/   │
└───────────┬─────────────┘
            │
            │ Event Grid
            │ (Blob Created)
            ▼
┌─────────────────────────┐
│     Snowpipe            │
│   (Auto-Ingest)         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   Snowflake Bronze      │
│   Tables                │
│                         │
│   TRADES                │
│   POSITIONS             │
│   CASH_MOVEMENTS        │
└─────────────────────────┘
```

## Prerequisites

### 1. Snowflake Trial Account

1. Sign up for free trial: https://signup.snowflake.com/
2. Choose **Enterprise** edition (30 days, $400 credits)
3. Note your account identifier (e.g., `xy12345.us-east-1`)

### 2. Create Snowflake Service Account

**Important**: Don't use your personal trial account for Terraform. Create a dedicated service account:

```sql
USE ROLE ACCOUNTADMIN;

-- Create service account for Terraform
CREATE USER terraform_user
  PASSWORD = 'YOUR_STRONG_PASSWORD'
  DEFAULT_ROLE = ACCOUNTADMIN
  MUST_CHANGE_PASSWORD = FALSE;

-- Grant ACCOUNTADMIN role (required for storage integration)
GRANT ROLE ACCOUNTADMIN TO USER terraform_user;
```

### 3. Azure Storage Account

Create an Azure Storage Account (if you don't have one):

```bash
# Login to Azure
az login

# Create resource group
az group create --name ingestion-platform-rg --location eastus

# Create storage account
az storage account create \
  --name yourstorageaccount \
  --resource-group ingestion-platform-rg \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2

# Create container
az storage container create \
  --name ingestion-data \
  --account-name yourstorageaccount
```

### 4. Terraform Cloud Account (Free Tier)

1. Sign up: https://app.terraform.io/signup
2. Create organization (or use existing)
3. Create workspace: `event-driven-ingestion-platform`
4. Get API token: Settings → Tokens → Create API token

### 5. Install Dependencies

- **Docker** (for Terraform via container)
- **Make** (for convenience commands)
- **Azure CLI** (for Event Grid setup)

```bash
# Verify installations
docker --version
make --version
az --version
```

## Setup Guide

### Step 1: Configure Terraform Variables

```bash
cd infra

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Fill in these required values:

```hcl
snowflake_account              = "xy12345.us-east-1"
snowflake_user                 = "terraform_user"
snowflake_password             = "YOUR_PASSWORD"
snowflake_role                 = "ACCOUNTADMIN"

azure_tenant_id                = "YOUR_AZURE_TENANT_ID"
azure_storage_account_name     = "yourstorageaccount"
azure_storage_container_name   = "ingestion-data"
azure_resource_group           = "ingestion-platform-rg"
```

**Get Azure Tenant ID**:
```bash
az account show --query tenantId -o tsv
```

### Step 2: Configure Terraform Cloud Backend

Edit `infra/main.tf` and update the organization name:

```hcl
cloud {
  organization = "YOUR_ORG_NAME"  # ← Change this

  workspaces {
    name = "event-driven-ingestion-platform"
  }
}
```

### Step 3: Login to Terraform Cloud

```bash
# From project root
make tf-login

# Follow prompts to generate token
```

### Step 4: Set GitHub Secrets (for CI/CD)

Go to GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `TF_API_TOKEN` | Terraform Cloud API token | `xxx.atlasv1.yyy` |
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | `xy12345.us-east-1` |
| `SNOWFLAKE_USER` | Service account username | `terraform_user` |
| `SNOWFLAKE_PASSWORD` | Service account password | `StrongP@ssw0rd!` |
| `SNOWFLAKE_ROLE` | Snowflake role | `ACCOUNTADMIN` |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `12345678-1234-...` |
| `AZURE_STORAGE_ACCOUNT_NAME` | Storage account name | `yourstorageaccount` |
| `AZURE_STORAGE_CONTAINER_NAME` | Container name | `ingestion-data` |
| `AZURE_RESOURCE_GROUP` | Resource group name | `ingestion-platform-rg` |

### Step 5: Export Environment Variables (for local development)

```bash
# Add to ~/.bashrc or ~/.zshrc
export TF_VAR_snowflake_account="xy12345.us-east-1"
export TF_VAR_snowflake_user="terraform_user"
export TF_VAR_snowflake_password="YOUR_PASSWORD"
export TF_VAR_snowflake_role="ACCOUNTADMIN"
export TF_VAR_azure_tenant_id="YOUR_TENANT_ID"
export TF_VAR_azure_storage_account_name="yourstorageaccount"
export TF_VAR_azure_storage_container_name="ingestion-data"
export TF_VAR_azure_resource_group="ingestion-platform-rg"

# Reload shell
source ~/.bashrc
```

### Step 6: Deploy Infrastructure

```bash
# Initialize Terraform
make tf-init

# Validate configuration
make tf-validate

# Preview changes
make tf-plan

# Apply (creates all Snowflake resources)
make tf-apply
```

Expected output:
```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.

Outputs:

azure_consent_url = "https://login.microsoftonline.com/.../oauth2/authorize?..."
database_name = "INGESTION_PLATFORM"
warehouse_name = "INGESTION_WH"
...
```

### Step 7: Grant Azure Consent

**One-time manual step** (required for storage integration):

1. Copy the `azure_consent_url` from terraform output
2. Open in browser (while logged into Azure)
3. Click "Accept" to grant Snowflake access to your storage account

### Step 8: Configure Azure Event Grid

Run the automated script:

```bash
cd infra/scripts
./setup-azure-eventgrid.sh
```

Or follow manual steps: [AZURE_EVENTGRID_MANUAL_STEPS.md](./scripts/AZURE_EVENTGRID_MANUAL_STEPS.md)

### Step 9: Test Ingestion

Upload a test Parquet file:

```bash
az storage blob upload \
  --account-name yourstorageaccount \
  --container-name ingestion-data \
  --name bronze/sqlserver/trades/test_2024_01_01.parquet \
  --file /path/to/test.parquet
```

Verify in Snowflake:

```sql
USE INGESTION_PLATFORM.BRONZE;

-- Check if data loaded
SELECT * FROM TRADES LIMIT 10;

-- Check Snowpipe status
SELECT *
FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
  DATE_RANGE_START => DATEADD('day', -1, CURRENT_DATE())
));
```

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make tf-login` | Login to Terraform Cloud (one-time) |
| `make tf-init` | Initialize Terraform |
| `make tf-validate` | Validate configuration |
| `make tf-fmt` | Format Terraform files |
| `make tf-plan` | Show execution plan |
| `make tf-apply` | Apply changes (create/update infrastructure) |
| `make tf-destroy` | Destroy all infrastructure (WARNING: destructive!) |
| `make tf-shell` | Open interactive Terraform shell |

## File Structure

```
infra/
├── main.tf                  # Provider config, Terraform Cloud backend
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── terraform.tfvars.example # Template for variables
├── terraform.tfvars         # Your actual values (gitignored)
├── database.tf              # Database and schemas
├── warehouse.tf             # Compute warehouse
├── roles.tf                 # RBAC and grants
├── storage.tf               # Storage integration, stage, file format
├── tables.tf                # Bronze layer tables
├── pipes.tf                 # Snowpipe definitions
├── scripts/
│   ├── setup-azure-eventgrid.sh         # Azure automation
│   └── AZURE_EVENTGRID_MANUAL_STEPS.md  # Manual setup guide
└── README.md                # This file
```

## CI/CD (GitHub Actions)

The workflow `.github/workflows/snowflake-infra.yml` automatically:

- **On PR**: Runs `terraform plan` and comments the plan on the PR
- **On merge to main**: Runs `terraform apply` to deploy changes

Triggered only when files in `infra/` change.

## Troubleshooting

### Terraform init fails: "Invalid credentials"

**Solution**: Check that you've run `make tf-login` and exported environment variables.

### Storage integration permission denied

**Solution**: Ensure you've granted Azure consent (Step 7) by visiting the `azure_consent_url`.

### Snowpipe not ingesting files

1. Check pipe status:
   ```sql
   SHOW PIPES IN SCHEMA BRONZE;
   ```

2. Manually refresh pipe:
   ```sql
   ALTER PIPE TRADES_PIPE REFRESH;
   ```

3. Check for errors:
   ```sql
   SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
     TABLE_NAME => 'INGESTION_PLATFORM.BRONZE.TRADES',
     START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
   ));
   ```

### Provider version conflicts

The Snowflake provider is pinned to `~> 0.98.0`. If you encounter issues:

```bash
# Check provider version
cd infra
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:1.9 version
```

## Cost Management

### Snowflake Trial

- **30 days free** with $400 credits
- X-SMALL warehouse: ~$2/hour when running
- Auto-suspend after 60 seconds minimizes costs
- Monitor credits: https://app.snowflake.com/ → Account → Billing

### Azure Free Tier

- **5 GB free** Blob Storage per month
- Event Grid: First 100k operations/month free

## Security Best Practices

1. **Never commit** `terraform.tfvars` (contains secrets)
2. **Use service accounts** for Terraform (not personal accounts)
3. **Rotate passwords** regularly
4. **Limit ACCOUNTADMIN** usage (only for storage integration provisioning)
5. **Review grants** in `roles.tf` before applying

## Next Steps

After infrastructure is deployed:

1. **Week 3**: Modify C# CDC Reader to write Parquet files to Azure Blob
2. **Week 4-6**: Add dbt for bronze → silver transformations
3. **Week 7-9**: Implement event-driven orchestration
4. **Week 10-12**: Add governance, monitoring, and observability

## Reference Documentation

- [Terraform Snowflake Provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)
- [Snowflake Storage Integration (Azure)](https://docs.snowflake.com/en/user-guide/data-load-azure-config)
- [Snowpipe Auto-Ingest for Azure](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto-azure)
- [Terraform Cloud](https://developer.hashicorp.com/terraform/cloud-docs)

## Support

For issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Terraform plan output
3. Check Snowflake query history
4. Open GitHub issue with error details
