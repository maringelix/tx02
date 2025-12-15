# TX02 - Infraestrutura Azure com Terraform e CI/CD

🎉 **Infraestrutura de produção completa na Azure com AKS Kubernetes, Azure Database for PostgreSQL, VM, Application Gateway, e CI/CD totalmente automatizado.**

[![AKS](https://img.shields.io/badge/AKS-v1.32-blue.svg)](https://azure.microsoft.com/en-us/services/kubernetes-service/)
[![Terraform](https://img.shields.io/badge/Terraform-1.6.0-purple.svg)](https://www.terraform.io/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-blue.svg)](https://www.postgresql.org/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-Workflows-green.svg)](https://github.com/features/actions)
[![Prometheus](https://img.shields.io/badge/Prometheus-Latest-orange.svg)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Latest-orange.svg)](https://grafana.com/)

---

## ⚠️ **Important Security Notice**

> 🔒 **This is a demonstration/portfolio project showcasing DevOps best practices on Azure.**

**Before using this in production:**

- ⚠️ **DO NOT** copy Azure credentials to code or commit them to Git
- ✅ All Azure credentials must be managed via **GitHub Secrets** or **Azure Key Vault**
- ✅ Replace all placeholder values with your own configurations
- ✅ Review and adjust IAM policies according to your security requirements
- ✅ Enable encryption at rest and in transit for all resources
- ✅ Implement proper backup and disaster recovery strategies
- ✅ Follow your organization's security and compliance policies
- ✅ Use Azure Management Groups for multi-subscription governance

**Security Features Implemented:**
- 🔐 No credentials in code (all via Key Vault/GitHub Secrets)
- 🔐 Azure Storage backend with encryption and versioning
- 🔐 Managed Identity for AKS workloads
- 🔐 Network Security Groups with least privilege
- 🔐 Azure Database encryption at rest
- 🔐 VNet with public/private subnet isolation

**This project is safe to share publicly** - All sensitive data is properly externalized.

---

## 📊 **Code Quality**

<div align="center">

| Metric | Rating | Issues | Status |
|--------|--------|--------|--------|
| **Security** | 🟢 A | 0 | Excellent |
| **Reliability** | 🟢 A | 0 | Excellent |
| **Maintainability** | 🟢 A | 0 | Excellent |
| **Coverage** | 🟡 Terraform Tests | - | Infrastructure validation |
| **Duplications** | 🟢 0.0% | 0 | No duplicates |
| **Lines of Code** | - | 2,500+ | Terraform, YAML |

**Quality Gate:** ✅ **PASSED**

</div>

---

## 🏆 **PROJETO COMPLETO E FUNCIONAL**

Este projeto demonstra uma arquitetura cloud moderna na Azure com:
- ✅ **Kubernetes (AKS)** - Cluster v1.32 com auto-scaling
- ✅ **Azure Database for PostgreSQL** - Banco de dados gerenciado
- ✅ **Switch Mode** - Alterna entre VM e AKS dinamicamente
- ✅ **CI/CD Completo** - Deploy automático via GitHub Actions
- ✅ **Infraestrutura como Código** - 100% Terraform
- ✅ **Alta Disponibilidade** - Multi-zone com load balancing
- ✅ **Segurança** - RBAC, NSGs, Key Vault

## � Quick Start

### 🎯 Método Recomendado: CI/CD (GitHub Actions)

**Provisionamento 100% automatizado via GitHub Actions - zero configuração local!**

📖 **[QUICKSTART_CICD.md](./QUICKSTART_CICD.md)** - Guia rápido (5 minutos)  
📚 **[BOOTSTRAP_GUIDE.md](./BOOTSTRAP_GUIDE.md)** - Documentação completa

```bash
# Passo a passo resumido:
1. Configure secrets no GitHub (AZURE_CREDENTIALS, passwords)
2. Execute workflow: Bootstrap - Setup Terraform Backend
3. Execute workflow: Terraform Apply
4. Configure secrets no DX02
5. Execute workflow: Deploy to AKS
# ✅ Pronto! Infraestrutura e aplicação rodando em ~25 minutos
```

### 💻 Setup Local (Alternativo)

Para desenvolvimento local ou troubleshooting - veja seção completa no final do README.

---

## �📋 Arquitetura

### **Modo AKS (Kubernetes)**
```
┌─────────────────────────────────────────────────────────────┐
│                      Azure Cloud                             │
│                                                              │
│  Internet → App Gateway → AKS Ingress → AKS v1.32          │
│               ├─ Ingress Controller                         │
│               └─ Service (LoadBalancer)                     │
│                           │                                  │
│                    AKS Cluster v1.32                        │
│                    ├─ Node 1 (Standard_B2s)                 │
│                    │  └─ Pod dx02-app                       │
│                    ├─ Node 2 (Standard_B2s)                 │
│                    │  └─ Pod dx02-app                       │
│                    ├─ Node 3 (Standard_B2s)                 │
│                    └─ HPA (2-10 pods)                       │
│                                                              │
│             ↓ (Network Security Groups)                     │
│                                                              │
│         Azure Database for PostgreSQL 17                    │
│              (Flexible Server - Burstable)                   │
└─────────────────────────────────────────────────────────────┘
```

### **Modo VM (Desenvolvimento/Teste)**
```
┌─────────────────────────────────────────────────────────────┐
│                      Azure Cloud                             │
│                                                              │
│  Internet → Public IP → Load Balancer → VM                 │
│                                          │                   │
│                                   Ubuntu 22.04              │
│                                   Docker Compose            │
│                                   └─ dx02 Container         │
│                                                              │
│             ↓ (Network Security Groups)                     │
│                                                              │
│         Azure Database for PostgreSQL 17                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Início Rápido

### **Pré-requisitos**
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) instalado
- [Terraform](https://www.terraform.io/downloads) >= 1.6.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) instalado
- Conta Azure ativa com permissões adequadas
- GitHub account para CI/CD

### **1. Clone o Repositório**
```bash
git clone https://github.com/maringelix/tx02.git
cd tx02
```

### **2. Configure as Credenciais Azure**
```bash
# Login no Azure
az login

# Definir subscription ativa
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Criar Service Principal para Terraform
az ad sp create-for-rbac --name "terraform-tx02" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"
```

### **3. Configurar Backend do Terraform**
```bash
# Criar Resource Group para backend
az group create --name terraform-state-rg --location eastus

# Criar Storage Account
az storage account create \
  --name tfstatetx02 \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS

# Criar Container
az storage container create \
  --name tfstate \
  --account-name tfstatetx02
```

### **4. Inicializar Terraform**
```bash
cd terraform/prd

# Copiar exemplo de variáveis
cp terraform.tfvars.example terraform.tfvars

# Editar com seus valores
nano terraform.tfvars

# Inicializar
terraform init

# Planejar
terraform plan

# Aplicar
terraform apply
```

### **5. Conectar ao AKS**
```bash
# Obter credenciais do AKS
az aks get-credentials \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks

# Verificar nodes
kubectl get nodes

# Verificar pods
kubectl get pods -A
```

---

## 📁 Estrutura do Projeto

```
tx02/
├── .github/
│   └── workflows/              # GitHub Actions CI/CD
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       ├── aks-deploy.yml
│       └── destroy.yml
├── terraform/
│   ├── bootstrap/              # Configuração inicial
│   │   └── main.tf
│   ├── modules/                # Módulos reutilizáveis
│   │   ├── aks/
│   │   ├── database/
│   │   ├── networking/
│   │   └── vm/
│   ├── prd/                    # Ambiente de Produção
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── stg/                    # Ambiente de Staging
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── k8s/                        # Manifestos Kubernetes
│   ├── deployment.yml
│   ├── service.yml
│   ├── ingress.yml
│   ├── hpa.yml
│   └── observability/
│       ├── prometheus/
│       └── grafana/
├── scripts/                    # Scripts de automação
│   ├── setup-aks.sh
│   ├── install-ingress.sh
│   └── cleanup-azure.ps1
├── config.json                 # Configuração do projeto
├── DEPLOYMENT_GUIDE.md         # Guia de deploy
├── GITHUB_SECRETS.md           # Configuração de secrets
├── QUICK_REFERENCE.md          # Referência rápida
└── README.md
```

---

## 🔐 Variáveis de Ambiente e Secrets

### **GitHub Secrets (obrigatórios)**
Configure estes secrets no GitHub (Settings → Secrets and variables → Actions):

```bash
AZURE_CREDENTIALS          # Service Principal JSON
AZURE_SUBSCRIPTION_ID      # ID da subscription Azure
AZURE_TENANT_ID            # ID do tenant Azure
AZURE_CLIENT_ID            # Client ID do Service Principal
AZURE_CLIENT_SECRET        # Client Secret do Service Principal
TF_VAR_db_password         # Senha do PostgreSQL
TF_VAR_admin_username      # Username admin da VM
TF_VAR_admin_password      # Senha admin da VM
```

### **Variáveis Terraform**
Edite `terraform/prd/terraform.tfvars`:

```hcl
# Projeto
project_name = "tx02"
environment  = "prd"
location     = "eastus"

# Rede
vnet_address_space = ["10.1.0.0/16"]
subnet_aks         = "10.1.1.0/24"
subnet_database    = "10.1.2.0/24"
subnet_vm          = "10.1.3.0/24"

# AKS
aks_node_count     = 3
aks_node_size      = "Standard_B2s"
kubernetes_version = "1.32"

# Database
db_sku_name        = "B_Standard_B1ms"
db_storage_gb      = 32
db_version         = "17"
db_admin_username  = "dbadmin"
# db_password via TF_VAR_db_password

# VM (modo desenvolvimento)
vm_size            = "Standard_B2s"
vm_admin_username  = "azureuser"
# vm_password via TF_VAR_admin_password
```

---

## 🎯 Modos de Operação

### **Modo 1: AKS (Kubernetes) - Produção**
Para rodar a aplicação no AKS:

```bash
cd terraform/prd
terraform apply -var="use_aks=true"
```

**Características:**
- ✅ Alta disponibilidade (multi-node)
- ✅ Auto-scaling horizontal (HPA)
- ✅ Load balancing automático
- ✅ Ideal para produção
- 💰 Custo: ~$150-200/mês

### **Modo 2: VM (Docker) - Desenvolvimento**
Para rodar em uma única VM com Docker:

```bash
cd terraform/prd
terraform apply -var="use_aks=false"
```

**Características:**
- ✅ Mais simples e econômico
- ✅ Ideal para testes e desenvolvimento
- ⚠️ Sem auto-scaling
- ⚠️ Single point of failure
- 💰 Custo: ~$50-80/mês

---

## 🔄 CI/CD com GitHub Actions

### **Workflows Disponíveis**

1. **Terraform Plan** (Pull Request)
   - Valida sintaxe Terraform
   - Executa `terraform plan`
   - Comenta o plano no PR

2. **Terraform Apply** (Push to main)
   - Aplica mudanças na infraestrutura
   - Atualiza outputs como secrets
   - Notifica no Slack

3. **Deploy to AKS** (Tag/Release)
   - Conecta ao AKS
   - Aplica manifestos K8s
   - Verifica health dos pods

4. **Destroy Infrastructure** (Manual)
   - Destrói toda infraestrutura
   - Requer confirmação manual
   - Backup automático antes de destruir

### **Fluxo de Deploy**
```
Developer → Git Push → GitHub Actions
                           ↓
                  [Terraform Plan]
                           ↓
                     PR Aprovado
                           ↓
                  [Terraform Apply]
                           ↓
                    Infra Criada
                           ↓
                  [Deploy to AKS]
                           ↓
               dx02 rodando na Azure! 🎉
```

---

## 📊 Monitoramento e Observabilidade

### **Prometheus + Grafana**
```bash
# Instalar stack de observabilidade
cd k8s/observability
kubectl apply -f prometheus/
kubectl apply -f grafana/

# Acessar Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# http://localhost:3000 (admin/admin)
```

### **Métricas Disponíveis**
- CPU, memória, disco por pod/node
- Request rate, latência, erros
- Health checks da aplicação
- Database connections e queries
- Custo estimado da infraestrutura

---

## 💰 Estimativa de Custos (Azure)

### **Modo AKS (Produção)**
| Recurso | Tipo | Quantidade | Custo/mês |
|---------|------|------------|-----------|
| AKS Control Plane | Free Tier | 1 | $0 |
| AKS Nodes | Standard_B2s | 3 | ~$90 |
| Azure Database | B_Standard_B1ms | 1 | ~$30 |
| Application Gateway | Standard_v2 | 1 | ~$50 |
| Load Balancer | Basic | 1 | ~$5 |
| Storage | Standard LRS | 100GB | ~$5 |
| Bandwidth | Outbound | ~50GB | ~$5 |
| **TOTAL** | | | **~$185/mês** |

### **Modo VM (Desenvolvimento)**
| Recurso | Tipo | Quantidade | Custo/mês |
|---------|------|------------|-----------|
| VM | Standard_B2s | 1 | ~$30 |
| Azure Database | B_Standard_B1ms | 1 | ~$30 |
| Load Balancer | Basic | 1 | ~$5 |
| Storage | Standard LRS | 64GB | ~$3 |
| Bandwidth | Outbound | ~20GB | ~$2 |
| **TOTAL** | | | **~$70/mês** |

*Valores aproximados para região East US (Dezembro 2025)*

---

## 🛠️ Comandos Úteis

### **Azure CLI**
```bash
# Listar recursos
az resource list --resource-group tx02-prd-rg --output table

# Ver custos
az consumption usage list --start-date 2025-12-01 --end-date 2025-12-15

# Logs da VM
az vm run-command invoke \
  --resource-group tx02-prd-rg \
  --name tx02-prd-vm \
  --command-id RunShellScript \
  --scripts "docker logs dx02"
```

### **Kubernetes**
```bash
# Contexto atual
kubectl config current-context

# Ver todos os recursos
kubectl get all -A

# Logs de um pod
kubectl logs -f deployment/dx02 -n default

# Escalar deployment
kubectl scale deployment/dx02 --replicas=5

# Port-forward
kubectl port-forward svc/dx02 8080:80
```

### **Terraform**
```bash
# Validar configuração
terraform validate

# Formatar código
terraform fmt -recursive

# Ver outputs
terraform output

# Destruir tudo
terraform destroy -auto-approve
```

---

## 🐛 Troubleshooting

### **AKS não está criando os nodes**
```bash
# Verificar eventos do cluster
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Ver detalhes do node pool
az aks nodepool show \
  --resource-group tx02-prd-rg \
  --cluster-name tx02-prd-aks \
  --name nodepool1
```

### **Database não conecta**
```bash
# Testar conectividade
az postgres flexible-server connect \
  --name tx02-prd-db \
  --database-name dx02db \
  --admin-user dbadmin

# Verificar firewall rules
az postgres flexible-server firewall-rule list \
  --resource-group tx02-prd-rg \
  --name tx02-prd-db
```

### **Terraform state locked**
```bash
# Forçar unlock (cuidado!)
terraform force-unlock LOCK_ID
```

Veja [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para mais detalhes.

---

## 📚 Documentação Adicional

- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Guia completo de deploy
- [GITHUB_SECRETS.md](GITHUB_SECRETS.md) - Configuração de secrets
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Referência rápida de comandos
- [SECURITY.md](SECURITY.md) - Políticas de segurança

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Para grandes mudanças:
1. Abra uma issue primeiro para discutir a mudança
2. Fork o repositório
3. Crie uma branch para sua feature
4. Commit suas mudanças
5. Push para a branch
6. Abra um Pull Request

---

## 📄 Licença

Este projeto está sob a licença MIT. Veja [LICENSE](LICENSE) para detalhes.

---

## 👤 Autor

**maringelix**
- GitHub: [@maringelix](https://github.com/maringelix)
- LinkedIn: [maringelix](https://linkedin.com/in/maringelix)

---

## 🙏 Agradecimentos

- Azure Documentation
- Terraform Azure Provider
- Kubernetes Community
- GitHub Actions Community

---

**⭐ Se este projeto foi útil, considere dar uma estrela!**
