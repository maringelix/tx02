# OPA Gatekeeper Policies - TX02

Este diretório contém as políticas do OPA Gatekeeper implementadas no cluster AKS TX02.

## 📋 Políticas Implementadas

### 1. **Require Labels** (`K8sRequiredLabels`)
Garante que recursos Kubernetes tenham labels obrigatórias.

**Constraint:** `constraint-require-labels.yaml`  
**Template:** `constraint-template-require-labels.yaml`

- **Enforcement:** `dryrun` (apenas alerta, não bloqueia)
- **Escopo:** Namespace `dx02`
- **Recursos:** Deployments, StatefulSets, DaemonSets, Services, Pods
- **Label obrigatória:** `app`
- **Regex permitido:** `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`

**Exemplo de violação:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  # ❌ Falta label "app"
spec:
  ...
```

**Exemplo correto:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: dx02  # ✅ Label "app" presente
spec:
  ...
```

---

### 2. **Deny Privileged Containers** (`K8sPSPrivilegedContainer`)
Bloqueia a criação de containers privilegiados (security risk).

**Constraint:** `constraint-no-privileged.yaml`  
**Template:** `constraint-template-no-privileged.yaml`

- **Enforcement:** `deny` (bloqueia deployment)
- **Escopo:** Todos os namespaces (exceto `kube-system`, `gatekeeper-system`, `monitoring`)
- **Recursos:** Pods, Deployments, StatefulSets, DaemonSets

**Exemplo de violação:**
```yaml
spec:
  containers:
  - name: app
    securityContext:
      privileged: true  # ❌ BLOQUEADO
```

**Exemplo correto:**
```yaml
spec:
  containers:
  - name: app
    securityContext:
      privileged: false  # ✅ Permitido
      # ou omitir (default é false)
```

---

### 3. **Require Resource Limits/Requests** (`K8sRequireResources`)
Garante que containers definam resource limits e requests.

**Constraint:** `constraint-require-resources.yaml`  
**Template:** `constraint-template-require-resources.yaml`

- **Enforcement:** `dryrun` (apenas alerta, não bloqueia)
- **Escopo:** Namespace `dx02`
- **Recursos:** Deployments, StatefulSets, DaemonSets
- **Recursos obrigatórios:** `cpu` e `memory` (limits e requests)

**Exemplo de violação:**
```yaml
spec:
  containers:
  - name: app
    image: myapp:latest
    # ❌ Faltam resources
```

**Exemplo correto:**
```yaml
spec:
  containers:
  - name: app
    image: myapp:latest
    resources:
      limits:
        cpu: "500m"
        memory: "512Mi"
      requests:
        cpu: "250m"
        memory: "256Mi"
```

---

## 🚀 Instalação

### Método Automatizado (Recomendado)

```powershell
# Executar script de instalação
.\install-gatekeeper.ps1
```

Este script:
1. Verifica conectividade com AKS
2. Instala OPA Gatekeeper via Helm
3. Aplica todas as policies deste diretório
4. Exibe status da instalação

### Método Manual

```powershell
# 1. Adicionar repositório Helm
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update

# 2. Instalar Gatekeeper
kubectl create namespace gatekeeper-system
helm install gatekeeper gatekeeper/gatekeeper --namespace gatekeeper-system

# 3. Aguardar pods prontos
kubectl wait --for=condition=ready pod -l app=gatekeeper -n gatekeeper-system --timeout=120s

# 4. Aplicar constraint templates
kubectl apply -f k8s/policies/constraint-template-require-labels.yaml
kubectl apply -f k8s/policies/constraint-template-no-privileged.yaml
kubectl apply -f k8s/policies/constraint-template-require-resources.yaml

# 5. Aplicar constraints
kubectl apply -f k8s/policies/constraint-require-labels.yaml
kubectl apply -f k8s/policies/constraint-no-privileged.yaml
kubectl apply -f k8s/policies/constraint-require-resources.yaml
```

---

## 🔍 Verificação

### Verificar instalação
```powershell
# Verificar pods do Gatekeeper
kubectl get pods -n gatekeeper-system

# Listar constraint templates
kubectl get constrainttemplates

# Listar constraints
kubectl get constraints --all-namespaces
```

### Verificar violações
```powershell
# Ver status de uma constraint específica
kubectl describe k8srequiredlabels require-app-label

# Ver violações em formato JSON
kubectl get k8srequiredlabels require-app-label -o jsonpath='{.status.violations}'
```

### Testar policies
```powershell
# Tentar criar pod sem label (deve alertar em dryrun)
kubectl run test-pod --image=nginx --namespace=dx02

# Tentar criar pod privilegiado (deve ser bloqueado)
kubectl run privileged-pod --image=nginx --namespace=dx02 --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx","securityContext":{"privileged":true}}]}}'
```

---

## 📊 Modos de Enforcement

### `deny` (Bloqueio)
- Rejeita criação/atualização de recursos que violam a policy
- Usado para: Privileged containers
- **Efeito:** Deployment falha imediatamente

### `dryrun` (Auditoria)
- Permite criação mas registra violação
- Usado para: Labels obrigatórias, Resource limits
- **Efeito:** Deployment funciona, mas violação é registrada

### `warn` (Aviso)
- Permite criação mas mostra warning
- **Efeito:** Deployment funciona, usuário vê aviso

---

## 🎯 Próximos Passos

### Policies Recomendadas

1. **Container Image Registry**
   - Permitir apenas imagens de registries aprovados (ACR)
   
2. **Require Liveness/Readiness Probes**
   - Garantir health checks em todos os containers

3. **Ingress HTTPS Only**
   - Bloquear Ingress sem TLS

4. **Resource Quotas**
   - Limitar recursos máximos por namespace

5. **Host Network/IPC/PID**
   - Bloquear uso de host network/IPC/PID

### Exemplo: Allowed Registries

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-container-registries
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    repos:
      - "tx02prdacr.azurecr.io"
      - "mcr.microsoft.com"
```

---

## 📚 Documentação Oficial

- **OPA Gatekeeper:** https://open-policy-agent.github.io/gatekeeper/
- **Policy Library:** https://github.com/open-policy-agent/gatekeeper-library
- **Rego Language:** https://www.openpolicyagent.org/docs/latest/policy-language/

---

## 🔧 Troubleshooting

### Gatekeeper não está bloqueando violações

```powershell
# Verificar se webhook está configurado
kubectl get validatingwebhookconfigurations | Select-String gatekeeper

# Verificar logs do Gatekeeper
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

### Constraint não está aplicando

```powershell
# Verificar status da constraint
kubectl describe k8spsprivilegedcontainer deny-privileged-containers

# Verificar se constraint template foi aplicado
kubectl get constrainttemplate k8spsprivilegedcontainer
```

### Remover Gatekeeper

```powershell
# Deletar todas as constraints
kubectl delete constraints --all

# Deletar constraint templates
kubectl delete constrainttemplates --all

# Desinstalar Helm release
helm uninstall gatekeeper -n gatekeeper-system

# Deletar namespace
kubectl delete namespace gatekeeper-system
```

---

**Última atualização:** 19/12/2025
