# 🚀 DX02 Application Deployment Guide

**Repositório da Aplicação:** https://github.com/maringelix/dx02  
**Repositório da Infraestrutura:** https://github.com/maringelix/tx02

Este guia documenta o processo completo de deployment da aplicação DX02 no cluster AKS provisionado pelo TX02.

---

## 📋 Índice

1. [Arquitetura](#arquitetura)
2. [Pré-requisitos](#pré-requisitos)
3. [Configuração Inicial](#configuração-inicial)
4. [Build e Push da Imagem](#build-e-push-da-imagem)
5. [Deploy no AKS](#deploy-no-aks)
6. [Verificação](#verificação)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                         Deployment Flow                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌───────────────┐         ┌─────────────┐
│   DX02 Repo  │────────▶│  Build Image  │────────▶│     ACR     │
│  (Code Push) │         │ GitHub Actions│         │ tx02prdacr  │
└──────────────┘         └───────────────┘         │.azurecr.io  │
                                                    └──────┬──────┘
                                                           │
                                        AcrPull Role ──────┤
                                        (Automatic)        │
                                                           ▼
┌──────────────┐         ┌───────────────┐         ┌─────────────┐
│   TX02 Repo  │────────▶│  Deploy AKS   │────────▶│ AKS Cluster │
│  (Manifest)  │         │ GitHub Actions│         │  (eastus)   │
└──────────────┘         └───────────────┘         └──────┬──────┘
                                                           │
                                             Private       ▼
                                             Endpoint  ┌─────────────┐
                                                    └─▶│ SQL Server  │
                                                       │  (westus2)  │
                                                       └─────────────┘
```

### Componentes

| Componente | Repositório | Responsabilidade |
|------------|-------------|------------------|
| **DX02** | [maringelix/dx02](https://github.com/maringelix/dx02) | Código da aplicação (React + Express) |
| **TX02** | [maringelix/tx02](https://github.com/maringelix/tx02) | Infraestrutura (Terraform + K8s manifests) |
| **ACR** | Azure Container Registry | Armazenamento de Docker images (tx02prdacr.azurecr.io) |
| **AKS** | Azure Kubernetes Service | Execução dos containers (auto-autenticado no ACR) |
| **SQL** | Azure SQL Database | Banco de dados (westus2 com Private Endpoint) |

---

## ✅ Pré-requisitos

### Infraestrutura (TX02)
- ✅ AKS Cluster provisionado (tx02-prd-aks)
- ✅ Azure SQL Database criado (tx02-prd-sql/tx02-prd-db)
- ✅ Virtual Network configurada
- ✅ GitHub Actions configurado

### Aplicação (DX02)
- ✅ Código migrado para SQL Server (mssql)
- ✅ Dockerfile configurado
- ✅ GitHub Actions workflows criados

### GitHub Secrets Necessários

#### DX02 Repository
| Secret Name | Descrição | Valor |
|-------------|-----------|-------|
| `ACR_USERNAME` | ACR admin username | Obter via `terraform output -raw acr_admin_username` |
| `ACR_PASSWORD` | ACR admin password | Obter via `terraform output -raw acr_admin_password` |

**Como obter as credenciais do ACR:**
```bash
cd tx02/terraform/prd
terraform output -raw acr_admin_username
terraform output -raw acr_admin_password
```

#### TX02 Repository
| Secret Name | Descrição | Valor |
|-------------|-----------|-------|
| `AZURE_SQL_PASSWORD` | Senha do SQL Server | Senha criada manualmente |

> **Nota:** Não precisa mais do `GHCR_PAT`! O AKS está integrado ao ACR via AcrPull role assignment.

---

## 🔧 Configuração Inicial

### 1. Preparar Repositório DX02

```bash
cd /caminho/para/dx02

# Verificar migração SQL Server
cat server/package.json | grep mssql  # Deve mostrar "mssql": "^10.0.1"

# Verificar database.js
head -5 server/database.js  # Deve importar 'mssql'

# Commit mudanças
git add .
git commit -m "feat: Migrate from PostgreSQL to SQL Server for Azure"
git push origin main
```

### 2. Preparar Repositório TX02

```bash
cd /caminho/para/tx02

# Verificar manifestos Kubernetes
ls k8s/
# Deve listar: deployment.yaml, service.yaml, hpa.yaml, ingress.yaml

# Commit manifestos
git add k8s/
git commit -m "feat: Add Kubernetes manifests for DX02 deployment"
git push origin main
```

---

## 🐳 Build e Push da Imagem

### Automático (GitHub Actions - Recomendado)

1. **Push para DX02 main branch:**
   ```bash
   cd /caminho/para/dx02
   git push origin main
   ```

2. **Acompanhar Workflow:**
   - Acesse: https://github.com/maringelix/dx02/actions
   - Workflow: **"Docker Build and Push"**
   - Aguarde conclusão (~3-5 minutos)

3. **Verificar Imagem:**
   - Acesse: https://github.com/maringelix/dx02/pkgs/container/dx02
   - Verificar tag `latest` disponível

### Manual (Local)

```bash
cd /caminho/para/dx02

# Login no GHCR
echo $GHCR_PAT | docker login ghcr.io -u USERNAME --password-stdin

# Build
docker build -t ghcr.io/maringelix/dx02:latest .

# Push
docker push ghcr.io/maringelix/dx02:latest
```

---

## ☸️ Deploy no AKS

### Automático (GitHub Actions - Recomendado)

1. **Via GitHub Web:**
   - Acesse: https://github.com/maringelix/tx02/actions
   - Selecione workflow: **"☁️ Deploy to AKS"**
   - Clique **"Run workflow"**
   - Environment: `prd`
   - Clique **"Run workflow"**

2. **Aguardar Deployment:**
   - Step: Create namespace ✅
   - Step: Create database secret ✅
   - Step: Create GHCR secret ✅
   - Step: Deploy manifests ✅
   - Step: Wait for deployment ✅
   - Step: Get service endpoint ✅

3. **Obter Endpoint:**
   - Workflow summary mostrará IP público
   - Ou via kubectl (veja seção Verificação)

### Manual (kubectl)

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks

# Create namespace
kubectl create namespace dx02

# Create database secret
kubectl create secret generic dx02-db-secret \
  --from-literal=host=tx02-prd-sql.database.windows.net \
  --from-literal=database=tx02-prd-db \
  --from-literal=username=tx02 \
  --from-literal=password=[SENHA_SQL] \
  --namespace=dx02

# Create GHCR secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=maringelix \
  --docker-password=[GHCR_PAT] \
  --namespace=dx02

# Deploy manifests
kubectl apply -f k8s/ -n dx02

# Watch deployment
kubectl get pods -n dx02 -w
```

---

## ✅ Verificação

### Verificar Pods

```bash
kubectl get pods -n dx02

# Output esperado:
# NAME                    READY   STATUS    RESTARTS   AGE
# dx02-xxxxxxxxx-xxxxx    1/1     Running   0          2m
# dx02-xxxxxxxxx-xxxxx    1/1     Running   0          2m
```

### Verificar Service

```bash
kubectl get svc -n dx02

# Output esperado:
# NAME   TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)        AGE
# dx02   LoadBalancer   10.0.x.x      20.xxx.xxx.xxx   80:xxxxx/TCP   5m
```

### Verificar Deployment

```bash
kubectl get deployment -n dx02

# Output esperado:
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# dx02   2/2     2            2           5m
```

### Health Check

```bash
# Obter IP externo
EXTERNAL_IP=$(kubectl get svc dx02 -n dx02 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Testar endpoint
curl http://$EXTERNAL_IP/health

# Output esperado:
# {"status":"healthy","database":"connected","timestamp":"2025-12-17T..."}
```

### Ver Logs

```bash
# Logs de um pod específico
kubectl logs -n dx02 -l app=dx02 --tail=100

# Logs em tempo real
kubectl logs -n dx02 -l app=dx02 -f
```

### Verificar HPA

```bash
kubectl get hpa -n dx02

# Output esperado:
# NAME   REFERENCE         TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
# dx02   Deployment/dx02   cpu: 15%/70%    2         10        2          5m
```

---

## 🔧 Troubleshooting

### Problema: Pods não sobem (ImagePullBackOff)

**Causa:** Secret do GHCR não configurado ou inválido

**Solução:**
```bash
# Deletar secret antigo
kubectl delete secret ghcr-secret -n dx02

# Criar novo com token válido
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=maringelix \
  --docker-password=[NOVO_GHCR_PAT] \
  --namespace=dx02

# Restart pods
kubectl rollout restart deployment/dx02 -n dx02
```

---

### Problema: Pods em CrashLoopBackOff

**Causa:** Erro de conexão com banco de dados

**Diagnóstico:**
```bash
# Ver logs do pod
kubectl logs -n dx02 -l app=dx02 --tail=50

# Verificar secret
kubectl get secret dx02-db-secret -n dx02 -o yaml
```

**Solução:**
```bash
# Atualizar secret com credenciais corretas
kubectl delete secret dx02-db-secret -n dx02

kubectl create secret generic dx02-db-secret \
  --from-literal=host=tx02-prd-sql.database.windows.net \
  --from-literal=database=tx02-prd-db \
  --from-literal=username=tx02 \
  --from-literal=password=[SENHA_CORRETA] \
  --namespace=dx02

# Restart
kubectl rollout restart deployment/dx02 -n dx02
```

---

### Problema: Service sem EXTERNAL-IP

**Causa:** LoadBalancer ainda provisionando

**Solução:**
```bash
# Aguardar (pode levar 2-5 minutos)
kubectl get svc dx02 -n dx02 -w

# Se após 10 minutos ainda não tiver IP, verificar eventos:
kubectl describe svc dx02 -n dx02

# Verificar quota de Public IPs
az network public-ip list -g MC_tx02-prd-rg_tx02-prd-aks_eastus
```

---

### Problema: Health check falha

**Causa:** Aplicação não responde em /health

**Diagnóstico:**
```bash
# Port-forward para acessar diretamente
kubectl port-forward -n dx02 svc/dx02 8080:80

# Em outro terminal:
curl http://localhost:8080/health
```

**Soluções:**
1. Verificar se aplicação está rodando:
   ```bash
   kubectl exec -n dx02 -it $(kubectl get pod -n dx02 -l app=dx02 -o jsonpath='{.items[0].metadata.name}') -- curl localhost:3000/health
   ```

2. Verificar logs de startup:
   ```bash
   kubectl logs -n dx02 -l app=dx02 --since=5m
   ```

---

### Problema: Erro de conexão SQL no logs

**Erro típico:**
```
Error: Failed to connect to tx02-prd-sql.database.windows.net:1433
```

**Verificações:**

1. **Firewall SQL Server:**
   ```bash
   # Via Portal Azure:
   # SQL Server → Networking → Firewall rules
   # Verificar: "Allow Azure services" = ON
   ```

2. **Private Endpoint:**
   ```bash
   # Verificar se Private Endpoint existe
   az network private-endpoint list -g tx02-prd-rg --query "[?name contains(@, 'sql')]"
   ```

3. **DNS Resolution:**
   ```bash
   # Dentro do pod
   kubectl exec -n dx02 -it $(kubectl get pod -n dx02 -l app=dx02 -o jsonpath='{.items[0].metadata.name}') -- nslookup tx02-prd-sql.database.windows.net
   ```

**Solução:**
- Verificar se SQL Server está em westus2 (free tier)
- Verificar se AKS pode acessar SQL via Private Endpoint
- Verificar credenciais no secret

---

### Problema: HPA não escala

**Causa:** Metrics Server não instalado ou sem dados

**Verificar:**
```bash
# Metrics server
kubectl get deployment metrics-server -n kube-system

# Métricas dos pods
kubectl top pods -n dx02
```

**Solução:**
```bash
# Se metrics server não existir, instalar:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Aguardar ~2 minutos e verificar novamente
```

---

## 📊 Monitoramento

### Dashboard Básico

```bash
# Watch pods
watch kubectl get pods -n dx02

# Recursos
kubectl top pods -n dx02
kubectl top nodes

# HPA status
watch kubectl get hpa -n dx02
```

### Métricas Detalhadas

```bash
# Describe deployment
kubectl describe deployment dx02 -n dx02

# Events do namespace
kubectl get events -n dx02 --sort-by='.lastTimestamp'

# Resource usage
kubectl describe pod -n dx02 -l app=dx02
```

---

## 🎯 Próximos Passos

Após deployment bem-sucedido:

1. **Configurar Domain:**
   - Configurar DNS para apontar para EXTERNAL-IP
   - Atualizar Ingress com domínio

2. **HTTPS/TLS:**
   - Instalar cert-manager
   - Configurar Let's Encrypt
   - Atualizar Ingress com TLS

3. **Monitoring Avançado:**
   - Prometheus + Grafana
   - Application Insights
   - Log aggregation

4. **CI/CD Automático:**
   - Deploy automático em cada push para main
   - Rollback automático em caso de falha
   - Blue-Green deployments

---

## � Azure Container Registry (ACR)

### Benefícios do ACR vs GHCR

| Característica | ACR (Azure) | GHCR (GitHub) |
|----------------|-------------|---------------|
| **Integração AKS** | ✅ Nativa (AcrPull role) | ❌ Requer imagePullSecrets |
| **Latência** | ✅ Baixa (mesma região) | ❌ Alta (fora Azure) |
| **Rate Limits** | ✅ Sem limites | ❌ 1000 pulls/hour |
| **Transfer Cost** | ✅ Grátis (mesma região) | ❌ Pago (ingress) |
| **Free Tier** | ✅ Basic SKU (50GB) | ✅ Ilimitado |

### Credenciais do ACR

```bash
# Obter informações do ACR via Terraform outputs
cd tx02/terraform/prd

# Login server (para workflows)
terraform output -raw acr_login_server
# Saída: tx02prdacr.azurecr.io

# Admin username (para GitHub Secrets)
terraform output -raw acr_admin_username

# Admin password (para GitHub Secrets)
terraform output -raw acr_admin_password

# ACR name (para comandos Azure CLI)
terraform output -raw acr_name
# Saída: tx02prdacr
```

### Login Manual no ACR

```bash
# Via Azure CLI (recomendado)
az acr login --name tx02prdacr

# Via Docker (usando admin credentials)
docker login tx02prdacr.azurecr.io
# Username: [obter via terraform output]
# Password: [obter via terraform output]
```

### Integração AKS ↔ ACR

O AKS já está **automaticamente autenticado** no ACR via:
- **AcrPull role assignment** criado pelo Terraform
- **Kubelet identity** do AKS tem permissão de pull
- **Sem necessidade de imagePullSecrets** nos deployments

Verificar integração:
```bash
# Listar role assignments do ACR
az role assignment list --scope $(az acr show -n tx02prdacr --query id -o tsv)

# Deve mostrar role "AcrPull" para o kubelet identity do AKS
```

---

## 📚 Referências

### Repositórios
- [DX02 Application](https://github.com/maringelix/dx02)
- [TX02 Infrastructure](https://github.com/maringelix/tx02)

### Documentação TX02
- [README.md](README.md) - Overview do projeto
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Guia de deployment da infra
- [AZURE_FREE_TRIAL_LESSONS_LEARNED.md](AZURE_FREE_TRIAL_LESSONS_LEARNED.md) - Lições aprendidas

### Azure Docs
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/)
- [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
- [Authenticate with ACR from AKS](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration)

---

**Última atualização:** Dezembro 17, 2025  
**Status:** ✅ Deployment Ready  
**Maintainer:** GitHub Copilot
