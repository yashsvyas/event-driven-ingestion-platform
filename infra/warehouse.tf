# ===================================
# Snowflake Warehouse (Compute)
# ===================================

resource "snowflake_warehouse" "ingestion_wh" {
  name    = "INGESTION_WH"
  comment = "Warehouse for data ingestion workloads - managed by Terraform"

  # Warehouse size (X-SMALL is sufficient for ingestion workloads)
  warehouse_size = var.warehouse_size

  # Auto-suspend after 60 seconds of inactivity to minimize credit consumption
  auto_suspend = var.warehouse_auto_suspend_seconds

  # Auto-resume when queries are submitted
  auto_resume = true

  # Don't initially suspend (warehouse starts in STARTED state)
  initially_suspended = false

  # Warehouse type: STANDARD (vs. SNOWPARK-OPTIMIZED)
  warehouse_type = "STANDARD"

  # Scale up/down settings (for X-SMALL, scaling is limited)
  min_cluster_count = 1
  max_cluster_count = 1

  # Scaling policy (STANDARD = favor saving credits, ECONOMY = favor performance)
  scaling_policy = "STANDARD"

  # Statement timeout (5 minutes default)
  statement_timeout_in_seconds = 300

  # Query queuing
  enable_query_acceleration = false
}
