# Security Scanning - TX02

Documentação completa das ferramentas de segurança implementadas no projeto TX02.

## 📋 Índice

- [Trivy - Container Security Scanner](#trivy---container-security-scanner)
- [OPA Gatekeeper - Policy Enforcement](#opa-gatekeeper---policy-enforcement)
- [Workflow Integration](#workflow-integration)
- [Security Best Practices](#security-best-practices)

---

## 🔍 Trivy - Container Security Scanner

### Visão Geral

**Trivy** é um scanner de vulnerabilidades open-source da Aqua Security que analisa:
- 🐳 Container images (CVEs em pacotes do OS e dependências de aplicação)
- 📦 Filesystem e rootfs
- 🗂️ Infrastructure as Code (Terraform, Kubernetes, Dockerfile)
- ⚙️ Configurações (misconfigurations)

### Implementação no TX02

Trivy está integrado no workflow `docker-build.yml` do repositório **DX02** (aplicação).

**Arquivo:** `.github/workflows/docker-build.yml`

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'

- name: Upload Trivy results to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: 'trivy-results.sarif'

- name: Run Trivy vulnerability scanner (table output)
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main
    format: 'table'
    severity: 'CRITICAL,HIGH,MEDIUM'
```

### Como Funciona

1. **Build da Imagem:** Docker image é construída pelo workflow
2. **Scan Automático:** Trivy analisa a imagem após o build
3. **Detecção de Vulnerabilidades:** Identifica CVEs em:
   - Pacotes do sistema operacional (Alpine, Ubuntu, etc.)
   - Dependências do Node.js (npm packages)
   - Bibliotecas nativas
4. **Relatório SARIF:** Gera relatório em formato SARIF
5. **Upload para GitHub:** Resultados aparecem na aba **Security > Code Scanning**
6. **Output na Console:** Mostra tabela com vulnerabilidades no log do workflow

### Níveis de Severidade

| Severidade | Descrição | Ação |
|------------|-----------|------|
| **CRITICAL** | Vulnerabilidades críticas, exploração imediata | ⛔ Bloqueia deploy (deve ser corrigido) |
| **HIGH** | Vulnerabilidades graves, alto risco | ⚠️ Alerta forte (recomenda correção) |
| **MEDIUM** | Vulnerabilidades médias | 📊 Monitoramento |
| **LOW** | Vulnerabilidades baixas | 📝 Informacional |

### Exemplo de Output

```
Total: 15 (CRITICAL: 2, HIGH: 5, MEDIUM: 8, LOW: 0)

┌─────────────────┬──────────────────┬──────────┬───────────────────┬───────────────┬────────────────────────────────┐
│     Library     │  Vulnerability   │ Severity │ Installed Version │ Fixed Version │             Title              │
├─────────────────┼──────────────────┼──────────┼───────────────────┼───────────────┼────────────────────────────────┤
│ express         │ CVE-2024-XXXXX   │ CRITICAL │ 4.18.2            │ 4.19.0        │ express: denial of service     │
│ node            │ CVE-2024-YYYYY   │ HIGH     │ 20.10.0           │ 20.11.1       │ node: buffer overflow          │
└─────────────────┴──────────────────┴──────────┴───────────────────┴───────────────┴────────────────────────────────┘
```

### Visualização no GitHub

1. Acesse: **Repository → Security → Code scanning**
2. Filtre por: **Tool: Trivy**
3. Veja detalhes de cada CVE:
   - Descrição da vulnerabilidade
   - CVSS score
   - Links para CVE database
   - Recomendações de fix

### Correção de Vulnerabilidades

#### 1. Atualizar Dependências
```bash
# Node.js packages
cd server
npm audit fix
npm update

# Rebuild image
docker build -t dx02:latest .
```

#### 2. Atualizar Base Image
```dockerfile
# Antes
FROM node:20-alpine

# Depois (versão mais recente)
FROM node:20.11-alpine3.19
```

#### 3. Remover Pacotes Desnecessários
```dockerfile
# Usar multi-stage builds
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
```

---

## 🔐 OPA Gatekeeper - Policy Enforcement

### Visão Geral

**OPA Gatekeeper** é uma ferramenta de policy enforcement para Kubernetes baseada no Open Policy Agent (OPA). Permite definir e aplicar políticas de segurança usando a linguagem Rego.

### Implementação no TX02

OPA Gatekeeper está instalado no cluster AKS com 3 policies principais.

### Políticas Implementadas

#### 1. **Require Labels** ✅ (Dryrun)

**Objetivo:** Garantir que todos os recursos tenham labels obrigatórias para rastreabilidade.

**Recursos afetados:** Deployments, StatefulSets, Services, Pods  
**Namespace:** `dx02`  
**Enforcement:** `dryrun` (alerta, não bloqueia)

**Label obrigatória:**
- `app`: Nome da aplicação (regex: `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`)

**Exemplo:**
```yaml
metadata:
  labels:
    app: dx02  # ✅ Obrigatório
```

#### 2. **Deny Privileged Containers** 🚫 (Deny)

**Objetivo:** Bloquear containers privilegiados (security best practice).

**Recursos afetados:** Pods, Deployments, StatefulSets  
**Escopo:** Todos os namespaces (exceto `kube-system`, `gatekeeper-system`, `monitoring`)  
**Enforcement:** `deny` (bloqueia criação)

**Exemplo de bloqueio:**
```yaml
securityContext:
  privileged: true  # ❌ BLOQUEADO
```

#### 3. **Require Resource Limits** ⚡ (Dryrun)

**Objetivo:** Garantir que containers definam resource limits e requests.

**Recursos afetados:** Deployments, StatefulSets  
**Namespace:** `dx02`  
**Enforcement:** `dryrun` (alerta, não bloqueia)

**Recursos obrigatórios:**
- CPU (limits e requests)
- Memory (limits e requests)

**Exemplo:**
```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "250m"
    memory: "256Mi"
```

### Instalação

```powershell
# Executar script automatizado
.\install-gatekeeper.ps1
```

Ou manualmente:
```powershell
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace
kubectl apply -f k8s/policies/ -R
```

### Verificação

```powershell
# Ver constraint templates
kubectl get constrainttemplates

# Ver constraints aplicadas
kubectl get constraints --all-namespaces

# Ver violações de uma constraint
kubectl describe k8srequiredlabels require-app-label
```

### Modos de Enforcement

| Modo | Comportamento | Uso |
|------|---------------|-----|
| **deny** | Bloqueia criação/atualização | Políticas críticas (privileged containers) |
| **dryrun** | Permite mas registra violação | Auditoria, gradual rollout |
| **warn** | Permite com warning | Políticas informativas |

---

## 🔄 Workflow Integration

### CI/CD Pipeline com Security

```
┌─────────────────────────────────────────────────────────┐
│                   GitHub Actions                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. Code Push → Trigger Workflow                        │
│  2. Checkout Code                                        │
│  3. Build Docker Image                                   │
│  4. ► Trivy Scan (CRITICAL/HIGH vulnerabilities)        │
│     ├─ Pass → Continue                                   │
│     └─ Fail → Workflow fails, block deploy              │
│  5. Push to ACR (if scan passed)                        │
│  6. Deploy to AKS                                        │
│  7. ► OPA Gatekeeper validates:                         │
│     ├─ Privileged containers → DENY                     │
│     ├─ Missing labels → WARN (dryrun)                   │
│     └─ Missing resources → WARN (dryrun)                │
│  8. Pod running ✅                                       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Security Checkpoints

1. **Before Build:** SonarCloud analisa código (SAST)
2. **After Build:** Trivy scan imagem (CVE scanning)
3. **Before Deploy:** GitHub Actions valida manifests
4. **During Deploy:** OPA Gatekeeper valida pods
5. **Runtime:** Azure Security Center monitora (se habilitado)

---

## 🛡️ Security Best Practices

### Container Security

✅ **Use imagens oficiais e mínimas:**
```dockerfile
# Preferir Alpine ou Distroless
FROM node:20-alpine
# ou
FROM gcr.io/distroless/nodejs20-debian12
```

✅ **Não rode como root:**
```dockerfile
USER node
```

✅ **Multi-stage builds:**
```dockerfile
FROM node:20-alpine AS builder
# Build stage

FROM node:20-alpine
COPY --from=builder /app /app
```

✅ **Scan regularmente:**
```bash
# Local scan
trivy image tx02prdacr.azurecr.io/dx02:main
```

### Kubernetes Security

✅ **Defina resource limits:**
```yaml
resources:
  limits:
    cpu: "1000m"
    memory: "1Gi"
  requests:
    cpu: "500m"
    memory: "512Mi"
```

✅ **Use SecurityContext:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
```

✅ **Network Policies:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dx02-netpol
spec:
  podSelector:
    matchLabels:
      app: dx02
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: sql-server
```

---

## 📊 Security Metrics

### Trivy Scan Results (Exemplo)

| Build | Date | Critical | High | Medium | Status |
|-------|------|----------|------|--------|--------|
| #125 | 19/12/2025 | 0 | 2 | 8 | ✅ Passed |
| #124 | 18/12/2025 | 1 | 3 | 12 | ❌ Failed |
| #123 | 17/12/2025 | 0 | 1 | 5 | ✅ Passed |

### Gatekeeper Audit (Exemplo)

| Policy | Violations | Status |
|--------|------------|--------|
| Require Labels | 0 | ✅ Clean |
| Deny Privileged | 0 | ✅ Clean |
| Require Resources | 5 | ⚠️ Dryrun (5 pods sem limits) |

---

## 🔗 Links Úteis

- **Trivy:** https://trivy.dev/
- **Trivy GitHub:** https://github.com/aquasecurity/trivy
- **OPA Gatekeeper:** https://open-policy-agent.github.io/gatekeeper/
- **Gatekeeper Library:** https://github.com/open-policy-agent/gatekeeper-library
- **CIS Benchmarks:** https://www.cisecurity.org/benchmark/kubernetes

---

**Última atualização:** 19/12/2025
