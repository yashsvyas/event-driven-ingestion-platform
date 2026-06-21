# ===================================
# Snowflake Authentication Variables
# ===================================

variable "snowflake_account" {
  description = "Snowflake account identifier (e.g., xy12345.us-east-1)"
  type        = string
  sensitive   = true
}

variable "snowflake_user" {
  description = "Snowflake username for Terraform (use a dedicated service account, not your personal account)"
  type        = string
  sensitive   = true
}

variable "snowflake_password" {
  description = "Snowflake password for Terraform user"
  type        = string
  sensitive   = true
}

variable "snowflake_role" {
  description = "Snowflake role for Terraform (must be ACCOUNTADMIN for storage integration provisioning)"
  type        = string
  default     = "ACCOUNTADMIN"
}

# ===================================
# Azure Storage Integration Variables
# ===================================

variable "azure_tenant_id" {
  description = "Azure Active Directory tenant ID for Snowflake storage integration"
  type        = string
  sensitive   = true
}

variable "azure_storage_account_name" {
  description = "Azure Storage Account name where Parquet files will be stored"
  type        = string
}

variable "azure_storage_container_name" {
  description = "Azure Blob Storage container name for ingestion files"
  type        = string
  default     = "ingestion-data"
}

variable "azure_resource_group" {
  description = "Azure Resource Group containing the storage account"
  type        = string
}

# ===================================
# Project Configuration
# ===================================

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ingestion_platform"
}

# ===================================
# Snowflake Resource Configuration
# ===================================

variable "warehouse_size" {
  description = "Size of the Snowflake warehouse (X-SMALL, SMALL, MEDIUM, etc.)"
  type        = string
  default     = "X-SMALL"
}

variable "warehouse_auto_suspend_seconds" {
  description = "Seconds of inactivity before warehouse auto-suspends"
  type        = number
  default     = 60
}

variable "snowpipe_error_handling" {
  description = "Snowpipe error handling mode (CONTINUE or ABORT_STATEMENT)"
  type        = string
  default     = "CONTINUE"
}

# ===================================
# Table Schema Definitions
# ===================================

# These match your SQL Server source schema
# You can override these if your source schema changes

variable "enable_bronze_tables" {
  description = "Enable creation of bronze layer tables"
  type        = bool
  default     = true
}
