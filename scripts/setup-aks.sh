#!/bin/bash
# setup-aks.sh - Script para configurar AKS após criação via Terraform

set -e

RESOURCE_GROUP=${1:-"tx02-prd-rg"}
CLUSTER_NAME=${2:-"tx02-prd-aks"}

echo "🔧 Configurando AKS Cluster: $CLUSTER_NAME"
echo "📦 Resource Group: $RESOURCE_GROUP"

# Get AKS credentials
echo "📥 Obtendo credenciais do AKS..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify connection
echo "✅ Verificando conexão..."
kubectl cluster-info
kubectl get nodes

# Create namespace
echo "📁 Criando namespace dx02..."
kubectl create namespace dx02 --dry-run=client -o yaml | kubectl apply -f -

# Install NGINX Ingress Controller
echo "🌐 Instalando NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

# Wait for ingress controller
echo "⏳ Aguardando Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Install cert-manager (para HTTPS)
echo "🔐 Instalando cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s

echo "✅ Setup do AKS completo!"
echo ""
echo "Próximos passos:"
echo "1. Criar secret do database:"
echo "   kubectl create secret generic dx02-db-secret \\"
echo "     --from-literal=host=YOUR_DB_HOST \\"
echo "     --from-literal=database=dx02db \\"
echo "     --from-literal=username=dbadmin \\"
echo "     --from-literal=password=YOUR_PASSWORD \\"
echo "     --namespace=dx02"
echo ""
echo "2. Deploy da aplicação:"
echo "   kubectl apply -f k8s/ -n dx02"
echo ""
echo "3. Verificar deployment:"
echo "   kubectl get all -n dx02"
