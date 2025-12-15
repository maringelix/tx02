.PHONY: help init plan apply destroy aks-connect clean

# Variables
ENV ?= prd
TF_DIR = terraform/$(ENV)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	@echo "🔧 Initializing Terraform for $(ENV)..."
	cd $(TF_DIR) && terraform init

validate: ## Validate Terraform configuration
	@echo "✅ Validating Terraform..."
	cd $(TF_DIR) && terraform validate

fmt: ## Format Terraform files
	@echo "🎨 Formatting Terraform files..."
	terraform fmt -recursive

plan: ## Run Terraform plan
	@echo "📋 Running Terraform plan for $(ENV)..."
	cd $(TF_DIR) && terraform plan

apply: ## Apply Terraform changes
	@echo "🚀 Applying Terraform for $(ENV)..."
	cd $(TF_DIR) && terraform apply

destroy: ## Destroy infrastructure
	@echo "🗑️  Destroying infrastructure for $(ENV)..."
	cd $(TF_DIR) && terraform destroy

output: ## Show Terraform outputs
	@echo "📊 Terraform outputs for $(ENV):"
	cd $(TF_DIR) && terraform output

# AKS Commands
aks-connect: ## Connect to AKS cluster
	@echo "🔌 Connecting to AKS..."
	cd $(TF_DIR) && \
	RG=$$(terraform output -raw resource_group_name) && \
	CLUSTER=$$(terraform output -raw aks_cluster_name) && \
	az aks get-credentials --resource-group $$RG --name $$CLUSTER --overwrite-existing

aks-nodes: ## Show AKS nodes
	@kubectl get nodes

aks-pods: ## Show all pods
	@kubectl get pods -A

aks-logs: ## Show logs (requires POD variable)
	@kubectl logs -f $(POD) -n dx02

# Database Commands
db-connect: ## Connect to database
	@cd $(TF_DIR) && \
	DB_HOST=$$(terraform output -raw db_host) && \
	echo "psql -h $$DB_HOST -U dbadmin -d dx02db"

# Cleanup
clean: ## Clean Terraform files
	@echo "🧹 Cleaning Terraform files..."
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.tfstate*" -delete 2>/dev/null || true
	find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true

# Azure Login
azure-login: ## Login to Azure
	@az login

azure-info: ## Show Azure account info
	@az account show

# Cost Estimation
cost: ## Show estimated costs
	@echo "💰 Estimativa de custos:"
	@echo "  AKS (3x Standard_B2s): ~90 USD/mês"
	@echo "  Database (B_Standard_B1ms): ~30 USD/mês"
	@echo "  Load Balancer: ~5 USD/mês"
	@echo "  Storage: ~5 USD/mês"
	@echo "  -----------------------------------"
	@echo "  TOTAL estimado: ~130 USD/mês"
