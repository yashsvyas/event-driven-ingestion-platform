# ===================================
# Snowpipe Auto-Ingest Configurations
# ===================================
# Snowpipe automatically loads data from Azure Blob Storage when new files arrive
# Requires Azure Event Grid configuration (automated via scripts/setup-azure-eventgrid.sh)

# ===================================
# Snowpipe for TRADES
# ===================================

resource "snowflake_pipe" "trades_pipe" {
  count = var.enable_bronze_tables ? 1 : 0

  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  name     = "TRADES_PIPE"
  comment  = "Auto-ingest Parquet files for trades table - managed by Terraform"

  # COPY INTO statement
  # Snowpipe watches the stage path and executes this COPY command for new files
  copy_statement = <<-SQL
    COPY INTO ${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_table.trades[0].name}
    FROM (
      SELECT
        $1:TRADE_ID::NUMBER(38,0) AS TRADE_ID,
        $1:ISIN::VARCHAR(12) AS ISIN,
        $1:COUNTERPARTY::VARCHAR(100) AS COUNTERPARTY,
        $1:NOTIONAL_AMOUNT::NUMBER(18,2) AS NOTIONAL_AMOUNT,
        $1:CURRENCY::VARCHAR(3) AS CURRENCY,
        $1:TRADE_DATE::DATE AS TRADE_DATE,
        $1:SETTLEMENT_DATE::DATE AS SETTLEMENT_DATE,
        $1:BUY_SELL_INDICATOR::VARCHAR(4) AS BUY_SELL_INDICATOR,
        $1:ASSET_CLASS::VARCHAR(2) AS ASSET_CLASS,
        $1:STATUS::VARCHAR(20) AS STATUS,
        $1:CREATED_AT::TIMESTAMP_NTZ AS CREATED_AT,
        $1:UPDATED_AT::TIMESTAMP_NTZ AS UPDATED_AT,
        CURRENT_TIMESTAMP() AS _LOADED_AT,
        METADATA$$FILENAME AS _SOURCE_FILE,
        $1:_BATCH_ID::VARCHAR(100) AS _BATCH_ID
      FROM @${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_stage.bronze_stage.name}/sqlserver/trades/
    )
    FILE_FORMAT = (FORMAT_NAME = '${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_file_format.parquet_format.name}')
    PATTERN = '.*\.parquet'
  SQL

  # Auto-ingest via Azure Event Grid
  auto_ingest = true

  # Error handling: CONTINUE loading even if some rows fail
  error_integration = null

  # AWS SNS topic (not used for Azure, but required by provider)
  # For Azure, notification channel is configured via Event Grid post-deployment
  aws_sns_topic_arn = null

  depends_on = [
    snowflake_table.trades,
    snowflake_stage.bronze_stage,
    snowflake_file_format.parquet_format
  ]
}

# ===================================
# Snowpipe for POSITIONS
# ===================================

resource "snowflake_pipe" "positions_pipe" {
  count = var.enable_bronze_tables ? 1 : 0

  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  name     = "POSITIONS_PIPE"
  comment  = "Auto-ingest Parquet files for positions table - managed by Terraform"

  copy_statement = <<-SQL
    COPY INTO ${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_table.positions[0].name}
    FROM (
      SELECT
        $1:POSITION_ID::NUMBER(38,0) AS POSITION_ID,
        $1:ISIN::VARCHAR(12) AS ISIN,
        $1:QUANTITY::NUMBER(18,4) AS QUANTITY,
        $1:MARKET_VALUE::NUMBER(18,2) AS MARKET_VALUE,
        $1:CURRENCY::VARCHAR(3) AS CURRENCY,
        $1:OAD::NUMBER(10,4) AS OAD,
        $1:OAS::NUMBER(10,4) AS OAS,
        $1:DTS::NUMBER(10,4) AS DTS,
        $1:ASSET_CLASS::VARCHAR(2) AS ASSET_CLASS,
        $1:AS_OF_DATE::DATE AS AS_OF_DATE,
        $1:UPDATED_AT::TIMESTAMP_NTZ AS UPDATED_AT,
        CURRENT_TIMESTAMP() AS _LOADED_AT,
        METADATA$$FILENAME AS _SOURCE_FILE,
        $1:_BATCH_ID::VARCHAR(100) AS _BATCH_ID
      FROM @${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_stage.bronze_stage.name}/sqlserver/positions/
    )
    FILE_FORMAT = (FORMAT_NAME = '${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_file_format.parquet_format.name}')
    PATTERN = '.*\.parquet'
  SQL

  auto_ingest = true
  error_integration = null
  aws_sns_topic_arn = null

  depends_on = [
    snowflake_table.positions,
    snowflake_stage.bronze_stage,
    snowflake_file_format.parquet_format
  ]
}

# ===================================
# Snowpipe for CASH_MOVEMENTS
# ===================================

resource "snowflake_pipe" "cash_movements_pipe" {
  count = var.enable_bronze_tables ? 1 : 0

  database = snowflake_database.ingestion_platform.name
  schema   = snowflake_schema.bronze.name
  name     = "CASH_MOVEMENTS_PIPE"
  comment  = "Auto-ingest Parquet files for cash_movements table - managed by Terraform"

  copy_statement = <<-SQL
    COPY INTO ${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_table.cash_movements[0].name}
    FROM (
      SELECT
        $1:MOVEMENT_ID::NUMBER(38,0) AS MOVEMENT_ID,
        $1:CURRENCY::VARCHAR(3) AS CURRENCY,
        $1:AMOUNT::NUMBER(18,2) AS AMOUNT,
        $1:VALUE_DATE::DATE AS VALUE_DATE,
        $1:DIRECTION::VARCHAR(3) AS DIRECTION,
        $1:STATUS::VARCHAR(20) AS STATUS,
        $1:COUNTERPARTY::VARCHAR(100) AS COUNTERPARTY,
        $1:CREATED_AT::TIMESTAMP_NTZ AS CREATED_AT,
        $1:UPDATED_AT::TIMESTAMP_NTZ AS UPDATED_AT,
        CURRENT_TIMESTAMP() AS _LOADED_AT,
        METADATA$$FILENAME AS _SOURCE_FILE,
        $1:_BATCH_ID::VARCHAR(100) AS _BATCH_ID
      FROM @${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_stage.bronze_stage.name}/sqlserver/cash_movements/
    )
    FILE_FORMAT = (FORMAT_NAME = '${snowflake_database.ingestion_platform.name}.${snowflake_schema.bronze.name}.${snowflake_file_format.parquet_format.name}')
    PATTERN = '.*\.parquet'
  SQL

  auto_ingest = true
  error_integration = null
  aws_sns_topic_arn = null

  depends_on = [
    snowflake_table.cash_movements,
    snowflake_stage.bronze_stage,
    snowflake_file_format.parquet_format
  ]
}

# ===================================
# Grant OWNERSHIP on Pipes to INGESTION_ROLE
# ===================================

resource "snowflake_grant_ownership" "trades_pipe_ownership" {
  count = var.enable_bronze_tables ? 1 : 0

  account_role_name   = snowflake_role.ingestion_role.name
  outbound_privileges = "COPY"

  on {
    object_type = "PIPE"
    object_name = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.bronze.name}\".\"${snowflake_pipe.trades_pipe[0].name}\""
  }

  depends_on = [snowflake_pipe.trades_pipe]
}

resource "snowflake_grant_ownership" "positions_pipe_ownership" {
  count = var.enable_bronze_tables ? 1 : 0

  account_role_name   = snowflake_role.ingestion_role.name
  outbound_privileges = "COPY"

  on {
    object_type = "PIPE"
    object_name = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.bronze.name}\".\"${snowflake_pipe.positions_pipe[0].name}\""
  }

  depends_on = [snowflake_pipe.positions_pipe]
}

resource "snowflake_grant_ownership" "cash_movements_pipe_ownership" {
  count = var.enable_bronze_tables ? 1 : 0

  account_role_name   = snowflake_role.ingestion_role.name
  outbound_privileges = "COPY"

  on {
    object_type = "PIPE"
    object_name = "\"${snowflake_database.ingestion_platform.name}\".\"${snowflake_schema.bronze.name}\".\"${snowflake_pipe.cash_movements_pipe[0].name}\""
  }

  depends_on = [snowflake_pipe.cash_movements_pipe]
}
