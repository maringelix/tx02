# 🎯 TX02 - Plano de Ação para Deploy da Infraestrutura

**Data:** 6 de Janeiro de 2026  
**Status:** Pronto para execução ✅

---

## 📊 Resumo Executivo

### ✅ Validações Locais Completadas

| Item | Status | Detalhes |
|------|--------|----------|
| **Git** | ✅ Instalado | v2.51.0 |
| **GitHub CLI** | ✅ Instalado | v2.83.2 |
| **Repositório** | ✅ Configurado | https://github.com/maringelix/tx02 |
| **Azure CLI** | ❌ Não instalado | **Não é necessário para CI/CD** |
| **Terraform** | ✅ Código validado | 18 workflows + 6 módulos |

### 🎯 Conclusão das Validações

**✅ AMBIENTE LOCAL VALIDADO E PRONTO**

- Git funcional e repositório conectado
- GitHub CLI disponível para gerenciar workflows
- **Azure CLI não está instalado localmente** - Isso é **PERFEITAMENTE CORRETO** pois:
  - ✅ Seguimos melhores práticas DevOps/SRE
  - ✅ Todo deploy será via CI/CD
  - ✅ Azure CLI só será usado dentro dos workflows do GitHub Actions
  - ✅ Evita configurações locais que podem causar inconsistências

---

## 🚀 Plano de Execução (4 Fases)

### 📋 Fase 1: Configurar GitHub Secrets (Manual - 10 minutos)

**⚠️ ESTA É A ÚNICA ETAPA QUE REQUER AZURE CLI**

Você precisa executar isso **UMA VEZ** em uma máquina com Azure CLI ou via Azure Portal:

#### Opção A: Via Azure CLI (em outra máquina ou Azure Cloud Shell)

```bash
# 1. Login no Azure
az login

# 2. Obter informações da subscription
az account show --output json

# 3. Criar Service Principal
az ad sp create-for-rbac \
  --name "github-actions-tx02" \
  --role="Contributor" \
  --scopes="/subscriptions/$(az account show --query id -o tsv)" \
  --sdk-auth
```

#### Opção B: Via Azure Cloud Shell (Recomendado)

1. Acessar: https://portal.azure.com
2. Clicar no ícone do Cloud Shell (>_) no topo
3. Executar os comandos acima
4. Copiar o JSON retornado

#### Secrets a Configurar

Acessar: https://github.com/maringelix/tx02/settings/secrets/actions

| Secret Name | Como Obter |
|------------|------------|
| `AZURE_CREDENTIALS` | JSON completo do Service Principal |
| `AZURE_SUBSCRIPTION_ID` | Campo `subscriptionId` do JSON |
| `AZURE_TENANT_ID` | Campo `tenantId` do JSON |
| `AZURE_CLIENT_ID` | Campo `clientId` do JSON |
| `AZURE_CLIENT_SECRET` | Campo `clientSecret` do JSON |
| `TF_VAR_db_password` | Gerar senha forte (ex: `Tx02DbPass2026!`) |
| `TF_VAR_admin_password` | Gerar senha forte (ex: `Tx02VmAdmin2026!@`) |

**Validação:**
```bash
gh secret list --repo maringelix/tx02
```

---

### 🏗️ Fase 2: Bootstrap - Terraform Backend (CI/CD - 3 minutos)

**Via GitHub Actions (recomendado):**

1. Acessar: https://github.com/maringelix/tx02/actions/workflows/bootstrap.yml
2. Clicar: **"Run workflow"**
3. Configurar:
   - **Action:** `apply`
   - **Confirm:** `bootstrap`
4. Clicar: **"Run workflow"** (botão verde)

**Via GitHub CLI (do seu terminal local):**
```bash
cd /home/tx02/Documents/Projects/tx02

# Executar bootstrap
gh workflow run bootstrap.yml \
  --repo maringelix/tx02 \
  -f action=apply \
  -f confirm=bootstrap

# Monitorar execução
gh run watch --repo maringelix/tx02
```

**O que será criado:**
- ✅ Resource Group: `terraform-state-rg`
- ✅ Storage Account: `tfstatetx02`
- ✅ Blob Container: `tfstate`
- ✅ Versioning habilitado
- ✅ Retention policy configurado

**Tempo:** ~3 minutos  
**Custo:** $0 (Storage mínimo)

---

### 📝 Fase 3: Terraform Plan - Preview (CI/CD - 2 minutos)

**Via GitHub Actions:**

1. Acessar: https://github.com/maringelix/tx02/actions/workflows/terraform-plan.yml
2. Clicar: **"Run workflow"**
3. Configurar:
   - **Environment:** `prd`
4. Clicar: **"Run workflow"**

**Via GitHub CLI:**
```bash
gh workflow run terraform-plan.yml \
  --repo maringelix/tx02 \
  -f environment=prd

gh run watch --repo maringelix/tx02
```

**O que faz:**
- ✅ Valida sintaxe Terraform
- ✅ Mostra recursos que serão criados
- ✅ Estima custos
- ✅ **NÃO cria recursos** (apenas preview)

**Revisar output:**
- Acessar: https://github.com/maringelix/tx02/actions
- Ver último run de "Terraform Plan"
- Revisar lista de recursos

---

### 🚀 Fase 4: Terraform Apply - Deploy Real (CI/CD - 20 minutos)

**⚠️ ATENÇÃO: Isso criará recursos reais no Azure que podem gerar custos**

**Via GitHub Actions:**

1. Acessar: https://github.com/maringelix/tx02/actions/workflows/terraform-apply.yml
2. Clicar: **"Run workflow"**
3. Configurar:
   - **Environment:** `prd`
4. Clicar: **"Run workflow"**

**Via GitHub CLI:**
```bash
gh workflow run terraform-apply.yml \
  --repo maringelix/tx02 \
  -f environment=prd

# Monitorar em tempo real
gh run watch --repo maringelix/tx02
```

**O que será criado:**

```
📦 tx02-prd-rg (Resource Group)
├── 🌐 tx02-prd-vnet (Virtual Network 10.1.0.0/16)
│   ├── tx02-prd-aks-subnet (10.1.1.0/24)
│   ├── tx02-prd-database-subnet (10.1.2.0/24)
│   ├── tx02-prd-vm-subnet (10.1.3.0/24)
│   └── tx02-prd-appgw-subnet (10.1.4.0/24)
│
├── ☸️ tx02-prd-aks (AKS Cluster)
│   ├── Kubernetes v1.32
│   ├── 3 nodes (Standard_B2s)
│   ├── Auto-scaling: 2-10 nodes
│   └── System + User node pools
│
├── 🗄️ tx02-prd-db (PostgreSQL Flexible Server)
│   ├── Version: 17
│   ├── SKU: B_Standard_B1ms (Free Tier)
│   ├── Storage: 32GB
│   └── High Availability: Disabled (Free Tier)
│
├── 📦 tx02prdacr (Container Registry)
│   ├── SKU: Basic (Free Tier)
│   ├── Login: tx02prdacr.azurecr.io
│   └── AKS Integration: Enabled
│
├── 🔒 Network Security Groups
│   ├── tx02-prd-aks-nsg
│   ├── tx02-prd-database-nsg
│   └── tx02-prd-vm-nsg
│
└── 🔐 Private Endpoints
    └── tx02-prd-db-private-endpoint
```

**Tempo:** ~20 minutos  
**Custo:** ~$5-10/mês (otimizado para Free Tier)

**Monitorar:**
```bash
# Ver status em tempo real
gh run watch --repo maringelix/tx02

# Listar últimos runs
gh run list --repo maringelix/tx02 --workflow "Terraform Apply" --limit 5
```

---

## ✅ Validação Pós-Deploy

### Via GitHub CLI (do seu terminal local)

```bash
# 1. Verificar se workflow completou com sucesso
gh run list --repo maringelix/tx02 --workflow "Terraform Apply" --limit 1

# 2. Ver outputs do Terraform (quando disponível)
gh run view --repo maringelix/tx02 --log

# 3. Verificar secrets configurados
gh secret list --repo maringelix/tx02
```

### Quando Azure CLI estiver disponível (opcional)

Se você instalar Azure CLI mais tarde para validações locais:

```bash
# Install Azure CLI (opcional)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Verificar resources
az group show --name tx02-prd-rg --output table
az aks list --output table
az postgres flexible-server list --output table
az acr list --output table
```

---

## 📋 Workflows Disponíveis (18 workflows)

### Core Infrastructure
1. **bootstrap.yml** - Setup Terraform Backend ⭐
2. **terraform-plan.yml** - Preview changes ⭐
3. **terraform-apply.yml** - Deploy infrastructure ⭐
4. **destroy.yml** - Destroy infrastructure ⚠️

### AKS & Applications
5. **aks-deploy.yml** - Deploy apps to AKS
6. **setup-argocd.yml** - Setup GitOps with ArgoCD

### Observability
7. **observability-deploy.yml** - Deploy Prometheus/Grafana
8. **configure-grafana-appinsights.yml** - Configure dashboards
9. **configure-logging.yml** - Setup Azure Monitor

### Security
10. **security-infrastructure.yml** - Security baseline
11. **security-scanning-iac.yml** - IaC security scan
12. **security-scanning-dast.yml** - DAST security scan
13. **deploy-gatekeeper.yml** - OPA Gatekeeper policies

### Service Mesh & Networking
14. **configure-service-mesh.yml** - Deploy Istio

### Backup & Recovery
15. **configure-backup.yml** - Setup Azure Backup
16. **restore-backup.yml** - Restore from backup

### Advanced Features
17. **configure-apm.yml** - Application Performance Monitoring
18. **chaos-engineering.yml** - Chaos testing

---

## 🎯 Ordem de Execução Recomendada

### Sequência Obrigatória (Fase Inicial)

```
1. Configurar GitHub Secrets (manual) ✅
   ↓
2. bootstrap.yml (CI/CD) ✅
   ↓
3. terraform-plan.yml (CI/CD) ✅
   ↓
4. terraform-apply.yml (CI/CD) ✅
```

### Após Infraestrutura Provisionada (Fase 2)

```
5. aks-deploy.yml - Deploy DX02 app
   ↓
6. observability-deploy.yml - Monitoring stack
   ↓
7. security-infrastructure.yml - Security hardening
   ↓
8. configure-service-mesh.yml - Istio mesh
   ↓
9. setup-argocd.yml - GitOps (opcional)
```

---

## 🔍 Comandos Úteis (GitHub CLI)

### Gerenciar Workflows

```bash
# Listar todos workflows
gh workflow list --repo maringelix/tx02

# Ver status do último run
gh run list --repo maringelix/tx02 --limit 5

# Ver detalhes de um run específico
gh run view RUN_ID --repo maringelix/tx02

# Baixar logs de um run
gh run download RUN_ID --repo maringelix/tx02

# Cancelar run em execução
gh run cancel RUN_ID --repo maringelix/tx02

# Re-executar workflow falhado
gh run rerun RUN_ID --repo maringelix/tx02
```

### Gerenciar Secrets

```bash
# Listar secrets
gh secret list --repo maringelix/tx02

# Adicionar secret
gh secret set SECRET_NAME --repo maringelix/tx02

# Deletar secret
gh secret delete SECRET_NAME --repo maringelix/tx02
```

---

## 🚨 Troubleshooting

### Erro: "Service Principal not found"

**Solução:** Recriar Service Principal via Azure Cloud Shell

```bash
az ad sp create-for-rbac \
  --name "github-actions-tx02-$(date +%s)" \
  --role="Contributor" \
  --scopes="/subscriptions/$(az account show --query id -o tsv)" \
  --sdk-auth
```

### Erro: "Insufficient quota"

**Solução:** Solicitar aumento via Azure Portal

1. Portal Azure → Support → New support request
2. Issue type: Service and subscription limits (quotas)
3. Quota type: Compute-VM (cores)
4. Region: East US
5. Request: +10 Standard B Family vCPUs

### Erro: "Backend not found"

**Solução:** Re-executar bootstrap

```bash
gh workflow run bootstrap.yml \
  --repo maringelix/tx02 \
  -f action=apply \
  -f confirm=bootstrap
```

### Workflow falhou com timeout

**Solução:** Re-executar workflow

```bash
gh run rerun RUN_ID --repo maringelix/tx02
```

---

## 💰 Custos Estimados

### Fase Inicial (Bootstrap)
- **Storage Account:** $0.01/mês (Storage mínimo)
- **Total:** ~$0.01/mês

### Infraestrutura Completa (Terraform Apply)
- **AKS Control Plane:** $0/mês (Free Tier)
- **AKS Nodes (3× Standard_B2s):** ~$30-50/mês
- **PostgreSQL (B_Standard_B1ms):** $0/mês (Free Tier)
- **ACR (Basic):** $0/mês (Free Tier - 1 registry)
- **Networking:** ~$5-10/mês
- **Total:** ~$35-60/mês

### Otimizações para Reduzir Custos
- Reduzir nodes AKS para 2 (min) → Save $15-20/mês
- Usar node size menor (Standard_B1s) → Save $10-15/mês
- Desabilitar quando não usar → Save 100%

---

## ✅ Checklist de Execução

### Antes de Começar
- [ ] Ler documentação completa
- [ ] Entender custos envolvidos
- [ ] Ter conta Azure ativa
- [ ] Ter acesso ao GitHub

### Fase 1: Secrets (10 min)
- [ ] Acessar Azure Cloud Shell
- [ ] Criar Service Principal
- [ ] Copiar JSON do SP
- [ ] Configurar 7 secrets no GitHub
- [ ] Gerar senhas fortes
- [ ] Validar secrets criados

### Fase 2: Bootstrap (3 min)
- [ ] Executar workflow bootstrap.yml
- [ ] Aguardar conclusão (verde)
- [ ] Verificar Storage Account criado

### Fase 3: Plan (2 min)
- [ ] Executar workflow terraform-plan.yml
- [ ] Revisar lista de recursos
- [ ] Confirmar que está correto

### Fase 4: Apply (20 min)
- [ ] Executar workflow terraform-apply.yml
- [ ] Monitorar execução
- [ ] Aguardar conclusão (verde)
- [ ] Verificar recursos criados

### Validação Final
- [ ] Todos workflows completados
- [ ] Resource Group criado
- [ ] AKS cluster rodando (3 nodes)
- [ ] Database provisionado
- [ ] ACR criado

---

## 📚 Documentação Adicional

- **[VALIDATION_CHECKLIST.md](./VALIDATION_CHECKLIST.md)** - Checklist completo de validação
- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - Guia detalhado de deployment
- **[BOOTSTRAP_GUIDE.md](./BOOTSTRAP_GUIDE.md)** - Bootstrap step-by-step
- **[GITHUB_SECRETS.md](./GITHUB_SECRETS.md)** - Configuração de secrets
- **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** - Comandos rápidos
- **[README.md](./README.md)** - Visão geral do projeto

---

## 🎉 Próximos Passos Após Deploy

1. **Deploy Aplicação DX02**
   - Configurar secrets do DX02
   - Executar workflow de deploy

2. **Configurar Observabilidade**
   - Deploy Prometheus + Grafana
   - Configurar dashboards

3. **Implementar Segurança**
   - Deploy OPA Gatekeeper
   - Configurar policies

4. **Service Mesh**
   - Deploy Istio
   - Configurar mTLS

5. **GitOps**
   - Setup ArgoCD
   - Automatizar deploys

---

**✅ RESUMO: Você está pronto para começar! Execute os workflows na ordem indicada.**

**Dúvidas?** Consulte a documentação ou revise os logs dos workflows no GitHub Actions.
