# 🔐 Configuração de Secrets - TX02

## ✅ O que foi corrigido

Os workflows foram atualizados para usar o secret `AZURE_CREDENTIALS` que você já configurou.

## 📋 Secrets Necessários

Vá para: **https://github.com/maringelix/tx02/settings/secrets/actions**

### 1️⃣ Secrets já configurados ✅
- `AZURE_CREDENTIALS` ✅
- `AZURE_STORAGE_ACCESS_KEY` ✅

### 2️⃣ Secrets que você precisa ADICIONAR:

| Secret Name | Valor | Descrição |
|------------|-------|-----------|
| `TF_VAR_DB_PASSWORD` | `sua_senha_forte_aqui` | Senha do PostgreSQL (mín. 12 caracteres, maiúsculas, minúsculas, números) |
| `TF_VAR_ADMIN_PASSWORD` | `sua_senha_admin_aqui` | Senha admin da VM (mín. 12 caracteres, maiúsculas, minúsculas, números) |

## 🔧 Passo a Passo

### 1. Gerar senhas fortes (PowerShell):

```powershell
# Senha do Database
$dbPass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})
echo "TF_VAR_DB_PASSWORD: $dbPass"

# Senha Admin da VM
$adminPass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})
echo "TF_VAR_ADMIN_PASSWORD: $adminPass"
```

### 2. Adicionar no GitHub:

1. Vá para: https://github.com/maringelix/tx02/settings/secrets/actions
2. Clique em **"New repository secret"**
3. Adicione cada secret:

   **Nome:** `TF_VAR_DB_PASSWORD`  
   **Valor:** (cole a senha gerada)
   
   **Nome:** `TF_VAR_ADMIN_PASSWORD`  
   **Valor:** (cole a senha gerada)

### 3. Verificar:

Após adicionar os secrets, você deve ter no total:
- ✅ AZURE_CREDENTIALS
- ✅ AZURE_STORAGE_ACCESS_KEY  
- ✅ TF_VAR_DB_PASSWORD
- ✅ TF_VAR_ADMIN_PASSWORD

## 🚀 Próximo Passo

Depois de configurar os secrets, rode o workflow:
1. Vá para **Actions**
2. Selecione **"Terraform Plan"**
3. Clique em **"Run workflow"**

## ⚠️ Importante

- **NÃO** compartilhe as senhas geradas
- **NÃO** commite senhas no código
- **Salve** as senhas em um gerenciador de senhas seguro
