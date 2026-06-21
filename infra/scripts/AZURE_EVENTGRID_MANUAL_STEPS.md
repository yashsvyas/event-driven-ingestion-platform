# Azure Event Grid Manual Setup for Snowpipe

If the automated script doesn't work, follow these manual steps to configure Azure Event Grid for Snowpipe auto-ingest.

## Prerequisites

- Terraform apply completed successfully
- Azure consent granted (visit the URL from terraform output: `azure_consent_url`)
- Access to Snowflake and Azure Portal

## Step 1: Get Snowpipe Notification Channels

Run these queries in Snowflake (via Snowflake UI or snowsql):

```sql
USE INGESTION_PLATFORM.BRONZE;

-- Get notification channel for trades pipe
SELECT SYSTEM$GET_SNOWPIPE_INFO('TRADES_PIPE');

-- Get notification channel for positions pipe
SELECT SYSTEM$GET_SNOWPIPE_INFO('POSITIONS_PIPE');

-- Get notification channel for cash_movements pipe
SELECT SYSTEM$GET_SNOWPIPE_INFO('CASH_MOVEMENTS_PIPE');
```

Each result will be JSON. Extract the `notificationChannelName` value - this is the webhook URL.

Example output:
```json
{
  "notificationChannelName": "arn:aws:sqs:us-east-1:123456789012:sf-snowpipe-AIDAI3QEXAMPLEID-tP0abcdefg1234567890",
  ...
}
```

## Step 2: Create Event Grid Subscriptions via Azure Portal

For each table (trades, positions, cash_movements):

1. Go to Azure Portal → Storage Accounts → Your storage account
2. Click "Events" in the left sidebar
3. Click "+ Event Subscription"
4. Configure:
   - **Name**: `snowpipe-trades-subscription` (or positions/cash_movements)
   - **Event Schema**: Event Grid Schema
   - **Topic Type**: Storage Account
   - **Filter to Event Types**: Check "Blob Created" only
   - **Endpoint Type**: Web Hook
   - **Endpoint**: Paste the `notificationChannelName` URL from Step 1

5. Click "Filters" tab:
   - **Subject Filtering**:
     - Subject Begins With: `/blobServices/default/containers/ingestion-data/blobs/bronze/sqlserver/trades/`
       (change `trades` to `positions` or `cash_movements` for other subscriptions)

6. Click "Advanced Filters":
   - Add filter: `data.api` String is in `CopyBlob`, `PutBlob`, `PutBlockList`, `FlushWithClose`

7. Click "Create"

8. Repeat for all three tables

## Step 3: Verify Setup via Azure CLI

```bash
# List all Event Grid subscriptions
az eventgrid event-subscription list \
  --resource-group YOUR_RESOURCE_GROUP

# Check specific subscription
az eventgrid event-subscription show \
  --name snowpipe-trades-subscription \
  --source-resource-id /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/YOUR_STORAGE_ACCOUNT
```

## Step 4: Test Ingestion

Upload a test Parquet file:

```bash
az storage blob upload \
  --account-name YOUR_STORAGE_ACCOUNT \
  --container-name ingestion-data \
  --name bronze/sqlserver/trades/test_2024_01_01.parquet \
  --file /path/to/test.parquet
```

Check Snowflake for ingested data:

```sql
USE INGESTION_PLATFORM.BRONZE;

-- Check table contents
SELECT * FROM TRADES LIMIT 10;

-- Check Snowpipe status
SELECT *
FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
  DATE_RANGE_START => DATEADD('day', -1, CURRENT_DATE()),
  PIPE_NAME => 'INGESTION_PLATFORM.BRONZE.TRADES_PIPE'
));

-- Check for errors
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'INGESTION_PLATFORM.BRONZE.TRADES',
  START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE STATUS = 'LOAD_FAILED';
```

## Troubleshooting

### Event Grid subscription creation fails

**Error**: "The webhook endpoint must be reachable and return 200 OK"

**Solution**: This is normal for the first attempt. Azure Event Grid validates the webhook. Snowflake's notification channel is designed to handle this. Try creating the subscription again.

### Snowpipe not ingesting files

1. **Check pipe status**:
   ```sql
   SHOW PIPES IN SCHEMA BRONZE;
   SELECT "name", "state" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
   ```

2. **Manually refresh pipe** (forces check for new files):
   ```sql
   ALTER PIPE TRADES_PIPE REFRESH;
   ```

3. **Check for errors**:
   ```sql
   SELECT *
   FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
     TABLE_NAME => 'INGESTION_PLATFORM.BRONZE.TRADES',
     START_TIME => DATEADD('day', -7, CURRENT_TIMESTAMP())
   ))
   ORDER BY LAST_LOAD_TIME DESC;
   ```

### Files in wrong path

Ensure your files follow this structure:
```
ingestion-data/
└── bronze/
    └── sqlserver/
        ├── trades/
        │   └── *.parquet
        ├── positions/
        │   └── *.parquet
        └── cash_movements/
            └── *.parquet
```

## Reference Documentation

- [Snowflake: Automating Snowpipe for Azure Blob Storage](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto-azure)
- [Azure Event Grid: Blob Storage Events](https://docs.microsoft.com/en-us/azure/event-grid/event-schema-blob-storage)
