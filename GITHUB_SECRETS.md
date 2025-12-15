# GitHub Secrets Configuration - TX02 & DX02

Este documento descreve todos os secrets necessários para CI/CD na Azure.

---

## 🔐 Secrets Obrigatórios

Configure estes secrets em: **Settings → Secrets and variables → Actions**

### TX02 (Infraestrutura)

| Secret Name | Descrição | Como Obter |
|------------|-----------|------------|
| `AZURE_CREDENTIALS` | Service Principal JSON | Ver seção abaixo |
| `AZURE_SUBSCRIPTION_ID` | ID da Subscription Azure | `az account show --query id -o tsv` |
| `AZURE_TENANT_ID` | ID do Tenant Azure | `az account show --query tenantId -o tsv` |
| `AZURE_CLIENT_ID` | Client ID do Service Principal | Criar Service Principal |
| `AZURE_CLIENT_SECRET` | Client Secret do Service Principal | Criar Service Principal |
| `TF_VAR_db_password` | Senha do PostgreSQL | Escolha uma senha forte |
| `TF_VAR_admin_password` | Senha admin da VM | Escolha uma senha forte |

### DX02 (Aplicação)

| Secret Name | Descrição | Valor |
|------------|-----------|-------|
| `AZURE_CREDENTIALS` | Service Principal JSON | Mesmo do TX02 |
| `DB_HOST` | Hostname do Database | Output do Terraform TX02 |
| `DB_NAME` | Nome do Database | `dx02db` |
| `DB_USER` | Username do Database | `dbadmin` (ou configurado) |
| `DB_PASSWORD` | Senha do Database | Mesmo que `TF_VAR_db_password` |

---

## 📋 Passo a Passo: Criando Service Principal

### 1. Login no Azure
```bash
az login
```

### 2. Definir Subscription
```bash
# Listar subscriptions
az account list --output table

# Definir a subscription ativa
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 3. Criar Service Principal
```bash
az ad sp create-for-rbac \
  --name "github-actions-tx02" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --sdk-auth
```

**Output (exemplo):**
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

⚠️ **IMPORTANTE:** Copie todo esse JSON! Você precisará dele.

---

## ⚙️ Configurando Secrets no GitHub

### TX02 Repository

1. Acesse: `https://github.com/SEU_USUARIO/tx02/settings/secrets/actions`
2. Clique em **New repository secret**
3. Adicione cada secret:

```bash
# AZURE_CREDENTIALS
# Cole o JSON completo do Service Principal

# AZURE_SUBSCRIPTION_ID
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# AZURE_TENANT_ID
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# AZURE_CLIENT_ID
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# AZURE_CLIENT_SECRET
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# TF_VAR_db_password
SuaSenhaForteDoDB123!

# TF_VAR_admin_password
SuaSenhaForteDaVM123!
```

### DX02 Repository

1. Acesse: `https://github.com/SEU_USUARIO/dx02/settings/secrets/actions`
2. Adicione:

```bash
# AZURE_CREDENTIALS
# Mesmo JSON do TX02

# DB_HOST (obtido após terraform apply no TX02)
tx02-prd-db.postgres.database.azure.com

# DB_NAME
dx02db

# DB_USER
dbadmin

# DB_PASSWORD
# Mesma senha do TF_VAR_db_password
SuaSenhaForteDoDB123!
```

---

## 🔄 Como Obter DB_HOST após Terraform Apply

Após aplicar o Terraform no TX02:

```bash
cd terraform/prd
terraform output db_host
```

Ou via Azure CLI:
```bash
az postgres flexible-server list \
  --resource-group tx02-prd-rg \
  --query "[].fullyQualifiedDomainName" \
  --output tsv
```

---

## 🧪 Testando os Secrets

### TX02 (Infraestrutura)
```bash
# Criar um PR para testar terraform plan
git checkout -b test-secrets
git commit --allow-empty -m "Test secrets"
git push origin test-secrets
# Criar PR e verificar se terraform plan executa
```

### DX02 (Aplicação)
```bash
# Fazer push para main para testar build
git commit --allow-empty -m "Test build"
git push origin main
# Verificar GitHub Actions
```

---

## 🔒 Segurança

### ✅ Best Practices

1. **Nunca** commite secrets no código
2. **Sempre** use GitHub Secrets para valores sensíveis
3. **Rotacione** o Service Principal periodicamente:
```bash
# Criar novo secret
az ad sp credential reset --id YOUR_CLIENT_ID
```

4. **Limite** permissões do Service Principal:
```bash
# Dar apenas permissões específicas
az role assignment create \
  --assignee YOUR_CLIENT_ID \
  --role "Contributor" \
  --scope "/subscriptions/SUB_ID/resourceGroups/tx02-prd-rg"
```

5. **Use** diferentes Service Principals para diferentes ambientes

### 🚫 O que NÃO fazer

- ❌ Commitar `.env` com valores reais
- ❌ Compartilhar Service Principal publicamente
- ❌ Usar mesma senha em prod e dev
- ❌ Dar permissões de Owner desnecessariamente

---

## 🆘 Troubleshooting

### "AADSTS700016: Application not found"
```bash
# Service Principal foi deletado, criar novo
az ad sp create-for-rbac --name "github-actions-tx02-new" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --sdk-auth
```

### "Terraform state lock"
```bash
# Desbloquear manualmente
az storage blob lease break \
  --account-name tfstatetx02 \
  --container-name tfstate \
  --blob-name tx02-prd.tfstate
```

### "Database connection failed"
- Verificar se DB_HOST está correto
- Verificar se DB_PASSWORD está correto
- Verificar firewall do Azure Database

---

## 📚 Links Úteis

- [Azure Service Principals](https://docs.microsoft.com/azure/active-directory/develop/app-objects-and-service-principals)
- [GitHub Actions Secrets](https://docs.github.com/actions/security-guides/encrypted-secrets)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)

---

**Última atualização:** Dezembro 2025
