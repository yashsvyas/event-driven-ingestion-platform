# ===================================
# Custom Roles
# ===================================

resource "snowflake_role" "ingestion_role" {
  name    = "INGESTION_ROLE"
  comment = "Role for data ingestion services - owns database objects and can execute Snowpipe"
}

# ===================================
# Database Grants
# ===================================

# Grant ownership of the database to INGESTION_ROLE
resource "snowflake_grant_ownership" "database_ownership" {
  account_role_name   = snowflake_role.ingestion_role.name
  outbound_privileges = "COPY"

  on {
    object_type = "DATABASE"
    object_name = snowflake_database.ingestion_platform.name
  }
}

# Grant usage on database to INGESTION_ROLE (in case ownership transfer doesn't cover it)
resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["USAGE", "MONITOR"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.ingestion_platform.name
  }

  depends_on = [snowflake_database.ingestion_platform]
}

# ===================================
# Schema Grants
# ===================================

resource "snowflake_grant_privileges_to_account_role" "schema_bronze_usage" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE STAGE", "CREATE PIPE", "CREATE FILE FORMAT"]

  on_schema {
    schema_name = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.bronze.name}\""
  }

  depends_on = [snowflake_schema.bronze]
}

resource "snowflake_grant_privileges_to_account_role" "schema_silver_usage" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["USAGE", "CREATE TABLE"]

  on_schema {
    schema_name = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.silver.name}\""
  }

  depends_on = [snowflake_schema.silver]
}

resource "snowflake_grant_privileges_to_account_role" "schema_governance_usage" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["USAGE", "CREATE TABLE"]

  on_schema {
    schema_name = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.governance.name}\""
  }

  depends_on = [snowflake_schema.governance]
}

# ===================================
# Warehouse Grants
# ===================================

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["USAGE", "OPERATE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.ingestion_wh.name
  }

  depends_on = [snowflake_warehouse.ingestion_wh]
}

# ===================================
# Future Grants (auto-grant privileges on future objects)
# ===================================

# Grant privileges on future tables in BRONZE schema
resource "snowflake_grant_privileges_to_account_role" "future_tables_bronze" {
  account_role_name = snowflake_role.ingestion_role.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE"]

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.bronze.name}\""
    }
  }

  depends_on = [snowflake_schema.bronze]
}

# ===================================
# Role Hierarchy
# ===================================

# Grant INGESTION_ROLE to SYSADMIN (best practice for custom roles)
resource "snowflake_role_grants" "ingestion_role_grant_to_sysadmin" {
  role_name = snowflake_role.ingestion_role.name

  roles = [
    "SYSADMIN"
  ]
}
