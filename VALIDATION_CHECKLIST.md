# ✅ TX02 - Checklist de Validação e Deploy

**Data:** 6 de Janeiro de 2026  
**Objetivo:** Validar pré-requisitos e executar deploy da infraestrutura TX02 via CI/CD

---

## 📋 Visão Geral

Este documento valida **TODOS** os pré-requisitos necessários para subir a infraestrutura TX02 no Azure seguindo **melhores práticas DevOps/SRE**:

✅ **Validação local** - Apenas para verificar ambiente  
✅ **Deploy via CI/CD** - Toda infraestrutura via GitHub Actions + Terraform  
❌ **NUNCA executar terraform local** - Apenas via pipeline  
❌ **NUNCA criar recursos via az cli** - Apenas via Terraform

---

## 🎯 Arquitetura a Ser Provisionada

### Recursos Azure (via Terraform)
```
📦 Resource Group: tx02-prd-rg
├── 🌐 VNet: 10.1.0.0/16
│   ├── Subnet AKS: 10.1.1.0/24
│   ├── Subnet Database: 10.1.2.0/24
│   ├── Subnet VM: 10.1.3.0/24
│   └── Subnet AppGW: 10.1.4.0/24
│
├── ☸️ AKS Cluster (tx02-prd-aks)
│   ├── Kubernetes: v1.32
│   ├── Node Count: 3 (min: 2, max: 10)
│   ├── Node Size: Standard_B2s (Free Tier)
│   └── Auto-scaling: Enabled
│
├── 🗄️ Azure Database for PostgreSQL
│   ├── SKU: B_Standard_B1ms (Free Tier)
│   ├── Version: 17
│   ├── Storage: 32GB
│   └── Admin: dbadmin
│
├── 📦 Azure Container Registry (ACR)
│   ├── Name: tx02prdacr
│   ├── SKU: Basic (Free Tier)
│   └── AKS Integration: Enabled
│
├── 🔒 Network Security Groups (NSGs)
│   ├── AKS NSG
│   ├── Database NSG
│   └── VM NSG
│
└── 🔐 Private Endpoints
    └── Database Private Endpoint
```

### Custo Estimado
- **AKS**: $0/mês (Free Tier - 1 cluster grátis)
- **Database**: $0/mês (Free Tier B1ms)
- **Networking**: ~$5-10/mês
- **ACR**: $0/mês (Free Tier - 1 registry)
- **Total**: ~$5-10/mês (otimizado para Free Tier)

---

## 🔍 Fase 1: Validação Local do Ambiente

### ✅ 1.1. Azure CLI Instalado

```bash
# Verificar instalação
az --version

# Resultado esperado:
# azure-cli: 2.x.x ou superior
```

**Status:** ⏳ Pendente validação

---

### ✅ 1.2. Azure CLI Login (para validação apenas)

```bash
# Login interativo
az login

# Verificar conta logada
az account show --output table

# Verificar subscription
az account list --output table
```

**Status:** ⏳ Pendente validação  
**Nota:** Login local é APENAS para validação. Deploy será via Service Principal no CI/CD.

---

### ✅ 1.3. Verificar Subscription Ativa

```bash
# Mostrar subscription atual
az account show --query "{Name:name, ID:id, State:state}" --output table

# Setar subscription correta (se necessário)
az account set --subscription "SUBSCRIPTION_ID"
```

**Valores esperados:**
- State: `Enabled`
- Type: `Azure subscription 1` ou similar

**Status:** ⏳ Pendente validação

---

### ✅ 1.4. Verificar Resource Providers Registrados

```bash
# Verificar providers necessários
az provider show -n Microsoft.ContainerService --query "registrationState"
az provider show -n Microsoft.Network --query "registrationState"
az provider show -n Microsoft.Compute --query "registrationState"
az provider show -n Microsoft.Storage --query "registrationState"
az provider show -n Microsoft.DBforPostgreSQL --query "registrationState"
az provider show -n Microsoft.OperationalInsights --query "registrationState"
az provider show -n Microsoft.ContainerRegistry --query "registrationState"
```

**Resultado esperado:** `"Registered"` para todos

**Se não registrado (NÃO fazer agora, será feito pelo CI/CD):**
```bash
# O workflow bootstrap.yml fará isso automaticamente
# NUNCA executar manualmente: az provider register --namespace ...
```

**Status:** ⏳ Pendente validação

---

### ✅ 1.5. Verificar Quotas Disponíveis

```bash
# Verificar quota de vCPUs na região
az vm list-usage --location "eastus" --output table | grep -E "Total Regional vCPUs|Standard B Family vCPUs"

# Verificar quota de AKS
az aks list --output table
```

**Requisitos mínimos:**
- Regional vCPUs: 6+ disponíveis (3 nodes × 2 vCPUs)
- Standard B Family vCPUs: 6+ disponíveis

**Status:** ⏳ Pendente validação

---

### ✅ 1.6. Git e GitHub CLI

```bash
# Verificar Git
git --version

# Verificar GitHub CLI (opcional)
gh --version

# Verificar repositório remoto
cd /home/tx02/Documents/Projects/tx02
git remote -v
```

**Resultado esperado:**
- Git version 2.x ou superior
- Remote: `origin	https://github.com/maringelix/tx02.git`

**Status:** ⏳ Pendente validação

---

## 🔐 Fase 2: Configuração de Secrets no GitHub

### ✅ 2.1. Criar Service Principal

**⚠️ EXECUTAR APENAS UMA VEZ**

```bash
# Login no Azure
az login

# Obter Subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Criar Service Principal
az ad sp create-for-rbac \
  --name "github-actions-tx02" \
  --role="Contributor" \
  --scopes="/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth
```

**Salvar output JSON completo:**
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

**Status:** ⏳ Pendente criação

---

### ✅ 2.2. Configurar GitHub Secrets

Acessar: `https://github.com/maringelix/tx02/settings/secrets/actions`

#### Secrets Obrigatórios

| Secret Name | Descrição | Onde Obter | Status |
|------------|-----------|------------|--------|
| `AZURE_CREDENTIALS` | JSON completo do Service Principal | Output do comando acima | ⏳ |
| `AZURE_SUBSCRIPTION_ID` | ID da subscription | `az account show --query id -o tsv` | ⏳ |
| `AZURE_TENANT_ID` | Tenant ID | `az account show --query tenantId -o tsv` | ⏳ |
| `AZURE_CLIENT_ID` | Client ID do SP | Campo `clientId` do JSON | ⏳ |
| `AZURE_CLIENT_SECRET` | Secret do SP | Campo `clientSecret` do JSON | ⏳ |
| `TF_VAR_db_password` | Senha PostgreSQL | Gerar senha forte (min 8 chars) | ⏳ |
| `TF_VAR_admin_password` | Senha admin VM | Gerar senha forte (min 12 chars) | ⏳ |

#### Exemplo de Senhas Fortes

```bash
# Gerar senha para PostgreSQL (min 8 chars, letras maiúsculas, minúsculas e números)
# Exemplo: Tx02Pass2026!

# Gerar senha para VM (min 12 chars, complexidade alta)
# Exemplo: Tx02VmAdmin2026!@
```

**Validação de Secrets:**
```bash
# Via GitHub CLI (se disponível)
gh secret list --repo maringelix/tx02
```

**Status:** ⏳ Pendente configuração

---

### ✅ 2.3. Validar Permissões do Service Principal

```bash
# Listar role assignments do SP
az role assignment list \
  --assignee "CLIENT_ID_DO_SP" \
  --output table

# Resultado esperado:
# Principal: github-actions-tx02
# Role: Contributor
# Scope: /subscriptions/SUBSCRIPTION_ID
```

**Status:** ⏳ Pendente validação

---

## 🚀 Fase 3: Execução do Bootstrap (CI/CD)

### ✅ 3.1. Executar Workflow de Bootstrap

**O que faz:**
- Cria Resource Group: `terraform-state-rg`
- Cria Storage Account: `tfstatetx02`
- Configura backend do Terraform
- Ativa versioning no Storage

**Passos:**

1. Acessar: https://github.com/maringelix/tx02/actions
2. Selecionar: **"🚀 Setup Terraform Backend"**
3. Clicar: **"Run workflow"**
4. Configurar:
   - **Action:** `apply`
   - **Confirm:** `bootstrap`
5. Clicar: **"Run workflow"** (botão verde)

**Validação:**
- ✅ Workflow completa com sucesso (verde)
- ✅ Storage Account criado
- ✅ Container `tfstate` criado

**Tempo estimado:** 2-3 minutos

**Status:** ⏳ Pendente execução

---

### ✅ 3.2. Verificar Backend Criado (local)

```bash
# Verificar Resource Group
az group show --name terraform-state-rg --output table

# Verificar Storage Account
az storage account show \
  --name tfstatetx02 \
  --resource-group terraform-state-rg \
  --output table

# Verificar Container
az storage container show \
  --name tfstate \
  --account-name tfstatetx02 \
  --output table
```

**Status:** ⏳ Pendente validação

---

## 🏗️ Fase 4: Deploy da Infraestrutura (CI/CD)

### ✅ 4.1. Executar Terraform Plan (Opcional)

**Visualizar o que será criado antes de aplicar:**

1. Acessar: https://github.com/maringelix/tx02/actions
2. Selecionar: **"Terraform Plan"**
3. Clicar: **"Run workflow"**
4. Configurar:
   - **Environment:** `prd`
5. Clicar: **"Run workflow"**

**Validação:**
- ✅ Plan executado com sucesso
- ✅ Revisar lista de recursos a serem criados

**Status:** ⏳ Pendente execução

---

### ✅ 4.2. Executar Terraform Apply

**⚠️ ATENÇÃO: Isso criará recursos reais no Azure**

1. Acessar: https://github.com/maringelix/tx02/actions
2. Selecionar: **"🚀 Terraform Apply"**
3. Clicar: **"Run workflow"**
4. Configurar:
   - **Environment:** `prd`
5. Clicar: **"Run workflow"**

**O que será criado:**
- ✅ Resource Group (tx02-prd-rg)
- ✅ Virtual Network + Subnets
- ✅ AKS Cluster (3 nodes)
- ✅ Azure Database for PostgreSQL
- ✅ Azure Container Registry
- ✅ Network Security Groups
- ✅ Private Endpoints

**Tempo estimado:** 15-20 minutos

**Status:** ⏳ Pendente execução

---

### ✅ 4.3. Monitorar Execução

```bash
# Via GitHub CLI
gh run list --repo maringelix/tx02 --workflow "Terraform Apply"

# Ver logs em tempo real
gh run watch
```

**Ou via browser:**
https://github.com/maringelix/tx02/actions

**Status:** ⏳ Pendente monitoramento

---

## 🔍 Fase 5: Validação Pós-Deploy

### ✅ 5.1. Verificar Resource Group Criado

```bash
# Listar resource groups
az group list --output table | grep tx02

# Ver detalhes do RG
az group show --name tx02-prd-rg --output json | jq '{name, location, properties}'
```

**Resultado esperado:**
- Name: `tx02-prd-rg`
- Location: `eastus`
- ProvisioningState: `Succeeded`

**Status:** ⏳ Pendente validação

---

### ✅ 5.2. Verificar AKS Cluster

```bash
# Listar clusters
az aks list --output table

# Ver detalhes do cluster
az aks show \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks \
  --output json | jq '{name, kubernetesVersion, nodeResourceGroup, provisioningState}'

# Obter credenciais (para kubectl local)
az aks get-credentials \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks \
  --overwrite-existing

# Verificar nodes
kubectl get nodes
```

**Resultado esperado:**
- 3 nodes em estado `Ready`
- Kubernetes version: `1.32.x`

**Status:** ⏳ Pendente validação

---

### ✅ 5.3. Verificar Azure Database

```bash
# Listar databases
az postgres flexible-server list --output table

# Ver detalhes
az postgres flexible-server show \
  --resource-group tx02-prd-rg \
  --name tx02-prd-db \
  --output json | jq '{name, version, state, sku}'
```

**Resultado esperado:**
- State: `Ready`
- Version: `17`
- SKU: `B_Standard_B1ms`

**Status:** ⏳ Pendente validação

---

### ✅ 5.4. Verificar ACR

```bash
# Listar registries
az acr list --output table

# Ver detalhes
az acr show \
  --name tx02prdacr \
  --resource-group tx02-prd-rg \
  --output json | jq '{name, loginServer, sku}'
```

**Resultado esperado:**
- SKU: `Basic`
- Login Server: `tx02prdacr.azurecr.io`

**Status:** ⏳ Pendente validação

---

### ✅ 5.5. Verificar Networking

```bash
# Listar VNets
az network vnet list --resource-group tx02-prd-rg --output table

# Ver subnets
az network vnet subnet list \
  --resource-group tx02-prd-rg \
  --vnet-name tx02-prd-vnet \
  --output table
```

**Resultado esperado:**
- VNet: `tx02-prd-vnet` (10.1.0.0/16)
- 4 subnets: AKS, Database, VM, AppGW

**Status:** ⏳ Pendente validação

---

### ✅ 5.6. Verificar NSGs

```bash
# Listar NSGs
az network nsg list \
  --resource-group tx02-prd-rg \
  --output table
```

**Resultado esperado:**
- `tx02-prd-aks-nsg`
- `tx02-prd-database-nsg`
- `tx02-prd-vm-nsg`

**Status:** ⏳ Pendente validação

---

## 📊 Fase 6: Deploy da Aplicação DX02

### ✅ 6.1. Configurar Secrets do DX02

Acessar: `https://github.com/maringelix/dx02/settings/secrets/actions`

| Secret Name | Valor | Como Obter |
|------------|-------|------------|
| `AZURE_CREDENTIALS` | Mesmo JSON do TX02 | Reutilizar |
| `DB_HOST` | Hostname do PostgreSQL | `az postgres flexible-server show --resource-group tx02-prd-rg --name tx02-prd-db --query "fullyQualifiedDomainName" -o tsv` |
| `DB_NAME` | `dx02db` | Fixo |
| `DB_USER` | `dbadmin` | Configurado no Terraform |
| `DB_PASSWORD` | Mesma senha do `TF_VAR_db_password` | Reutilizar |

**Status:** ⏳ Pendente configuração

---

### ✅ 6.2. Deploy da Aplicação via CI/CD

1. Acessar: https://github.com/maringelix/dx02/actions
2. Selecionar workflow de deploy (ex: "Deploy to AKS")
3. Executar workflow

**Status:** ⏳ Pendente execução

---

## 📝 Checklist Final

### Pré-requisitos
- [ ] Azure CLI instalado e funcionando
- [ ] Azure Login realizado (validação local)
- [ ] Subscription verificada e ativa
- [ ] Resource Providers registrados
- [ ] Quotas verificadas
- [ ] Git configurado

### GitHub Secrets
- [ ] Service Principal criado
- [ ] `AZURE_CREDENTIALS` configurado
- [ ] `AZURE_SUBSCRIPTION_ID` configurado
- [ ] `AZURE_TENANT_ID` configurado
- [ ] `AZURE_CLIENT_ID` configurado
- [ ] `AZURE_CLIENT_SECRET` configurado
- [ ] `TF_VAR_db_password` configurado
- [ ] `TF_VAR_admin_password` configurado

### Bootstrap
- [ ] Workflow de Bootstrap executado
- [ ] Storage Account criado
- [ ] Backend Terraform configurado

### Infraestrutura
- [ ] Terraform Plan revisado
- [ ] Terraform Apply executado
- [ ] Resource Group criado
- [ ] AKS cluster provisionado
- [ ] Database provisionado
- [ ] ACR criado
- [ ] Networking configurado

### Validação
- [ ] AKS nodes online (3/3)
- [ ] Database acessível
- [ ] ACR funcional
- [ ] kubectl configurado localmente

### Aplicação
- [ ] DX02 secrets configurados
- [ ] DX02 deploy executado
- [ ] Aplicação acessível

---

## 🚨 Troubleshooting

### Erro: "Service Principal not found"
```bash
# Recriar Service Principal
az ad sp create-for-rbac \
  --name "github-actions-tx02-new" \
  --role="Contributor" \
  --scopes="/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth
```

### Erro: "Provider not registered"
```bash
# Será resolvido automaticamente pelo workflow bootstrap.yml
# Não executar manualmente
```

### Erro: "Quota exceeded"
```bash
# Verificar quotas
az vm list-usage --location "eastus" --output table

# Solicitar aumento via portal:
# https://portal.azure.com → Support → New support request
```

### Erro: "Storage Account already exists"
```bash
# Verificar se backend já foi criado
az storage account show --name tfstatetx02 --resource-group terraform-state-rg

# Se sim, prosseguir com terraform apply
```

---

## 📚 Documentação Complementar

- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Guia completo de deployment
- [BOOTSTRAP_GUIDE.md](./BOOTSTRAP_GUIDE.md) - Detalhes do bootstrap
- [GITHUB_SECRETS.md](./GITHUB_SECRETS.md) - Configuração de secrets
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Referência rápida de comandos

---

## ✅ Conclusão

Após completar todas as fases deste checklist:

✅ Infraestrutura TX02 100% provisionada via CI/CD  
✅ Seguindo melhores práticas DevOps/SRE  
✅ Zero execuções de terraform local  
✅ Zero criação manual de recursos  
✅ Tudo versionado e rastreável no GitHub  
✅ Infraestrutura reprodutível e escalável

**Próximos passos:**
1. Deploy da aplicação DX02
2. Configurar observabilidade (Prometheus/Grafana)
3. Configurar service mesh (Istio)
4. Implementar CI/CD para aplicação
5. Configurar WAF e segurança avançada
