# SonarQube/SonarCloud - Análise de Qualidade de Código

## 📊 Visão Geral

Este projeto utiliza **SonarCloud** (versão cloud do SonarQube) para análise contínua de qualidade de código, detecção de bugs, vulnerabilidades de segurança e code smells.

---

## 🎯 Projeto TX02 no SonarCloud

**URL:** https://sonarcloud.io/organizations/maringelix/projects

### Métricas Atuais

| Métrica | Rating | Valor | Detalhes |
|---------|--------|-------|----------|
| **Security** | 🟡 C | 3 issues | Minor security issues |
| **Reliability** | 🟢 A | 2 issues | Excellent reliability |
| **Maintainability** | 🟢 A | 6 issues | Clean code |
| **Hotspots Reviewed** | 🔴 E | 0.0% | Requires review |
| **Duplications** | 🟢 | 0.0% | No code duplication |
| **Lines of Code** | - | 3,300+ | YAML, Terraform |

**Status:** 📝 Not Computed (análise inicial)

---

## 📁 Arquivos Analisados

- ✅ **Terraform** (.tf files)
  - Infraestrutura como código (AKS, SQL Database, Networking)
  - Variables, outputs, providers
  
- ✅ **YAML**
  - Kubernetes manifests (deployments, services, ingress)
  - GitHub Actions workflows
  - Configurações (docker-compose, observability)

- ✅ **Scripts**
  - Shell scripts (.sh)
  - PowerShell scripts (.ps1)

---

## 🔧 Configuração

### 1. Organização SonarCloud

- **Organization:** `maringelix`
- **Project Key:** `tx02`
- **Visibility:** Public
- **Language:** YAML, Terraform

### 2. Integração com GitHub

O SonarCloud está integrado diretamente com o repositório GitHub:

```yaml
# Exemplo de workflow (futuro)
name: SonarCloud Analysis
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  sonarcloud:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    
    - name: SonarCloud Scan
      uses: SonarSource/sonarcloud-github-action@master
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

### 3. Arquivo sonar-project.properties

```properties
# Project identification
sonar.organization=maringelix
sonar.projectKey=tx02
sonar.projectName=TX02 - Azure Infrastructure

# Source code
sonar.sources=.
sonar.exclusions=**/node_modules/**,**/*.test.js,**/dist/**,**/build/**

# Language specific
sonar.sourceEncoding=UTF-8

# Terraform specific
sonar.terraform.file.suffixes=.tf

# YAML specific  
sonar.yaml.file.suffixes=.yaml,.yml
```

---

## 📈 Issues Identificados

### Security (C Rating - 3 issues)

Os 3 issues de segurança são provavelmente relacionados a:
- 🔍 Hardcoded credentials placeholders em exemplos
- 🔍 Permissões amplas em IAM policies (Azure Free Tier)
- 🔍 Secrets expostos em comentários/docs

**Ação:** Revisar e aplicar secrets management com Azure Key Vault.

### Reliability (A Rating - 2 issues)

Excelente! Apenas 2 issues menores, possivelmente:
- 🔍 Configurações de retry em scripts
- 🔍 Error handling em automation scripts

### Maintainability (A Rating - 6 issues)

Código muito bem estruturado com apenas 6 code smells:
- 🔍 Comentários TODO/FIXME
- 🔍 Funções longas em scripts
- 🔍 Duplicação menor em configurações

---

## 🎯 Quality Gate

**Status:** Not Computed (primeira análise)

### Critérios do Quality Gate

- ✅ **Security Rating:** A (0 vulnerabilities)
- ⚠️ **Reliability Rating:** A-B (< 5 bugs)
- ✅ **Maintainability Rating:** A (< 10 code smells)
- ⚠️ **Security Hotspots:** 100% reviewed
- ✅ **Duplications:** < 3%
- ✅ **Coverage:** N/A (Infrastructure as Code)

**Próximo objetivo:** Passar o Quality Gate com rating A em todas as categorias.

---

## 🔍 Como Usar

### Visualizar Análise no SonarCloud

1. Acesse: https://sonarcloud.io/organizations/maringelix/projects
2. Selecione o projeto `tx02`
3. Navegue pelas abas:
   - **Overview:** Visão geral das métricas
   - **Issues:** Lista detalhada de problemas
   - **Security Hotspots:** Pontos críticos de segurança
   - **Code:** Navegação pelo código analisado
   - **Activity:** Histórico de análises

### Executar Análise Local (Opcional)

```bash
# Instalar SonarScanner
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip sonar-scanner-cli-5.0.1.3006-linux.zip

# Configurar token
export SONAR_TOKEN="seu-token-aqui"

# Executar análise
./sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner \
  -Dsonar.organization=maringelix \
  -Dsonar.projectKey=tx02 \
  -Dsonar.sources=. \
  -Dsonar.host.url=https://sonarcloud.io \
  -Dsonar.login=$SONAR_TOKEN
```

---

## 📊 Monitoramento Contínuo

### Badges no README

Adicionar ao README.md:

```markdown
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=tx02&metric=alert_status)](https://sonarcloud.io/dashboard?id=tx02)
[![Security](https://sonarcloud.io/api/project_badges/measure?project=tx02&metric=security_rating)](https://sonarcloud.io/dashboard?id=tx02)
[![Reliability](https://sonarcloud.io/api/project_badges/measure?project=tx02&metric=reliability_rating)](https://sonarcloud.io/dashboard?id=tx02)
[![Maintainability](https://sonarcloud.io/api/project_badges/measure?project=tx02&metric=sqale_rating)](https://sonarcloud.io/dashboard?id=tx02)
```

### Integração com Pull Requests

SonarCloud analisa automaticamente pull requests e fornece:
- ✅ Comentários inline no código
- ✅ Status check no GitHub
- ✅ Comparação com branch principal
- ✅ Bloqueio de merge se Quality Gate falhar (opcional)

---

## 🎓 Próximos Passos

1. **Resolver Security Issues (C → A)**
   - Remover hardcoded secrets de exemplos
   - Implementar Azure Key Vault references
   - Ajustar IAM policies para least privilege

2. **Review Security Hotspots (E → A)**
   - Revisar 100% dos hotspots identificados
   - Marcar como "safe" ou corrigir

3. **Automatizar Análise**
   - Adicionar workflow do SonarCloud
   - Configurar análise em PRs
   - Bloquear merge se Quality Gate falhar

4. **Manter Qualidade**
   - Monitorar novas issues a cada commit
   - Revisar relatórios semanalmente
   - Manter ratings A em todas as categorias

---

## 🔗 Links Úteis

- **SonarCloud Dashboard:** https://sonarcloud.io/organizations/maringelix/projects
- **SonarCloud Docs:** https://docs.sonarcloud.io/
- **Terraform Plugin:** https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/languages/terraform/
- **Quality Gate Docs:** https://docs.sonarcloud.io/improving/quality-gates/

---

**Última atualização:** 18/12/2025
