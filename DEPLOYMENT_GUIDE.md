# 🚀 Guia Completo de Deployment - TX02

Este guia detalha o processo completo de deployment da infraestrutura TX02 na Azure.

---

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Configuração do GitHub](#configuração-do-github)
3. [Criação Manual do SQL Server](#criação-manual-do-sql-server)
4. [Execução do Terraform](#execução-do-terraform)
5. [Validação](#validação)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 Pré-requisitos

### Azure

- ✅ Conta Azure (Free Trial ou Pay-as-you-go)
- ✅ Subscription ativa
- ✅ Service Principal criado com permissões adequadas
- ✅ Providers registrados:
  - Microsoft.Network
  - Microsoft.Compute
  - Microsoft.Storage
  - Microsoft.ContainerService
  - Microsoft.OperationalInsights
  - Microsoft.Sql

### GitHub

- ✅ Repositório criado
- ✅ Código do TX02 no repositório

---

## 🔐 Configuração do GitHub

### 1. GitHub Secrets Necessários

Acesse: `https://github.com/[seu-usuario]/[repo]/settings/secrets/actions`

Crie os seguintes secrets:

| Secret Name | Descrição | Onde Obter |
|-------------|-----------|------------|
| `AZURE_SUBSCRIPTION_ID` | ID da subscription Azure | Portal Azure → Subscriptions |
| `AZURE_TENANT_ID` | ID do tenant Azure AD | Portal Azure → Azure Active Directory |
| `AZURE_CLIENT_ID` | ID do Service Principal | Criado via `az ad sp create-for-rbac` |
| `AZURE_CLIENT_SECRET` | Secret do Service Principal | Retornado ao criar o SP |
| `AZURE_STORAGE_ACCESS_KEY` | Access key do Storage Account | Portal Azure → Storage Account → Access keys |
| `AZURE_SQL_PASSWORD` | Senha do admin SQL | Senha que você criou manualmente |
| `TF_VAR_admin_password` | Senha admin da VM | Criar uma senha forte |

### 2. Criar Service Principal

```bash
az login

az ad sp create-for-rbac \
  --name "sp-tx02-terraform" \
  --role="Contributor" \
  --scopes="/subscriptions/[SUBSCRIPTION_ID]"
```

Isso retornará:
```json
{
  "appId": "...",        # → AZURE_CLIENT_ID
  "displayName": "sp-tx02-terraform",
  "password": "...",     # → AZURE_CLIENT_SECRET
  "tenant": "..."        # → AZURE_TENANT_ID
}
```

---

## 🗄️ Criação Manual do SQL Server

**⚠️ IMPORTANTE:** Devido às limitações do Azure Free Trial, o SQL Database deve ser criado manualmente via Portal Azure. O free tier requer clicar no botão "Apply offer" que não pode ser automatizado.

### Passo 1: Acessar Portal Azure

1. Acesse: https://portal.azure.com
2. Pesquise por **"SQL servers"**
3. Clique em **"+ Create"**

### Passo 2: Basics

Preencha os campos:

| Campo | Valor |
|-------|-------|
| **Subscription** | tx02 (ou sua subscription) |
| **Resource group** | tx02-prd-rg |
| **Server name** | `tx02-prd-sql` |
| **Location** | **(US) West US 2** (ou mesma do AKS) |

**⚠️ ATENÇÃO:** A região deve ser a mesma do seu AKS cluster (configurado no Terraform).

### Passo 3: Authentication

Selecione: **"Use both SQL and Microsoft Entra authentication"**

Configure:

| Campo | Valor |
|-------|-------|
| **Authentication method** | Use both SQL and Microsoft Entra authentication |
| **Set Microsoft Entra admin** | [Seu email Microsoft/Azure AD] |
| **Server admin login** | `tx02` |
| **Password** | [Senha forte - 12+ caracteres] |
| **Confirm password** | [Mesma senha] |

**💾 SALVE ESTA SENHA!** Você precisará adicionar como secret `AZURE_SQL_PASSWORD` no GitHub.

### Passo 4: Networking

Configure:

| Campo | Valor |
|-------|-------|
| **Firewall rules** | |
| **Allow Azure services and resources to access this server** | ✅ **Yes** |
| **Add current client IP address** | ❌ No (opcional para testes) |

> **Nota:** O Private Endpoint será criado automaticamente pelo Terraform.

### Passo 5: Security

Mantenha padrões:

| Campo | Valor |
|-------|-------|
| **Identity** | Not enabled |
| **Transparent data encryption** | Service-managed key selected |

### Passo 6: Tags

Adicione as tags:

| Name | Value |
|------|-------|
| Environment | production |
| Project | tx02 |
| ManagedBy | terraform |

### Passo 7: Review + Create

1. Revise todas as configurações
2. Clique em **"Create"**
3. Aguarde ~2-3 minutos para criação

---

## 📦 Criar Database

Após o SQL Server ser criado:

### 1. Acessar SQL Server

1. Portal Azure → **SQL servers**
2. Clique em **tx02-prd-sql**

### 2. Create Database

1. Clique em **"+ Create database"**
2. Preencha:

| Campo | Valor |
|-------|-------|
| **Database name** | `tx02-prd-db` |
| **Want to use elastic pool?** | No |

### 3. Compute + Storage

1. Clique em **"Configure database"**
2. Selecione **"Basic"**
3. Configure:
   - **DTUs:** 5
   - **Max data size:** 2 GB
4. **⚠️ IMPORTANTE:** Procure pelo banner **"Apply offer"** e clique nele
   - Isso ativa o free tier (100,000 vCore seconds/month)
5. Clique **"Apply"**

### 4. Backup Storage Redundancy

Selecione: **Locally-redundant backup storage**

### 5. Tags

Herda automaticamente as tags do server.

### 6. Review + Create

1. Revise configurações
2. Clique **"Create"**
3. Aguarde ~1-2 minutos

---

## 🔑 Adicionar Senha SQL no GitHub

Após criar o SQL Server:

1. Acesse: `https://github.com/[seu-usuario]/[repo]/settings/secrets/actions`
2. Clique em **"New repository secret"**
3. Preencha:
   - **Name:** `AZURE_SQL_PASSWORD`
   - **Value:** [A senha que você criou no SQL Server]
4. Clique **"Add secret"**

---

## ▶️ Execução do Terraform

### Método 1: GitHub Actions (Recomendado)

1. **Acesse Actions no GitHub:**
   - `https://github.com/[seu-usuario]/[repo]/actions`

2. **Execute Bootstrap (primeira vez apenas):**
   - Selecione workflow: **"Bootstrap - Setup Terraform Backend"**
   - Clique **"Run workflow"**
   - Aguarde ~2-3 minutos
   - Isso cria Storage Account para Terraform state

3. **Execute Terraform Apply:**
   - Selecione workflow: **"🚀 Terraform Apply"**
   - Clique **"Run workflow"**
   - Environment: `prd`
   - Clique **"Run workflow"**
   - Aguarde ~8-12 minutos

4. **Acompanhe logs:**
   - Clique na execução do workflow
   - Veja os steps sendo executados
   - Verifique o step **"Import Existing SQL Resources"**
     - Deve importar SQL Server e Database criados manualmente
   - Verifique o step **"Terraform Apply"**
     - Deve criar AKS, VNet, NSGs, etc.
     - SQL Server/Database devem aparecer como "imported" ou "no changes"

### Método 2: Local (Desenvolvimento)

```bash
# 1. Clone repositório
git clone https://github.com/[seu-usuario]/[repo].git
cd [repo]/terraform/prd

# 2. Login Azure
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# 3. Set subscription
az account set --subscription $AZURE_SUBSCRIPTION_ID

# 4. Init Terraform
terraform init

# 5. Import SQL Server (se criado manualmente)
terraform import module.database.azurerm_mssql_server.main \
  /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tx02-prd-rg/providers/Microsoft.Sql/servers/tx02-prd-sql

# 6. Import SQL Database
terraform import module.database.azurerm_mssql_database.main \
  /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tx02-prd-rg/providers/Microsoft.Sql/servers/tx02-prd-sql/databases/tx02-prd-db

# 7. Plan
export TF_VAR_db_password="[SUA_SENHA_SQL]"
export TF_VAR_vm_admin_password="[SENHA_VM]"

terraform plan

# 8. Apply
terraform apply
```

---

## ✅ Validação

### 1. Verificar Resources no Portal Azure

Acesse Portal Azure → **Resource Groups** → **tx02-prd-rg**

Recursos esperados:
- ✅ **tx02-prd-vnet** - Virtual Network
- ✅ **tx02-prd-aks** - Kubernetes Service
- ✅ **tx02-prd-sql** - SQL Server
- ✅ **tx02-prd-db** - SQL Database (dentro do server)
- ✅ **tx02-prd-logs** - Log Analytics Workspace
- ✅ **nsg-aks-subnet** - Network Security Group (AKS)
- ✅ **nsg-database-subnet** - Network Security Group (Database)
- ✅ **nsg-vm-subnet** - Network Security Group (VM)
- ✅ **privatelink.database.windows.net** - Private DNS Zone

### 2. Testar Conexão AKS

```bash
# Get credentials
az aks get-credentials \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks

# Test connection
kubectl get nodes

# Expected output:
# NAME                                STATUS   ROLES   AGE   VERSION
# aks-default-12345678-vmss000000    Ready    agent   10m   v1.32.x
# aks-default-12345678-vmss000001    Ready    agent   10m   v1.32.x
```

### 3. Testar Conexão SQL Database

**Via Azure Portal:**
1. Portal Azure → SQL databases → tx02-prd-db
2. Clique em **"Query editor (preview)"**
3. Login com admin: `tx02` e sua senha
4. Execute query de teste:
```sql
SELECT @@VERSION;
SELECT DB_NAME();
```

**Via sqlcmd (local):**
```bash
sqlcmd -S tx02-prd-sql.database.windows.net -d tx02-prd-db -U tx02 -P [senha] -N -C

1> SELECT DB_NAME();
2> GO
```

### 4. Verificar Terraform State

```bash
cd terraform/prd

# List resources
terraform state list

# Should include:
# module.database.azurerm_mssql_server.main
# module.database.azurerm_mssql_database.main
# module.aks.azurerm_kubernetes_cluster.main
# module.networking.azurerm_virtual_network.main
# ...
```

---

## 🔧 Troubleshooting

### SQL Server já existe - erro de duplicação

**Erro:**
```
Error: A resource with the ID "/subscriptions/.../tx02-prd-sql" already exists
```

**Solução:**
O workflow GitHub Actions já faz import automaticamente. Se executar local:
```bash
terraform import module.database.azurerm_mssql_server.main \
  /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tx02-prd-rg/providers/Microsoft.Sql/servers/tx02-prd-sql
```

### SQL Database - ProvisioningDisabled

**Erro:**
```
Code="ProvisioningDisabled"
Message="Provisioning is restricted in this region"
```

**Causa:** Free tier não ativado corretamente.

**Solução:**
1. Delete o database via portal
2. Recrie clicando no botão **"Apply offer"**
3. Aguarde criação completa
4. Execute workflow novamente (fará import automaticamente)

### AKS nodes não ficam Ready

**Verificar:**
```bash
kubectl get nodes
kubectl describe node [node-name]
```

**Comum em Free Trial:** Limitações de quota.

**Solução:**
1. Portal Azure → Subscriptions → Usage + quotas
2. Verifique se tem quota para **Standard DCsv3-series** em East US
3. Se não, request quota increase

### Terraform state lock

**Erro:**
```
Error: Error acquiring the state lock
```

**Solução:**
```bash
# List locks
az storage blob lease list \
  --account-name [storage-account] \
  --container-name tfstate

# Break lease
az storage blob lease break \
  --blob-name prd.tfstate \
  --container-name tfstate \
  --account-name [storage-account]
```

### Import falha - recurso não existe

**Erro:**
```
Error: Cannot import non-existent remote object
```

**Causa:** SQL Server/Database ainda não foi criado manualmente.

**Solução:**
1. Crie SQL Server conforme seção [Criação Manual do SQL Server](#criação-manual-do-sql-server)
2. Execute workflow novamente

---

## 📊 Monitoramento

### Logs do AKS

```bash
# Get cluster logs
az aks show \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks \
  --query "agentPoolProfiles[0].provisioningState"

# Check pod logs (após deploy)
kubectl logs -n default [pod-name]
```

### SQL Database Metrics

Portal Azure → SQL databases → tx02-prd-db → **Metrics**

Métricas importantes:
- DTU percentage
- Storage percentage
- Connections
- Deadlocks

### Log Analytics

Portal Azure → Log Analytics workspaces → tx02-prd-logs → **Logs**

Query exemplo:
```kusto
AzureDiagnostics
| where ResourceType == "SERVERS/DATABASES"
| where TimeGenerated > ago(1h)
| summarize count() by bin(TimeGenerated, 5m)
```

---

## 🎉 Conclusão

Após seguir este guia, você terá:

✅ SQL Server e Database criados manualmente com free tier  
✅ GitHub Secrets configurados  
✅ Terraform importando e gerenciando SQL automaticamente  
✅ AKS cluster funcionando  
✅ Rede completa (VNet, Subnets, NSGs)  
✅ Private DNS configurado  
✅ CI/CD funcionando via GitHub Actions  

**Próximos passos:**
- Deploy da aplicação DX02 no AKS
- Configurar ingress/load balancer
- Configurar monitoring avançado

---

## 📚 Referências

- [Azure SQL Database Documentation](https://docs.microsoft.com/en-us/azure/azure-sql/)
- [Azure Free Services](https://azure.microsoft.com/en-us/free/free-account-faq/)
- [Terraform azurerm Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Documentação criada em:** Dezembro 2025  
**Projeto:** TX02 - Azure Infrastructure with Terraform  
**Maintainer:** GitHub Copilot
