# ===================================
# Azure Storage Integration Outputs
# ===================================

output "azure_consent_url" {
  description = "URL to grant Azure consent for Snowflake storage integration (one-time setup required)"
  value       = snowflake_storage_integration.azure_integration.azure_consent_url
  sensitive   = false
}

output "azure_multi_tenant_app_name" {
  description = "Azure multi-tenant app name for Snowflake storage integration"
  value       = snowflake_storage_integration.azure_integration.azure_multi_tenant_app_name
  sensitive   = false
}

output "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  value       = snowflake_storage_integration.azure_integration.name
}

# ===================================
# External Stage Outputs
# ===================================

output "external_stage_name" {
  description = "Name of the external stage pointing to Azure Blob Storage"
  value       = snowflake_stage.bronze_stage.name
}

output "external_stage_url" {
  description = "Azure Blob Storage URL for the external stage"
  value       = snowflake_stage.bronze_stage.url
}

# ===================================
# Snowpipe Outputs
# ===================================

output "snowpipe_trades_name" {
  description = "Snowpipe name for trades table"
  value       = snowflake_pipe.trades_pipe.name
}

output "snowpipe_positions_name" {
  description = "Snowpipe name for positions table"
  value       = snowflake_pipe.positions_pipe.name
}

output "snowpipe_cash_movements_name" {
  description = "Snowpipe name for cash_movements table"
  value       = snowflake_pipe.cash_movements_pipe.name
}

output "snowpipe_notification_channels" {
  description = "Snowpipe notification channel ARNs for Azure Event Grid configuration"
  value = {
    trades         = "Run: SELECT SYSTEM$GET_SNOWPIPE_INFO('${snowflake_pipe.trades_pipe.name}') to get notification channel"
    positions      = "Run: SELECT SYSTEM$GET_SNOWPIPE_INFO('${snowflake_pipe.positions_pipe.name}') to get notification channel"
    cash_movements = "Run: SELECT SYSTEM$GET_SNOWPIPE_INFO('${snowflake_pipe.cash_movements_pipe.name}') to get notification channel"
  }
  sensitive = false
}

# ===================================
# Database & Warehouse Outputs
# ===================================

output "database_name" {
  description = "Snowflake database name"
  value       = snowflake_database.ingestion_platform.name
}

output "warehouse_name" {
  description = "Snowflake warehouse name"
  value       = snowflake_warehouse.ingestion_wh.name
}

output "bronze_schema_name" {
  description = "Bronze schema name"
  value       = snowflake_schema.bronze.name
}

# ===================================
# Setup Instructions Output
# ===================================

output "next_steps" {
  description = "Next steps after Terraform apply"
  value = <<-EOT
    ========================================
    TERRAFORM APPLY COMPLETE
    ========================================

    NEXT STEPS:

    1. GRANT AZURE CONSENT (One-time setup):
       Visit: ${snowflake_storage_integration.azure_integration.azure_consent_url}

    2. CONFIGURE AZURE EVENT GRID:
       Run the Azure CLI script:
       ./infra/scripts/setup-azure-eventgrid.sh

    3. TEST SNOWPIPE:
       Upload a test Parquet file to Azure Blob Storage:
       az storage blob upload --account-name ${var.azure_storage_account_name} \
         --container-name ${var.azure_storage_container_name} \
         --name bronze/sqlserver/trades/test.parquet \
         --file ./test.parquet

    4. VERIFY INGESTION:
       SELECT * FROM ${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.TRADES LIMIT 10;

    ========================================
  EOT
}
