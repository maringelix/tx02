# 🔒 Security Scanning - IaC & DAST

Documentação completa sobre security scanning automatizado de infraestrutura (IaC) e testes dinâmicos de segurança (DAST) no TX02.

## 📑 Índice

- [Visão Geral](#-visão-geral)
- [IaC Security Scanning](#-iac-security-scanning)
  - [tfsec](#tfsec---terraform-security-scanner)
  - [Checkov](#checkov---infrastructure-as-code-security)
  - [Gitleaks](#gitleaks---secrets-detection)
- [DAST Security Scanning](#-dast-security-scanning)
  - [OWASP ZAP](#owasp-zap---dynamic-application-security-testing)
- [Como Usar](#-como-usar)
- [Interpretando Resultados](#-interpretando-resultados)
- [Remediação](#-remediação)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Visão Geral

O TX02 implementa múltiplas camadas de security scanning automatizado:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Scanning Layers                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  📝 Code Commit                                                   │
│      │                                                            │
│      ├─> 🔍 IaC Scanning (Terraform)                            │
│      │      ├─ tfsec: Static analysis                           │
│      │      ├─ Checkov: Compliance & security                   │
│      │      └─ Gitleaks: Secret detection                       │
│      │                                                            │
│      └─> 🏗️ Build & Deploy                                      │
│             │                                                     │
│             └─> 🕷️ DAST Scanning (Live App)                     │
│                    └─ OWASP ZAP: Dynamic testing                │
│                                                                   │
│  📊 Results → GitHub Security Tab + Issues                       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 🎭 Camadas de Proteção

| Layer | Tool | Quando Roda | O Que Detecta |
|-------|------|-------------|---------------|
| **Static (IaC)** | tfsec | Push/PR com Terraform | Misconfigurations, insecure defaults |
| **Static (IaC)** | Checkov | Push/PR com Terraform | 750+ policies, compliance violations |
| **Static (Secrets)** | Gitleaks | Push/PR | Hardcoded credentials, API keys |
| **Dynamic (Runtime)** | OWASP ZAP | Após deploy | SQL injection, XSS, CSRF, headers |

---

## 🔍 IaC Security Scanning

### tfsec - Terraform Security Scanner

**O que é:** Static analysis tool focado em Terraform que detecta configurações inseguras.

**Workflow:** `.github/workflows/security-scanning-iac.yml`

**Quando roda:**
- Push para `main` com mudanças em `terraform/**`
- Pull requests com mudanças em Terraform
- Manual via workflow_dispatch

**O que detecta:**

```yaml
# Exemplos de problemas que tfsec encontra:

❌ Azure Storage sem HTTPS:
  resource "azurerm_storage_account" "example" {
    enable_https_traffic_only = false  # ⚠️ tfsec alerta
  }

❌ AKS sem RBAC:
  resource "azurerm_kubernetes_cluster" "example" {
    role_based_access_control {
      enabled = false  # ⚠️ tfsec alerta
    }
  }

❌ SQL Database sem TLS:
  resource "azurerm_mssql_server" "example" {
    minimum_tls_version = "1.0"  # ⚠️ tfsec alerta (deve ser 1.2)
  }
```

**Severidades:**
- 🔴 **CRITICAL**: Exploração imediata possível
- 🟠 **HIGH**: Risco significativo de segurança
- 🟡 **MEDIUM**: Potencial vulnerabilidade
- 🔵 **LOW**: Melhores práticas

**Como visualizar:**
```bash
# Localmente
tfsec terraform/ --format=json

# GitHub
Security Tab → Code scanning alerts → tfsec
```

---

### Checkov - Infrastructure as Code Security

**O que é:** Policy-as-code framework com 750+ checks para Terraform, Kubernetes, Docker, etc.

**Workflow:** `.github/workflows/security-scanning-iac.yml`

**O que detecta:**

```yaml
# Exemplos de policies que Checkov verifica:

✅ CKV_AZURE_33: Storage Account não usa HTTPS
✅ CKV_AZURE_35: Storage Account não usa secure transfer
✅ CKV_AZURE_43: SQL Database não usa Azure AD authentication
✅ CKV_AZURE_50: AKS não usa managed identity
✅ CKV_AZURE_117: AKS não usa Azure Policy addon
✅ CKV_AZURE_168: SQL Database não usa Private Endpoint
✅ CKV2_AZURE_1: Storage Account não tem logging habilitado
✅ CKV2_AZURE_8: AKS não tem audit logging
```

**Compliance frameworks suportados:**
- CIS Azure Benchmarks
- HIPAA
- PCI-DSS
- SOC 2
- GDPR
- ISO 27001

**Como usar:**
```bash
# Scan local com compliance
checkov -d terraform/ --framework terraform --compact

# Scan com framework específico
checkov -d terraform/ --framework terraform --check CIS_AZURE

# Skip checks específicos
checkov -d terraform/ --skip-check CKV_AZURE_33
```

---

### Gitleaks - Secrets Detection

**O que é:** Scanner que detecta secrets, passwords, API keys hardcoded no código ou git history.

**Workflow:** `.github/workflows/security-scanning-iac.yml`

**O que detecta:**

```bash
# Exemplos de secrets que Gitleaks encontra:

❌ AWS Keys:
  aws_access_key_id = "AKIAIOSFODNN7EXAMPLE"

❌ Azure Connection Strings:
  DefaultEndpointsProtocol=https;AccountName=myaccount;
  AccountKey=abc123...

❌ Private Keys:
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA...

❌ Generic Passwords:
  DB_PASSWORD="SuperSecret123!"

❌ Tokens:
  GITHUB_TOKEN="ghp_abc123xyz"
```

**Como funciona:**
- Scans entire git history (não só último commit)
- Usa regex patterns + entropy analysis
- Detecta 100+ tipos de secrets

**Falsos positivos:** Criar `.gitleaksignore`
```
# Ignore test fixtures
test/fixtures/fake-credentials.json:1

# Ignore example configs
config.example.yaml:15
```

---

## 🕷️ DAST Security Scanning

### OWASP ZAP - Dynamic Application Security Testing

**O que é:** Web application security scanner que testa a aplicação em runtime.

**Workflow:** `.github/workflows/security-scanning-dast.yml`

**Quando roda:**
- Após deploy bem-sucedido (`workflow_run`)
- Manual via workflow_dispatch
- (Recomendado) Scheduled weekly

**Tipos de scan:**

#### 1. Baseline Scan (~5 minutos)
```yaml
# Rápido, ideal para CI/CD
scan_type: baseline

O que testa:
  ✅ Passive scanning (não invasivo)
  ✅ Security headers
  ✅ Cookie security
  ✅ Content Security Policy
  ✅ X-Frame-Options
  ✅ SSL/TLS configuration
```

#### 2. Full Scan (~30-60 minutos)
```yaml
# Comprehensive, para auditorias
scan_type: full

O que testa:
  ✅ Active scanning (invasivo)
  ✅ SQL Injection
  ✅ Cross-Site Scripting (XSS)
  ✅ Cross-Site Request Forgery (CSRF)
  ✅ Path Traversal
  ✅ Command Injection
  ✅ Remote File Inclusion
  ✅ Server-Side Request Forgery (SSRF)
```

#### 3. API Scan (~10-15 minutos)
```yaml
# Para REST APIs com OpenAPI spec
scan_type: api

O que testa:
  ✅ API endpoint vulnerabilities
  ✅ Authentication/Authorization
  ✅ Input validation
  ✅ Rate limiting
  ✅ Error handling
```

**Como rodar manualmente:**

```bash
# Via workflow dispatch no GitHub
Actions → 🕷️ Security Scanning - DAST → Run workflow
  └─ target_url: http://51.8.204.129
  └─ scan_type: baseline/full/api

# Localmente com Docker
docker run -v $(pwd):/zap/wrk/:rw \
  -t owasp/zap2docker-stable zap-baseline.py \
  -t http://51.8.204.129 \
  -r zap-report.html
```

**Interpretando resultados:**

```
Risk Levels:
🔴 High   = Exploração confirmada, ação imediata
🟠 Medium = Provável vulnerabilidade, investigar
🟡 Low    = Potencial issue, revisar
🔵 Info   = Informacional, sem risco direto

Common Findings:

1. Missing Security Headers
   Risk: Low/Medium
   Fix: Adicionar no Ingress ou application
   
2. Cookie Without Secure Flag
   Risk: Medium
   Fix: Set secure=true em cookies
   
3. SQL Injection
   Risk: High
   Fix: Usar prepared statements/ORMs
   
4. Cross-Site Scripting (XSS)
   Risk: High
   Fix: Sanitizar inputs, escape outputs
```

---

## 🚀 Como Usar

### Execução Automática (CI/CD)

Os workflows rodam automaticamente:

```yaml
# IaC Scanning: Roda em push/PR com Terraform
git add terraform/main.tf
git commit -m "feat: add new resource"
git push
# ↓ Workflow security-scanning-iac.yml roda automaticamente

# DAST Scanning: Roda após deploy
git push  # Deploy workflow completa
# ↓ Workflow security-scanning-dast.yml roda automaticamente
```

### Execução Manual

```bash
# 1. GitHub Actions
Actions → [workflow name] → Run workflow

# 2. Local - tfsec
cd terraform
tfsec . --format=json > tfsec-results.json

# 3. Local - Checkov
checkov -d terraform/ --framework terraform --output-format cli

# 4. Local - Gitleaks
gitleaks detect --source . --verbose

# 5. Local - OWASP ZAP
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t http://51.8.204.129 \
  -r baseline-report.html
```

### Pre-commit hooks

`.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_tfsec
      - id: terraform_checkov
  
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

Instalar:
```bash
pip install pre-commit
pre-commit install
```

---

## 📊 Interpretando Resultados

### GitHub Security Tab

```
Repository → Security → Code scanning alerts

Filtros disponíveis:
  - Tool (tfsec, checkov, zap)
  - Severity (critical, high, medium, low)
  - State (open, closed, fixed)
  - Branch

Para cada alert:
  1. Description: O que foi encontrado
  2. Location: Arquivo e linha
  3. Recommendation: Como corrigir
  4. CWE/CVE: Classificação da vulnerabilidade
```

### Workflow Summary

Cada workflow gera um summary no final:

```markdown
## 🔒 Security Scanning Results - IaC

### Scanners Executed
| Scanner | Purpose | Status |
|---------|---------|--------|
| tfsec   | Terraform static analysis | ✅ Completed |
| Checkov | IaC security & compliance | ✅ Completed |
| Gitleaks | Secret detection | ✅ Completed |

### Review Results
1. GitHub Security Tab: Security > Code scanning alerts
2. Workflow Logs: Detailed output
3. SARIF Files: Downloadable artifacts
```

---

## 🔧 Remediação

### IaC Findings

#### ❌ Storage Account sem HTTPS

**Finding:** `CKV_AZURE_33: Ensure Storage logging is enabled for Blob service`

**Fix:**
```hcl
resource "azurerm_storage_account" "example" {
  name                     = "mystorageaccount"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  
  # ✅ Enable HTTPS
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
  
  # ✅ Enable blob logging
  blob_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 30
    }
  }
}
```

#### ❌ Secret hardcoded

**Finding:** `gitleaks: Generic API Key detected`

**Fix:**
```yaml
# ❌ NUNCA faça isso
api_key: "abc123-secret-key"

# ✅ Use GitHub Secrets
api_key: ${{ secrets.API_KEY }}

# ✅ Ou Azure Key Vault
api_key: "@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/apikey)"
```

### DAST Findings

#### ❌ Missing Security Headers

**Finding:** `X-Content-Type-Options header missing`

**Fix (Ingress):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dx02-ingress
  annotations:
    # ✅ Add security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Strict-Transport-Security: max-age=31536000";
```

#### ❌ SQL Injection

**Finding:** `SQL Injection vulnerability detected`

**Fix:**
```javascript
// ❌ Vulnerable
const query = `SELECT * FROM users WHERE id = ${req.params.id}`;
db.query(query);

// ✅ Prepared statement
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [req.params.id]);

// ✅ ORM (Sequelize)
const user = await User.findByPk(req.params.id);
```

---

## 🐛 Troubleshooting

### tfsec Issues

**Problema:** Muitos falsos positivos
```bash
# Solução: Usar inline ignore com justificativa
resource "azurerm_storage_account" "example" {
  #tfsec:ignore:azure-storage-use-secure-tls-policy Reason: Free tier limitation
  min_tls_version = "TLS1_0"
}
```

### Checkov Issues

**Problema:** Scan muito lento
```bash
# Solução: Skip frameworks não usados
checkov -d . --framework terraform --skip-framework kubernetes,dockerfile
```

### Gitleaks Issues

**Problema:** Secret já no histórico
```bash
# Solução: Remover do histórico (cuidado!)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch path/to/file' \
  --prune-empty --tag-name-filter cat -- --all
```

### ZAP Issues

**Problema:** Scan timeout
```bash
# Solução: Aumentar max-duration no workflow
cmd_options: '-a -j -m 60'  # 60 minutes
```

---

## 📚 Recursos Adicionais

### Documentação Oficial

- **tfsec**: https://aquasecurity.github.io/tfsec/
- **Checkov**: https://www.checkov.io/
- **Gitleaks**: https://github.com/gitleaks/gitleaks
- **OWASP ZAP**: https://www.zaproxy.org/docs/

### Compliance Frameworks

- **CIS Benchmarks**: https://www.cisecurity.org/cis-benchmarks/
- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **Azure Security**: https://docs.microsoft.com/en-us/azure/security/

---

## 🎯 Próximos Passos

- [ ] **Dependency Scanning**: Adicionar Snyk ou Dependabot
- [ ] **Container Scanning**: Expandir Trivy para scan de runtime
- [ ] **SAST**: Adicionar Semgrep ou SonarQube para código
- [ ] **Compliance as Code**: Implementar Azure Policy definitions
- [ ] **Threat Modeling**: Microsoft Threat Modeling Tool

---

**Mantido por:** DevOps Team  
**Última atualização:** Dezembro 2025  
**Versão:** 1.0.0
