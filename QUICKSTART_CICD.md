# 🎯 TX02/DX02 - Quick Start CI/CD

Guia rápido para provisionar a infraestrutura completa via GitHub Actions.

## ⚡ Execução Rápida (5 minutos)

### 1️⃣ Configurar Secrets (GitHub Web)

**TX02 Repository** (https://github.com/maringelix/tx02/settings/secrets/actions):

```bash
# Clique em "New repository secret" e adicione:

Nome: AZURE_CREDENTIALS
Valor: <cole o JSON completo do Service Principal>

Nome: TF_VAR_db_password
Valor: <senha forte, ex: MyP@ssw0rd123>

Nome: TF_VAR_admin_password
Valor: <senha forte para VM, ex: AdminP@ss123!>
```

### 2️⃣ Executar Bootstrap

1. Acesse: https://github.com/maringelix/tx02/actions
2. Workflow: **Bootstrap - Setup Terraform Backend**
3. **Run workflow** → Digite `bootstrap` → **Run**
4. ⏱️ Aguarde ~3 minutos
5. ✅ Verifique conclusão

### 3️⃣ Provisionar Infraestrutura

1. Acesse: https://github.com/maringelix/tx02/actions
2. Workflow: **Terraform Apply**
3. **Run workflow**:
   - Environment: `prd`
   - Deploy Mode: `aks`
   - Confirm: `apply`
4. **Run** → ⏱️ Aguarde ~15 minutos
5. ✅ Copie outputs (DB_HOST, etc)

### 4️⃣ Configurar DX02 Secrets

**DX02 Repository** (https://github.com/maringelix/dx02/settings/secrets/actions):

```bash
# Use os outputs do Terraform Apply

Nome: AZURE_CREDENTIALS
Valor: <mesmo JSON do TX02>

Nome: DB_HOST
Valor: <obtido do Terraform output>

Nome: DB_NAME
Valor: dx02_db

Nome: DB_USER
Valor: dx02admin

Nome: DB_PASSWORD
Valor: <mesmo valor de TF_VAR_db_password>

Nome: AKS_CLUSTER_NAME
Valor: aks-tx02-prd

Nome: AKS_RESOURCE_GROUP
Valor: rg-tx02-prd
```

### 5️⃣ Deploy Aplicação

1. Acesse: https://github.com/maringelix/dx02/actions
2. Workflow: **Deploy to AKS**
3. **Run workflow** → **Run**
4. ⏱️ Aguarde ~5 minutos
5. ✅ Aplicação rodando!

## 📋 Checklist Completo

```
☐ Secrets configurados no TX02
  ☐ AZURE_CREDENTIALS
  ☐ TF_VAR_db_password
  ☐ TF_VAR_admin_password

☐ Bootstrap executado com sucesso
  ☐ Storage Account criado
  ☐ Terraform backend configurado

☐ Terraform Apply executado
  ☐ VNet criada
  ☐ AKS cluster provisionado
  ☐ PostgreSQL database criado
  ☐ Outputs copiados

☐ Secrets configurados no DX02
  ☐ AZURE_CREDENTIALS
  ☐ DB_HOST
  ☐ DB_NAME
  ☐ DB_USER
  ☐ DB_PASSWORD
  ☐ AKS_CLUSTER_NAME
  ☐ AKS_RESOURCE_GROUP

☐ Deploy DX02 executado
  ☐ Container build bem-sucedido
  ☐ Pods running no AKS
  ☐ Service exposto
```

## 🔍 Comandos de Verificação

### Verificar Backend Terraform

```bash
az storage account show --name tfstatetx02 --resource-group terraform-state-rg -o table
```

### Verificar Infraestrutura

```bash
# Resource Groups
az group list --tag ManagedBy=Terraform -o table

# AKS
az aks list -o table

# PostgreSQL
az postgres flexible-server list -o table
```

### Conectar no AKS

```bash
# Obter credenciais
az aks get-credentials --resource-group rg-tx02-prd --name aks-tx02-prd

# Verificar nodes
kubectl get nodes

# Verificar aplicação
kubectl get pods -n dx02
kubectl get svc -n dx02
```

### Obter URL da Aplicação

```bash
# Obter IP externo do LoadBalancer
kubectl get svc dx02 -n dx02 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Acessar aplicação
echo "http://$(kubectl get svc dx02 -n dx02 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

## 🆘 Troubleshooting Rápido

| Problema | Solução Rápida |
|----------|---------------|
| ❌ Bootstrap falha | Verifique `AZURE_CREDENTIALS` secret |
| ❌ Terraform Apply falha | Execute Bootstrap primeiro |
| ❌ DB password error | Senha deve ter 8+ chars, maiúsculas, minúsculas, números |
| ❌ AKS Deploy falha | Verifique se Terraform Apply completou |
| ❌ ImagePullBackOff | Execute Docker Build workflow no DX02 |

## 🔗 Links Rápidos

- [TX02 Actions](https://github.com/maringelix/tx02/actions)
- [DX02 Actions](https://github.com/maringelix/dx02/actions)
- [TX02 Secrets](https://github.com/maringelix/tx02/settings/secrets/actions)
- [DX02 Secrets](https://github.com/maringelix/dx02/settings/secrets/actions)
- [Azure Portal](https://portal.azure.com)
- [Bootstrap Guide (Detalhado)](./BOOTSTRAP_GUIDE.md)

## 💡 Dicas

- 🕐 **Tempo total**: ~25 minutos (primeira execução)
- 💰 **Custo**: ~$272/mês (ou ~$30/mês em modo VM)
- 🎯 **Free Trial**: R$ 1.078,95 disponíveis (~25 dias)
- 🔄 **Re-executar**: Use Terraform Destroy antes de Apply novamente
- 📊 **Monitorar**: Azure Portal → Resource Groups → rg-tx02-prd

---

**Pronto para começar?** Execute o Passo 1! 🚀
