# ===================================
# Bronze Layer Tables
# ===================================
# These tables mirror the SQL Server source schema with additional ingestion metadata columns
# Schema source: sql/init.sql

# ===================================
# BRONZE.TRADES
# ===================================

resource "snowflake_table" "trades" {
  count = var.enable_bronze_tables ? 1 : 0

  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  name     = "TRADES"
  comment  = "Bronze layer - Trade executions from SQL Server CDC - managed by Terraform"

  # Source columns (from SQL Server dbo.trades)
  column {
    name     = "TRADE_ID"
    type     = "NUMBER(38,0)"
    nullable = false
    comment  = "Primary key from source system"
  }

  column {
    name     = "ISIN"
    type     = "VARCHAR(12)"
    nullable = false
    comment  = "International Securities Identification Number"
  }

  column {
    name     = "COUNTERPARTY"
    type     = "VARCHAR(100)"
    nullable = false
  }

  column {
    name     = "NOTIONAL_AMOUNT"
    type     = "NUMBER(18,2)"
    nullable = false
  }

  column {
    name     = "CURRENCY"
    type     = "VARCHAR(3)"
    nullable = false
  }

  column {
    name     = "TRADE_DATE"
    type     = "DATE"
    nullable = false
  }

  column {
    name     = "SETTLEMENT_DATE"
    type     = "DATE"
    nullable = false
  }

  column {
    name     = "BUY_SELL_INDICATOR"
    type     = "VARCHAR(4)"
    nullable = false
    comment  = "BUY or SELL"
  }

  column {
    name     = "ASSET_CLASS"
    type     = "VARCHAR(2)"
    nullable = false
    comment  = "EQ (Equity), FI (Fixed Income), or FX (Foreign Exchange)"
  }

  column {
    name     = "STATUS"
    type     = "VARCHAR(20)"
    nullable = false
    comment  = "PENDING, CONFIRMED, SETTLED, or CANCELLED"
  }

  column {
    name     = "CREATED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
    comment  = "Timestamp from source system"
  }

  column {
    name     = "UPDATED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
    comment  = "Last update timestamp from source system"
  }

  # Ingestion metadata columns
  column {
    name     = "_LOADED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
    comment  = "Snowflake ingestion timestamp"
  }

  column {
    name     = "_SOURCE_FILE"
    type     = "VARCHAR(500)"
    nullable = true
    comment  = "Source Parquet file path in Azure Blob Storage"
  }

  column {
    name     = "_BATCH_ID"
    type     = "VARCHAR(100)"
    nullable = true
    comment  = "CDC batch identifier from extraction service"
  }

  depends_on = [snowflake_schema.bronze]
}

# ===================================
# BRONZE.POSITIONS
# ===================================

resource "snowflake_table" "positions" {
  count = var.enable_bronze_tables ? 1 : 0

  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  name     = "POSITIONS"
  comment  = "Bronze layer - Portfolio positions with risk metrics from SQL Server CDC - managed by Terraform"

  # Source columns (from SQL Server dbo.positions)
  column {
    name     = "POSITION_ID"
    type     = "NUMBER(38,0)"
    nullable = false
    comment  = "Primary key from source system"
  }

  column {
    name     = "ISIN"
    type     = "VARCHAR(12)"
    nullable = false
  }

  column {
    name     = "QUANTITY"
    type     = "NUMBER(18,4)"
    nullable = false
  }

  column {
    name     = "MARKET_VALUE"
    type     = "NUMBER(18,2)"
    nullable = false
  }

  column {
    name     = "CURRENCY"
    type     = "VARCHAR(3)"
    nullable = false
  }

  column {
    name     = "OAD"
    type     = "NUMBER(10,4)"
    nullable = true
    comment  = "Option-Adjusted Duration (for Fixed Income)"
  }

  column {
    name     = "OAS"
    type     = "NUMBER(10,4)"
    nullable = true
    comment  = "Option-Adjusted Spread in basis points (for Fixed Income)"
  }

  column {
    name     = "DTS"
    type     = "NUMBER(10,4)"
    nullable = true
    comment  = "Duration Times Spread - risk metric (for Fixed Income)"
  }

  column {
    name     = "ASSET_CLASS"
    type     = "VARCHAR(2)"
    nullable = false
    comment  = "EQ, FI, or FX"
  }

  column {
    name     = "AS_OF_DATE"
    type     = "DATE"
    nullable = false
    comment  = "Snapshot date for position"
  }

  column {
    name     = "UPDATED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
  }

  # Ingestion metadata columns
  column {
    name     = "_LOADED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
    comment  = "Snowflake ingestion timestamp"
  }

  column {
    name     = "_SOURCE_FILE"
    type     = "VARCHAR(500)"
    nullable = true
    comment  = "Source Parquet file path"
  }

  column {
    name     = "_BATCH_ID"
    type     = "VARCHAR(100)"
    nullable = true
    comment  = "CDC batch identifier"
  }

  depends_on = [snowflake_schema.bronze]
}

# ===================================
# BRONZE.CASH_MOVEMENTS
# ===================================

resource "snowflake_table" "cash_movements" {
  count = var.enable_bronze_tables ? 1 : 0

  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  name     = "CASH_MOVEMENTS"
  comment  = "Bronze layer - Cash flows (settlements, dividends, coupons, fees) from SQL Server CDC - managed by Terraform"

  # Source columns (from SQL Server dbo.cash_movements)
  column {
    name     = "MOVEMENT_ID"
    type     = "NUMBER(38,0)"
    nullable = false
    comment  = "Primary key from source system"
  }

  column {
    name     = "CURRENCY"
    type     = "VARCHAR(3)"
    nullable = false
  }

  column {
    name     = "AMOUNT"
    type     = "NUMBER(18,2)"
    nullable = false
  }

  column {
    name     = "VALUE_DATE"
    type     = "DATE"
    nullable = false
    comment  = "Date when cash movement is effective"
  }

  column {
    name     = "DIRECTION"
    type     = "VARCHAR(3)"
    nullable = false
    comment  = "IN or OUT"
  }

  column {
    name     = "STATUS"
    type     = "VARCHAR(20)"
    nullable = false
    comment  = "PENDING, SETTLED, or FAILED"
  }

  column {
    name     = "COUNTERPARTY"
    type     = "VARCHAR(100)"
    nullable = false
  }

  column {
    name     = "CREATED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
  }

  column {
    name     = "UPDATED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
  }

  # Ingestion metadata columns
  column {
    name     = "_LOADED_AT"
    type     = "TIMESTAMP_NTZ"
    nullable = false
    comment  = "Snowflake ingestion timestamp"
  }

  column {
    name     = "_SOURCE_FILE"
    type     = "VARCHAR(500)"
    nullable = true
    comment  = "Source Parquet file path"
  }

  column {
    name     = "_BATCH_ID"
    type     = "VARCHAR(100)"
    nullable = true
    comment  = "CDC batch identifier"
  }

  depends_on = [snowflake_schema.bronze]
}
