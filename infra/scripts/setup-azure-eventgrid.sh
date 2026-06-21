#!/bin/bash

# ===================================
# Azure Event Grid Setup for Snowpipe Auto-Ingest
# ===================================
# This script automates the Azure Event Grid configuration for Snowpipe auto-ingest
# Run this AFTER terraform apply completes successfully
#
# Prerequisites:
# - Azure CLI installed (az command)
# - Logged in to Azure (az login)
# - Snowflake access to get notification channel URLs
#
# What this script does:
# 1. Creates Event Grid subscriptions for each Snowpipe
# 2. Configures blob created events to notify Snowflake
# 3. Enables Snowpipe auto-ingestion from Azure Blob Storage

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===================================
# Configuration (from terraform.tfvars)
# ===================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Azure Event Grid Setup for Snowpipe Auto-Ingest         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Prompt for configuration values
read -p "Enter Azure Resource Group name: " RESOURCE_GROUP
read -p "Enter Azure Storage Account name: " STORAGE_ACCOUNT
read -p "Enter Azure Storage Container name [ingestion-data]: " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-ingestion-data}

read -p "Enter Snowflake Account (e.g., xy12345.us-east-1): " SNOWFLAKE_ACCOUNT
read -p "Enter Snowflake Database name [INGESTION_PLATFORM]: " SNOWFLAKE_DB
SNOWFLAKE_DB=${SNOWFLAKE_DB:-INGESTION_PLATFORM}

read -p "Enter Snowflake Username: " SNOWFLAKE_USER
read -sp "Enter Snowflake Password: " SNOWFLAKE_PASSWORD
echo ""

# ===================================
# Helper Functions
# ===================================

get_snowpipe_notification_channel() {
    local pipe_name=$1
    local database=$2
    local schema=$3

    echo -e "${BLUE}→ Fetching notification channel for ${pipe_name}...${NC}"

    # Use Snowflake CLI to get notification channel
    # Note: This requires snowsql to be installed
    # Alternative: Use REST API or manual query

    local notification_channel=$(snowsql \
        -a "${SNOWFLAKE_ACCOUNT}" \
        -u "${SNOWFLAKE_USER}" \
        -d "${database}" \
        -s "${schema}" \
        -q "SELECT SYSTEM\$GET_SNOWPIPE_INFO('${pipe_name}');" \
        --private-key-path ~/.ssh/snowflake_rsa_key.p8 \
        -o output_format=plain \
        -o header=false \
        -o timing=false \
        -o friendly=false 2>/dev/null | grep -oP '"notificationChannelName":\s*"\K[^"]+')

    if [ -z "$notification_channel" ]; then
        echo -e "${YELLOW}⚠ Could not automatically fetch notification channel${NC}"
        echo -e "${YELLOW}  Please run this query manually in Snowflake:${NC}"
        echo -e "${YELLOW}    SELECT SYSTEM\$GET_SNOWPIPE_INFO('${database}.${schema}.${pipe_name}');${NC}"
        read -p "  Enter notification channel URL: " notification_channel
    fi

    echo "$notification_channel"
}

create_event_subscription() {
    local pipe_name=$1
    local table_path=$2
    local notification_channel=$3
    local subscription_name="snowpipe-${table_path}-subscription"

    echo -e "${BLUE}→ Creating Event Grid subscription: ${subscription_name}${NC}"

    # Get storage account resource ID
    local storage_id=$(az storage account show \
        --name "${STORAGE_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query id \
        --output tsv)

    # Create Event Grid subscription
    az eventgrid event-subscription create \
        --name "${subscription_name}" \
        --source-resource-id "${storage_id}" \
        --endpoint-type webhook \
        --endpoint "${notification_channel}" \
        --included-event-types Microsoft.Storage.BlobCreated \
        --subject-begins-with "/blobServices/default/containers/${CONTAINER_NAME}/blobs/bronze/sqlserver/${table_path}/" \
        --advanced-filter data.api stringin CopyBlob PutBlob PutBlockList FlushWithClose \
        --resource-group "${RESOURCE_GROUP}" \
        2>&1 | tee /tmp/eventgrid_output.log

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Event Grid subscription created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create Event Grid subscription${NC}"
        echo -e "${YELLOW}  Check /tmp/eventgrid_output.log for details${NC}"
        return 1
    fi
}

# ===================================
# Main Execution
# ===================================

echo ""
echo -e "${BLUE}Step 1: Validating Azure configuration${NC}"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}✗ Azure CLI not found. Please install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli${NC}"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}⚠ Not logged in to Azure. Running 'az login'...${NC}"
    az login
fi

# Verify storage account exists
if ! az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" &> /dev/null; then
    echo -e "${RED}✗ Storage account '${STORAGE_ACCOUNT}' not found in resource group '${RESOURCE_GROUP}'${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Azure configuration validated${NC}"

echo ""
echo -e "${BLUE}Step 2: Fetching Snowpipe notification channels${NC}"

# Get notification channels for each pipe
TRADES_CHANNEL=$(get_snowpipe_notification_channel "TRADES_PIPE" "${SNOWFLAKE_DB}" "BRONZE")
POSITIONS_CHANNEL=$(get_snowpipe_notification_channel "POSITIONS_PIPE" "${SNOWFLAKE_DB}" "BRONZE")
CASH_MOVEMENTS_CHANNEL=$(get_snowpipe_notification_channel "CASH_MOVEMENTS_PIPE" "${SNOWFLAKE_DB}" "BRONZE")

echo -e "${GREEN}✓ Notification channels retrieved${NC}"

echo ""
echo -e "${BLUE}Step 3: Creating Event Grid subscriptions${NC}"

# Create Event Grid subscriptions for each table
create_event_subscription "TRADES_PIPE" "trades" "${TRADES_CHANNEL}"
create_event_subscription "POSITIONS_PIPE" "positions" "${POSITIONS_CHANNEL}"
create_event_subscription "CASH_MOVEMENTS_PIPE" "cash_movements" "${CASH_MOVEMENTS_CHANNEL}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Setup Complete!                                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Upload a test Parquet file to Azure Blob Storage"
echo "  2. Verify automatic ingestion into Snowflake tables"
echo "  3. Check Snowpipe status with: SELECT * FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY());"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  - View Event Grid subscription status: az eventgrid event-subscription list --resource-group ${RESOURCE_GROUP}"
echo "  - Check Snowpipe errors: SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY());"
echo ""
