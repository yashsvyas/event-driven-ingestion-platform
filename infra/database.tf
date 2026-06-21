# ===================================
# Snowflake Database
# ===================================

resource "snowflake_database" "ingestion_platform" {
  name    = "INGESTION_PLATFORM"
  comment = "Event-driven data ingestion platform - managed by Terraform"

  # Data retention for Time Travel (1 day for free/standard, up to 90 for enterprise)
  data_retention_time_in_days = 1
}

# ===================================
# Schemas
# ===================================

# Bronze layer: raw ingested data from source systems
resource "snowflake_schema" "bronze" {
  database = snowflake_database.ingestion_platform.name
  name     = "BRONZE"
  comment  = "Bronze layer - raw data from CDC extraction with minimal transformation"

  is_transient = false
  is_managed   = false

  data_retention_time_in_days = 1
}

# Silver layer: cleaned and conformed data (placeholder for dbt transformations)
resource "snowflake_schema" "silver" {
  database = snowflake_database.ingestion_platform.name
  name     = "SILVER"
  comment  = "Silver layer - cleaned and conformed data (dbt transformations - future)"

  is_transient = false
  is_managed   = false

  data_retention_time_in_days = 1
}

# Governance schema: audit tables, metadata, lineage tracking (weeks 10-11)
resource "snowflake_schema" "governance" {
  database = snowflake_database.ingestion_platform.name
  name     = "GOVERNANCE"
  comment  = "Governance layer - audit logs, metadata, lineage (future)"

  is_transient = false
  is_managed   = false

  data_retention_time_in_days = 7  # Keep audit data longer
}
