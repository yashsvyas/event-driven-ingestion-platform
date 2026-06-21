# ===================================
# Makefile for Terraform via Docker
# ===================================
# No local Terraform installation required
# All commands run in Docker container

.PHONY: help tf-init tf-validate tf-plan tf-apply tf-destroy tf-fmt tf-shell tf-login

# Docker configuration
TERRAFORM_VERSION := 1.9
DOCKER_IMAGE := hashicorp/terraform:$(TERRAFORM_VERSION)
WORK_DIR := /workspace
INFRA_DIR := $(PWD)/infra

# Terraform Cloud token location (for local development)
TF_TOKEN_FILE := $(HOME)/.terraform.d/credentials.tfrc.json

# Colors for output
COLOR_RESET := \033[0m
COLOR_BLUE := \033[34m
COLOR_GREEN := \033[32m
COLOR_YELLOW := \033[33m

help: ## Show this help message
	@echo "$(COLOR_BLUE)Terraform Commands (via Docker)$(COLOR_RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-20s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(COLOR_YELLOW)Prerequisites:$(COLOR_RESET)"
	@echo "  - Docker installed and running"
	@echo "  - Terraform Cloud account (free tier): https://app.terraform.io"
	@echo "  - Run 'make tf-login' first to authenticate"
	@echo ""

tf-login: ## Login to Terraform Cloud (required once)
	@echo "$(COLOR_BLUE)Logging in to Terraform Cloud...$(COLOR_RESET)"
	@docker run --rm -it \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-w $(WORK_DIR) \
		$(DOCKER_IMAGE) login

tf-init: ## Initialize Terraform (run this first)
	@echo "$(COLOR_BLUE)Initializing Terraform...$(COLOR_RESET)"
	@docker run --rm \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-v $(TF_TOKEN_FILE):/root/.terraform.d/credentials.tfrc.json:ro \
		-w $(WORK_DIR) \
		-e TF_VAR_snowflake_account=$(TF_VAR_snowflake_account) \
		-e TF_VAR_snowflake_user=$(TF_VAR_snowflake_user) \
		-e TF_VAR_snowflake_password=$(TF_VAR_snowflake_password) \
		-e TF_VAR_snowflake_role=$(TF_VAR_snowflake_role) \
		-e TF_VAR_azure_tenant_id=$(TF_VAR_azure_tenant_id) \
		-e TF_VAR_azure_storage_account_name=$(TF_VAR_azure_storage_account_name) \
		-e TF_VAR_azure_storage_container_name=$(TF_VAR_azure_storage_container_name) \
		-e TF_VAR_azure_resource_group=$(TF_VAR_azure_resource_group) \
		$(DOCKER_IMAGE) init

tf-validate: ## Validate Terraform configuration
	@echo "$(COLOR_BLUE)Validating Terraform configuration...$(COLOR_RESET)"
	@docker run --rm \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-w $(WORK_DIR) \
		$(DOCKER_IMAGE) validate

tf-fmt: ## Format Terraform files
	@echo "$(COLOR_BLUE)Formatting Terraform files...$(COLOR_RESET)"
	@docker run --rm \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-w $(WORK_DIR) \
		$(DOCKER_IMAGE) fmt -recursive

tf-plan: ## Show Terraform execution plan
	@echo "$(COLOR_BLUE)Generating Terraform plan...$(COLOR_RESET)"
	@docker run --rm \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-v $(TF_TOKEN_FILE):/root/.terraform.d/credentials.tfrc.json:ro \
		-w $(WORK_DIR) \
		-e TF_VAR_snowflake_account=$(TF_VAR_snowflake_account) \
		-e TF_VAR_snowflake_user=$(TF_VAR_snowflake_user) \
		-e TF_VAR_snowflake_password=$(TF_VAR_snowflake_password) \
		-e TF_VAR_snowflake_role=$(TF_VAR_snowflake_role) \
		-e TF_VAR_azure_tenant_id=$(TF_VAR_azure_tenant_id) \
		-e TF_VAR_azure_storage_account_name=$(TF_VAR_azure_storage_account_name) \
		-e TF_VAR_azure_storage_container_name=$(TF_VAR_azure_storage_container_name) \
		-e TF_VAR_azure_resource_group=$(TF_VAR_azure_resource_group) \
		$(DOCKER_IMAGE) plan

tf-apply: ## Apply Terraform changes (create/update infrastructure)
	@echo "$(COLOR_BLUE)Applying Terraform changes...$(COLOR_RESET)"
	@docker run --rm -it \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-v $(TF_TOKEN_FILE):/root/.terraform.d/credentials.tfrc.json:ro \
		-w $(WORK_DIR) \
		-e TF_VAR_snowflake_account=$(TF_VAR_snowflake_account) \
		-e TF_VAR_snowflake_user=$(TF_VAR_snowflake_user) \
		-e TF_VAR_snowflake_password=$(TF_VAR_snowflake_password) \
		-e TF_VAR_snowflake_role=$(TF_VAR_snowflake_role) \
		-e TF_VAR_azure_tenant_id=$(TF_VAR_azure_tenant_id) \
		-e TF_VAR_azure_storage_account_name=$(TF_VAR_azure_storage_account_name) \
		-e TF_VAR_azure_storage_container_name=$(TF_VAR_azure_storage_container_name) \
		-e TF_VAR_azure_resource_group=$(TF_VAR_azure_resource_group) \
		$(DOCKER_IMAGE) apply

tf-destroy: ## Destroy all Terraform-managed infrastructure (WARNING: destructive!)
	@echo "$(COLOR_YELLOW)WARNING: This will destroy all infrastructure!$(COLOR_RESET)"
	@docker run --rm -it \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-v $(TF_TOKEN_FILE):/root/.terraform.d/credentials.tfrc.json:ro \
		-w $(WORK_DIR) \
		-e TF_VAR_snowflake_account=$(TF_VAR_snowflake_account) \
		-e TF_VAR_snowflake_user=$(TF_VAR_snowflake_user) \
		-e TF_VAR_snowflake_password=$(TF_VAR_snowflake_password) \
		-e TF_VAR_snowflake_role=$(TF_VAR_snowflake_role) \
		-e TF_VAR_azure_tenant_id=$(TF_VAR_azure_tenant_id) \
		-e TF_VAR_azure_storage_account_name=$(TF_VAR_azure_storage_account_name) \
		-e TF_VAR_azure_storage_container_name=$(TF_VAR_azure_storage_container_name) \
		-e TF_VAR_azure_resource_group=$(TF_VAR_azure_resource_group) \
		$(DOCKER_IMAGE) destroy

tf-shell: ## Open an interactive Terraform shell (for debugging)
	@echo "$(COLOR_BLUE)Opening Terraform shell...$(COLOR_RESET)"
	@docker run --rm -it \
		-v $(INFRA_DIR):$(WORK_DIR) \
		-v $(TF_TOKEN_FILE):/root/.terraform.d/credentials.tfrc.json:ro \
		-w $(WORK_DIR) \
		-e TF_VAR_snowflake_account=$(TF_VAR_snowflake_account) \
		-e TF_VAR_snowflake_user=$(TF_VAR_snowflake_user) \
		-e TF_VAR_snowflake_password=$(TF_VAR_snowflake_password) \
		-e TF_VAR_snowflake_role=$(TF_VAR_snowflake_role) \
		-e TF_VAR_azure_tenant_id=$(TF_VAR_azure_tenant_id) \
		-e TF_VAR_azure_storage_account_name=$(TF_VAR_azure_storage_account_name) \
		-e TF_VAR_azure_storage_container_name=$(TF_VAR_azure_storage_container_name) \
		-e TF_VAR_azure_resource_group=$(TF_VAR_azure_resource_group) \
		--entrypoint /bin/sh \
		$(DOCKER_IMAGE)

# Default target
.DEFAULT_GOAL := help
