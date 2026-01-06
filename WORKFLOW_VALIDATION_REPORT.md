# 🔍 Validação do Workflow Terraform Plan - TX02

**Data:** 6 de Janeiro de 2026  
**Status:** ⚠️ **CRÍTICO - PROBLEMA ENCONTRADO**

---

## 📋 Resumo Executivo

**PROBLEMA ENCONTRADO:** ❌ Inconsistência crítica no workflow `terraform-plan.yml`

**Severity:** 🔴 **CRÍTICO** - Impedirá o deploy correto

**Impacto:** O `terraform plan` vai criar um plano DIFERENTE do `terraform apply`

---

## 🐛 Problema Identificado

### Inconsistência em `use_aks`

#### terraform-plan.yml (LINHA 84)
```yaml
-var="use_aks=false" \
```

#### terraform-apply.yml (LINHA 93)
```yaml
-var="use_aks=true" \
```

### ⚠️ Consequência

```
terraform plan → -var="use_aks=false"
  └─ Mostrará: VM mode (NÃO vai criar AKS)

terraform apply → -var="use_aks=true"
  └─ Criará: AKS cluster (diferente do plano!)
```

**ISSO VAI CAUSAR:** Divergência entre plan e apply

---

## 🔎 Análise Detalhada do Workflow

### ✅ O que está CORRETO

| Aspecto | Status | Detalhes |
|---------|--------|----------|
| **Triggers** | ✅ OK | Pull request + push paths |
| **Checkout** | ✅ OK | actions/checkout@v4 |
| **Setup Terraform** | ✅ OK | hashicorp/setup-terraform@v3 |
| **Terraform Init** | ✅ OK | Com backend Azure |
| **Terraform Validate** | ✅ OK | Syntax check |
| **Break State Lock** | ✅ OK | Útil para resubmissões |
| **Comment PR** | ✅ OK | Feedback no PR |
| **Secrets** | ✅ OK | Corretamente referenciados |

### ❌ O que está ERRADO

| Problema | Linha | Valor Atual | Valor Esperado | Impacto |
|----------|-------|-------------|----------------|---------|
| `use_aks` | 84 | `false` | `true` | 🔴 CRÍTICO |

### ⚠️ Outros Problemas Menores

#### 1. Falta de Variáveis Sensíveis

```yaml
# terraform-plan.yml está faltando:
TF_VAR_db_password: ${{ secrets.AZURE_SQL_PASSWORD }}
TF_VAR_vm_admin_password: ${{ secrets.TF_VAR_admin_password }}
```

**Está presente em terraform-apply.yml mas FALTANDO em terraform-plan.yml**

**Consequência:** Pode não solicitar credenciais corretamente no plan

#### 2. Variáveis com Valores Inline

```yaml
# Valores hardcoded que deveriam vir de variables.tf:
-var="db_version=12.0"        # ← Deveria ser 17
-var="db_sku_name=Basic"       # ← OK
-var="db_storage_gb=2"         # ← OK
-var="vm_size=Standard_D2s_v3" # ← OK (pode estar deprecado)
```

**db_version=12.0 é PostgreSQL 12, mas terraform.tfvars.example especifica 17**

#### 3. Parallelism

```yaml
# Em terraform-plan.yml
terraform plan ... -parallelism=10 \

# Em terraform-apply.yml (não especifica)
terraform apply tfplan -auto-approve
```

**Inconsistência:** plan usa parallelism=10, apply não especifica

---

## ✅ Checklist de Secrets

### Secrets Necessários (Validação)

| Secret | Esperado | Usado em Plan? | Usado em Apply? | Status |
|--------|----------|---|---|--------|
| `AZURE_CLIENT_ID` | ✅ | ✅ | ✅ | ✅ OK |
| `AZURE_CLIENT_SECRET` | ✅ | ✅ | ✅ | ✅ OK |
| `AZURE_SUBSCRIPTION_ID` | ✅ | ✅ | ✅ | ✅ OK |
| `AZURE_TENANT_ID` | ✅ | ✅ | ✅ | ✅ OK |
| `AZURE_STORAGE_ACCESS_KEY` | ✅ | ✅ | ✅ | ✅ OK |
| `AZURE_SQL_PASSWORD` | ✅ | ❌ FALTA | ✅ | ❌ PROBLEM |
| `TF_VAR_admin_password` | ✅ | ❌ FALTA | ✅ | ❌ PROBLEM |

**Status:** ⚠️ Secrets faltam em terraform-plan.yml

---

## 🔧 Correções Necessárias

### 1. CRÍTICO: Corrigir `use_aks`

**Arquivo:** `.github/workflows/terraform-plan.yml`  
**Linha:** 84

```yaml
# ANTES (ERRADO):
-var="use_aks=false" \

# DEPOIS (CORRETO):
-var="use_aks=true" \
```

### 2. IMPORTANTE: Adicionar Secrets Sensíveis

**Arquivo:** `.github/workflows/terraform-plan.yml`  
**Encontrar:** Seção "Terraform Plan" > env

```yaml
# ADICIONAR ANTES DE "Continue-on-error":
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_ACCESS_KEY: ${{ secrets.AZURE_STORAGE_ACCESS_KEY }}
          TF_VAR_db_password: ${{ secrets.AZURE_SQL_PASSWORD }}
          TF_VAR_vm_admin_password: ${{ secrets.TF_VAR_admin_password }}
```

### 3. IMPORTANTE: Corrigir db_version

**Arquivo:** `.github/workflows/terraform-plan.yml`  
**Linha:** ~91

```yaml
# ANTES (ERRADO):
-var="db_version=12.0" \

# DEPOIS (CORRETO):
-var="db_version=17" \
```

---

## 📋 Teste de Validação

### Teste Local (Sem Executar)

```bash
# Verificar syntax YAML
cd /home/tx02/Documents/Projects/tx02
yamllint .github/workflows/terraform-plan.yml

# Verificar formato
grep "use_aks" .github/workflows/terraform-plan.yml
grep "use_aks" .github/workflows/terraform-apply.yml
```

**Resultado esperado após fix:**
```
terraform-plan.yml:     -var="use_aks=true" \
terraform-apply.yml:    -var="use_aks=true" \
```

---

## 🎯 Impacto das Correções

### Antes das Correções ❌

```
Execução do terraform-plan:
  ├─ use_aks=false → Plan mostra NENHUM AKS
  ├─ db_version=12 → Plan mostra PostgreSQL 12
  ├─ Sem TF_VAR_db_password → Aviso de variável vazia
  └─ Resultado: ❌ Plan INCONSISTENTE

Execução do terraform-apply:
  ├─ use_aks=true → Apply cria AKS
  ├─ db_version=12 → Apply cria PostgreSQL 12
  ├─ Com TF_VAR_db_password → Cria com credencial correta
  └─ Resultado: ❌ Apply DIFERENTE do Plan
```

**Problema:** Plan diz "nada para criar" mas Apply cria AKS inteiro! 🚨

### Depois das Correções ✅

```
Execução do terraform-plan:
  ├─ use_aks=true → Plan mostra AKS
  ├─ db_version=17 → Plan mostra PostgreSQL 17
  ├─ Com TF_VAR_db_password → Variável correta
  └─ Resultado: ✅ Plan CONSISTENTE

Execução do terraform-apply:
  ├─ use_aks=true → Apply cria AKS
  ├─ db_version=17 → Apply cria PostgreSQL 17
  ├─ Com TF_VAR_db_password → Cria com credencial correta
  └─ Resultado: ✅ Apply IDÊNTICO ao Plan
```

**Correto:** Plan e Apply são idênticos! ✅

---

## 📊 Recomendação

### ✅ AÇÃO RECOMENDADA:

**Não execute o terraform-plan enquanto não corrigir o workflow!**

1. ❌ **NÃO FAZER:** `gh workflow run terraform-plan.yml`
2. ✅ **FAZER PRIMEIRO:** Corrigir os 3 problemas
3. ✅ **DEPOIS:** Fazer commit
4. ✅ **ENTÃO:** Executar o terraform-plan
5. ✅ **FINALMENTE:** Executar terraform-apply

---

## 🔧 Como Corrigir

### Opção 1: Via GitHub Web UI

1. Acessar: https://github.com/maringelix/tx02/blob/main/.github/workflows/terraform-plan.yml
2. Clicar: Edit (lápis)
3. Corrigir:
   - Linha 84: `use_aks=false` → `use_aks=true`
   - Linha ~91: `db_version=12.0` → `db_version=17`
   - Adicionar env vars (TF_VAR_*)
4. Commit: "fix: terraform-plan workflow consistency"

### Opção 2: Local (Recomendado)

```bash
cd /home/tx02/Documents/Projects/tx02

# Fazer as 3 correções (editar arquivo)
code .github/workflows/terraform-plan.yml

# Validar YAML
yamllint .github/workflows/terraform-plan.yml

# Commit
git add .github/workflows/terraform-plan.yml
git commit -m "fix: terraform-plan workflow - use_aks consistency and secrets"
git push origin main
```

---

## ✅ Checklist Pós-Correção

- [ ] Linha 84: `use_aks=true` (não false)
- [ ] Linha ~91: `db_version=17` (não 12.0)
- [ ] Env vars adicionadas:
  - [ ] `TF_VAR_db_password`
  - [ ] `TF_VAR_vm_admin_password`
- [ ] YAML válido (sem syntax errors)
- [ ] Commit feito
- [ ] Push enviado
- [ ] Compara com terraform-apply.yml (variáveis iguais)

---

## 🚀 Próximos Passos

### 1. Corrigir Workflow (5 minutos)
```bash
# Editar arquivo
# Fazer 3 correções
# Commit + push
```

### 2. Esperar GitHub Actions (2 minutos)
```bash
# Workflow vai revalidar
# Nenhuma ação é executada (PR não foi aberto)
```

### 3. Executar terraform-plan (5 minutos)
```bash
gh workflow run terraform-plan.yml \
  --repo maringelix/tx02 \
  -f environment=prd
```

### 4. Revisar Plan
```bash
# Verificar se mostra criação de AKS
# Verificar se mostra PostgreSQL 17
# Validar que é idêntico ao terraform-apply
```

### 5. Executar terraform-apply (20 minutos)
```bash
gh workflow run terraform-apply.yml \
  --repo maringelix/tx02 \
  -f environment=prd
```

---

## 📝 Resumo Técnico

| Item | Valor |
|------|-------|
| **Problemas Encontrados** | 3 (1 crítico, 2 importantes) |
| **Tempo de Correção** | ~5 minutos |
| **Requer Reinstalação?** | ❌ Não |
| **Afeta Backend?** | ❌ Não |
| **Afeta Secrets?** | ❌ Não |
| **Risco de Perda de Dados?** | ❌ Não |

---

**Status Final:** ⚠️ **BLOQUEADO - Corrigir Workflow Antes de Executar**

Quer que eu mostre exatamente como corrigir o arquivo?
