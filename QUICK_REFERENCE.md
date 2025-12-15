# Quick Reference - TX02 & DX02

Comandos rápidos e úteis para trabalhar com Azure.

---

## 🚀 Quick Start

```bash
# 1. Login Azure
az login

# 2. Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# 3. Clone repo
git clone https://github.com/maringelix/tx02.git
cd tx02

# 4. Initialize Terraform
cd terraform/prd
terraform init
terraform plan
terraform apply

# 5. Connect to AKS
az aks get-credentials --resource-group tx02-prd-rg --name tx02-prd-aks

# 6. Deploy app
cd ../../../dx02
kubectl apply -f k8s/ -n dx02
```

---

## 📦 Azure CLI

### Login & Account
```bash
# Login
az login

# Show current account
az account show

# List subscriptions
az account list --output table

# Set subscription
az account set --subscription "SUBSCRIPTION_ID"
```

### Resource Groups
```bash
# List all resource groups
az group list --output table

# Show specific RG
az group show --name tx02-prd-rg

# Delete RG (careful!)
az group delete --name tx02-prd-rg --yes --no-wait
```

### AKS
```bash
# Get credentials
az aks get-credentials --resource-group tx02-prd-rg --name tx02-prd-aks

# List clusters
az aks list --output table

# Show cluster details
az aks show --resource-group tx02-prd-rg --name tx02-prd-aks

# Scale node pool
az aks scale --resource-group tx02-prd-rg \
  --name tx02-prd-aks \
  --node-count 5

# Upgrade Kubernetes version
az aks upgrade --resource-group tx02-prd-rg \
  --name tx02-prd-aks \
  --kubernetes-version 1.32.0
```

### Azure Database for PostgreSQL
```bash
# List servers
az postgres flexible-server list --output table

# Show server
az postgres flexible-server show \
  --resource-group tx02-prd-rg \
  --name tx02-prd-db

# Connect to database
az postgres flexible-server connect \
  --name tx02-prd-db \
  --database-name dx02db \
  --admin-user dbadmin

# Show connection string
az postgres flexible-server show-connection-string \
  --server-name tx02-prd-db
```

---

## ☸️ Kubernetes (kubectl)

### Context
```bash
# Show current context
kubectl config current-context

# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context tx02-prd-aks
```

### Pods
```bash
# List all pods
kubectl get pods -A

# List pods in namespace
kubectl get pods -n dx02

# Describe pod
kubectl describe pod POD_NAME -n dx02

# Logs
kubectl logs -f POD_NAME -n dx02

# Execute command in pod
kubectl exec -it POD_NAME -n dx02 -- sh
```

### Deployments
```bash
# List deployments
kubectl get deployments -n dx02

# Scale deployment
kubectl scale deployment/dx02 --replicas=5 -n dx02

# Rollout status
kubectl rollout status deployment/dx02 -n dx02

# Rollout history
kubectl rollout history deployment/dx02 -n dx02

# Rollback
kubectl rollout undo deployment/dx02 -n dx02
```

### Services
```bash
# List services
kubectl get svc -A

# Get external IP
kubectl get svc dx02 -n dx02 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Port forward
kubectl port-forward svc/dx02 8080:80 -n dx02
```

### Secrets
```bash
# Create secret
kubectl create secret generic dx02-db-secret \
  --from-literal=host=tx02-prd-db.postgres.database.azure.com \
  --from-literal=database=dx02db \
  --from-literal=username=dbadmin \
  --from-literal=password=PASSWORD \
  -n dx02

# View secrets (encoded)
kubectl get secret dx02-db-secret -n dx02 -o yaml

# Decode secret
kubectl get secret dx02-db-secret -n dx02 -o jsonpath='{.data.password}' | base64 -d
```

### Events & Logs
```bash
# View events
kubectl get events -n dx02 --sort-by='.lastTimestamp'

# View all logs in namespace
kubectl logs -l app=dx02 -n dx02 --tail=100

# Stream logs
kubectl logs -f deployment/dx02 -n dx02
```

---

## 🔧 Terraform

### Basic Commands
```bash
# Initialize
terraform init

# Format code
terraform fmt -recursive

# Validate
terraform validate

# Plan
terraform plan

# Apply
terraform apply

# Destroy
terraform destroy

# Show outputs
terraform output

# Show state
terraform show
```

### State Management
```bash
# List resources
terraform state list

# Show resource
terraform state show azurerm_resource_group.main

# Remove resource from state
terraform state rm azurerm_resource_group.main

# Pull state
terraform state pull

# Force unlock
terraform force-unlock LOCK_ID
```

---

## 🐳 Docker

### Build & Run
```bash
# Build image
docker build -t dx02:latest .

# Run locally
docker run -p 80:80 \
  -e DB_HOST=localhost \
  -e DB_NAME=dx02db \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  dx02:latest

# Run with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Azure Container Registry (ACR)
```bash
# Create ACR
az acr create --resource-group tx02-prd-rg \
  --name tx02acr \
  --sku Basic

# Login to ACR
az acr login --name tx02acr

# Tag image
docker tag dx02:latest tx02acr.azurecr.io/dx02:latest

# Push image
docker push tx02acr.azurecr.io/dx02:latest

# List images
az acr repository list --name tx02acr --output table
```

---

## 📊 Monitoring

### Resource Metrics
```bash
# AKS metrics
az monitor metrics list \
  --resource /subscriptions/SUB_ID/resourceGroups/tx02-prd-rg/providers/Microsoft.ContainerService/managedClusters/tx02-prd-aks \
  --metric "node_cpu_usage_percentage"

# Database metrics
az monitor metrics list \
  --resource /subscriptions/SUB_ID/resourceGroups/tx02-prd-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/tx02-prd-db \
  --metric "cpu_percent"
```

### Kubernetes Metrics
```bash
# Node metrics
kubectl top nodes

# Pod metrics
kubectl top pods -n dx02

# HPA status
kubectl get hpa -n dx02

# Resource usage
kubectl describe node NODE_NAME
```

---

## 💰 Cost Management
```bash
# Show costs by resource group
az consumption usage list \
  --start-date 2025-12-01 \
  --end-date 2025-12-15 \
  --query "[?contains(instanceName, 'tx02')]"

# Cost analysis
az costmanagement query \
  --type Usage \
  --dataset-filter "{\"and\":[{\"dimension\":{\"name\":\"ResourceGroup\",\"operator\":\"In\",\"values\":[\"tx02-prd-rg\"]}}]}"
```

---

## 🆘 Troubleshooting

### AKS não sobe os nodes
```bash
# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Ver node status
kubectl describe node NODE_NAME

# Ver quota
az vm list-usage --location eastus --output table
```

### Database não conecta
```bash
# Testar conectividade
nc -zv tx02-prd-db.postgres.database.azure.com 5432

# Ver firewall rules
az postgres flexible-server firewall-rule list \
  --resource-group tx02-prd-rg \
  --name tx02-prd-db

# Adicionar regra
az postgres flexible-server firewall-rule create \
  --resource-group tx02-prd-rg \
  --name tx02-prd-db \
  --rule-name AllowMyIP \
  --start-ip-address YOUR_IP \
  --end-ip-address YOUR_IP
```

### Pod não inicia
```bash
# Ver logs
kubectl logs POD_NAME -n dx02

# Ver eventos
kubectl describe pod POD_NAME -n dx02

# Ver imagem
kubectl get pod POD_NAME -n dx02 -o jsonpath='{.spec.containers[0].image}'
```

---

## 🔗 Links Úteis

- [Azure CLI Docs](https://docs.microsoft.com/cli/azure/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

**Última atualização:** Dezembro 2025
