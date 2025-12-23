# 🚀 ArgoCD - GitOps para Kubernetes

## 📋 Visão Geral

O ArgoCD é uma ferramenta declarativa de continuous delivery para Kubernetes que segue os princípios GitOps. Ele automatiza o deployment de aplicações mantendo o cluster sincronizado com os manifestos Git.

### 🎯 Características Principais

- **GitOps Nativo**: Source of truth no Git
- **UI Web Intuitiva**: Interface visual para gerenciar deployments
- **Auto-Sync**: Sincronização automática com o repositório
- **Self-Healing**: Recuperação automática de divergências
- **Rollback Fácil**: Reverter para qualquer commit anterior
- **Multi-Cluster**: Gerenciar múltiplos clusters K8s
- **SSO Integration**: Integração com OIDC, SAML, GitHub, GitLab
- **RBAC**: Controle de acesso granular
- **Health Assessment**: Validação de saúde das aplicações

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                     Git Repository                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  dx02/k8s  │  │  aether/   │  │  configs/  │        │
│  │ manifests  │  │  manifests │  │   helm     │        │
│  └────────────┘  └────────────┘  └────────────┘        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Poll/Webhook
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   ArgoCD Namespace                       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │          ArgoCD Application Controller           │  │
│  │  • Monitors Git repo for changes                 │  │
│  │  • Compares desired vs actual state              │  │
│  │  • Triggers sync operations                      │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │              ArgoCD API Server                   │  │
│  │  • REST API & gRPC                               │  │
│  │  • Web UI (LoadBalancer: External IP)            │  │
│  │  • CLI interface                                 │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │            ArgoCD Repo Server                    │  │
│  │  • Git repository caching                        │  │
│  │  • Manifest generation (Helm, Kustomize, etc)    │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │         ArgoCD Notifications Controller          │  │
│  │  • Slack, email, webhook notifications           │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Apply manifests
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (AKS)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │   dx02   │  │  aether  │  │ monitoring│             │
│  │namespace │  │namespace │  │ namespace │             │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
```

## 🔧 Instalação

### Automática (via GitHub Actions)

```bash
# Executar workflow
gh workflow run setup-argocd.yml

# Com senha customizada
gh workflow run setup-argocd.yml -f admin_password="SuaSenhaSegura123!"
```

### Manual

```bash
# 1. Criar namespace
kubectl create namespace argocd

# 2. Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.3/manifests/install.yaml

# 3. Expor via LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 4. Obter senha inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 🌐 Acesso

### Web UI

```bash
# Obter IP público
kubectl get svc argocd-server-external -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Acesse: http://<IP_PUBLICO>
# Username: admin
# Password: <obtida no passo 4 acima>
```

### CLI

```bash
# Instalar ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login <IP_PUBLICO> --username admin --password <senha>

# Listar aplicações
argocd app list

# Ver status
argocd app get dx02

# Sincronizar manualmente
argocd app sync dx02
```

## 📦 Aplicações Configuradas

### DX02 Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dx02
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/maringelix/tx02.git
    targetRevision: main
    path: dx02/k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: dx02
  syncPolicy:
    automated:
      prune: true        # Remove recursos deletados do Git
      selfHeal: true     # Corrige drift automático
      allowEmpty: false  # Previne sync de diretório vazio
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Características:**
- ✅ Auto-sync habilitado
- ✅ Self-healing ativo
- ✅ Prune automático
- ✅ Retry com backoff exponencial

## 🔄 Workflows GitOps

### 1. Deploy Normal (Auto-Sync)

```bash
# 1. Fazer mudanças nos manifestos K8s
vim dx02/k8s/deployment.yaml

# 2. Commit e push
git add dx02/k8s/deployment.yaml
git commit -m "feat: update dx02 deployment replicas to 3"
git push origin main

# 3. ArgoCD detecta mudança (polling ou webhook)
# 4. ArgoCD aplica automaticamente no cluster
# 5. Verificar na UI ou CLI
argocd app get dx02
```

### 2. Deploy Manual (Sync Disabled)

```bash
# 1. Desabilitar auto-sync
kubectl patch app dx02 -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'

# 2. Fazer mudanças e push
git add . && git commit -m "feat: new feature" && git push

# 3. Sincronizar manualmente via UI ou CLI
argocd app sync dx02

# 4. Reabilitar auto-sync
kubectl patch app dx02 -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

### 3. Rollback

```bash
# Via UI: History → Select commit → Rollback

# Via CLI
argocd app rollback dx02 <revision-number>

# Ver histórico
argocd app history dx02
```

## 🎛️ Configurações Avançadas

### Webhooks (GitHub)

Configure webhook para sync instantâneo:

1. **GitHub**: Settings → Webhooks → Add webhook
2. **Payload URL**: `http://<ARGOCD_IP>/api/webhook`
3. **Content type**: `application/json`
4. **Secret**: (opcional) configure em ArgoCD
5. **Events**: `Just the push event`

### Notificações (Slack)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} deployed to {{.app.spec.destination.namespace}}
      Repository: {{.app.spec.source.repoURL}}
      Revision: {{.app.status.sync.revision}}
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
```

### Multi-Cluster

```bash
# Adicionar cluster remoto
argocd cluster add <context-name>

# Listar clusters
argocd cluster list

# Deploy para cluster específico
# Modificar .spec.destination.server na Application
```

## 📊 Monitoramento

### Health Status

ArgoCD avalia a saúde dos recursos:
- ✅ **Healthy**: Recurso operacional
- ⚠️ **Progressing**: Em progresso
- ⚠️ **Suspended**: Suspenso intencionalmente
- ❌ **Degraded**: Problema detectado
- ❓ **Missing**: Recurso não encontrado
- ❓ **Unknown**: Status desconhecido

### Sync Status

- ✅ **Synced**: Cluster = Git
- ⚠️ **OutOfSync**: Drift detectado
- ❓ **Unknown**: Não comparado ainda

### Métricas Prometheus

ArgoCD expõe métricas em `/metrics`:

```yaml
# Service Monitor para Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  endpoints:
  - port: metrics
```

**Métricas importantes:**
- `argocd_app_sync_total`: Total de syncs
- `argocd_app_health_status`: Status de saúde
- `argocd_app_sync_duration_seconds`: Duração do sync

## 🔒 Segurança

### RBAC

```yaml
# argocd-rbac-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Developer role
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    g, developer-team, role:developer
    
    # Admin role (full access)
    p, role:admin, *, *, */*, allow
    g, admin-team, role:admin
```

### SSO (GitHub)

```yaml
# argocd-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
    - type: github
      id: github
      name: GitHub
      config:
        clientID: <github-oauth-client-id>
        clientSecret: <github-oauth-client-secret>
        orgs:
        - name: your-org
```

## 🛠️ Troubleshooting

### App OutOfSync

```bash
# Ver diferenças
argocd app diff dx02

# Forçar sync
argocd app sync dx02 --force

# Ver logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Sync Falha

```bash
# Ver detalhes do erro
argocd app get dx02

# Ver eventos
kubectl get events -n dx02 --sort-by='.lastTimestamp'

# Logs do repo-server (problemas de Git/Helm)
kubectl logs -n argocd deployment/argocd-repo-server
```

### Refresh Repository

```bash
# Forçar refresh
argocd app get dx02 --refresh

# Hard refresh (limpa cache)
argocd app get dx02 --hard-refresh
```

## 📚 Recursos Adicionais

- [Documentação Oficial](https://argo-cd.readthedocs.io/)
- [Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD Autopilot](https://argocd-autopilot.readthedocs.io/)
- [ApplicationSets](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [GitOps Patterns](https://www.gitops.tech/)

## 🎓 Próximos Passos

- [ ] Configurar ApplicationSets para multi-ambiente
- [ ] Implementar Progressive Delivery (Argo Rollouts)
- [ ] Configurar Sync Waves para ordem de deploy
- [ ] Integrar Argo Events para event-driven workflows
- [ ] Configurar Argo Image Updater para auto-update de imagens
- [ ] Implementar disaster recovery com Velero
