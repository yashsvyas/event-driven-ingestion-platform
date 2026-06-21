terraform {
  required_version = ">= 1.9.0"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.98.0"
    }
  }

  # Terraform Cloud backend for remote state management
  # Run `terraform login` first to authenticate
  # Create a workspace at https://app.terraform.io
  cloud {
    organization = "REPLACE_WITH_YOUR_ORG_NAME"  # Change this after running `terraform login`

    workspaces {
      name = "event-driven-ingestion-platform"
    }
  }
}

# Snowflake provider configuration
# Credentials should be provided via environment variables or GitHub Secrets:
# - SNOWFLAKE_ACCOUNT
# - SNOWFLAKE_USER
# - SNOWFLAKE_PASSWORD
# - SNOWFLAKE_ROLE (should be ACCOUNTADMIN for storage integration provisioning)
provider "snowflake" {
  account  = var.snowflake_account
  user     = var.snowflake_user
  password = var.snowflake_password
  role     = var.snowflake_role
}
