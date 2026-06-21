# ===================================
# Azure Storage Integration
# ===================================

# Storage integration for Azure Blob Storage
# This creates a trust relationship between Snowflake and Azure
# After applying this, you must grant consent in Azure Portal using the azure_consent_url output
resource "snowflake_storage_integration" "azure_integration" {
  name    = "AZURE_INGESTION_INTEGRATION"
  comment = "Storage integration for Azure Blob Storage - managed by Terraform"

  type = "EXTERNAL_STAGE"

  enabled = true

  # Azure-specific configuration
  storage_provider         = "AZURE"
  azure_tenant_id          = var.azure_tenant_id
  storage_allowed_locations = [
    "azure://${var.azure_storage_account_name}.blob.core.windows.net/${var.azure_storage_container_name}/bronze/"
  ]

  # Optional: Restrict to specific paths (recommended for production)
  # storage_blocked_locations = []
}

# Grant usage on storage integration to INGESTION_ROLE
resource "snowflake_grant_privileges_to_account_role" "storage_integration_usage" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "INTEGRATION"
    object_name = snowflake_storage_integration.azure_integration.name
  }

  depends_on = [snowflake_storage_integration.azure_integration]
}

# ===================================
# File Format for Parquet
# ===================================

resource "snowflake_file_format" "parquet_format" {
  name     = "PARQUET_FORMAT"
  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  comment  = "Parquet file format with case-insensitive column matching - managed by Terraform"

  format_type = "PARQUET"

  # Case-insensitive column name matching (handles casing differences between source and target)
  # This is critical for CDC data where column names might vary in casing
  compression          = "AUTO"  # Parquet files are already compressed
  binary_as_text       = false
  trim_space           = false

  depends_on = [snowflake_schema.bronze]
}

# ===================================
# External Stage (Azure Blob Storage)
# ===================================

resource "snowflake_stage" "bronze_stage" {
  name     = "BRONZE_STAGE"
  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  comment  = "External stage for bronze layer ingestion from Azure Blob Storage - managed by Terraform"

  # Azure Blob Storage URL
  url = "azure://${var.azure_storage_account_name}.blob.core.windows.net/${var.azure_storage_container_name}/bronze/"

  # Use storage integration (not inline credentials)
  storage_integration = snowflake_storage_integration.azure_integration.name

  # File format for stage
  file_format = "FORMAT_NAME = ${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_file_format.parquet_format.name}"

  # Directory table (enables querying stage metadata without loading data)
  directory = "ENABLE = TRUE"

  depends_on = [
    snowflake_schema.bronze,
    snowflake_storage_integration.azure_integration,
    snowflake_file_format.parquet_format
  ]
}

# Grant read access on stage to INGESTION_ROLE
resource "snowflake_grant_privileges_to_account_role" "stage_usage" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["USAGE", "READ"]

  on_schema_object {
    object_type = "STAGE"
    object_name = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.bronze.name}\".\"${snowflake_stage.bronze_stage.name}\""
  }

  depends_on = [snowflake_stage.bronze_stage]
}
