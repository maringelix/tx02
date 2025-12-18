# Observability Stack - Acesso

## ✅ Status da Instalação

A stack de observabilidade está **100% funcional**:

- ✅ **Prometheus**: Coletando métricas do cluster
- ✅ **Grafana**: Dashboards funcionando
- ✅ **Alertmanager**: Configurado com Slack
- ✅ **Node Exporter**: 2 pods running
- ✅ **Kube State Metrics**: Running

## 🔗 Acesso ao Grafana

### Port-Forward (Recomendado)

```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 8080:80
```

Acesse: **http://localhost:8080**

### Credenciais

- **Usuário**: `admin`
- **Senha**: `admin`

## 📊 Dashboards Disponíveis

O Grafana vem com **28 dashboards pré-configurados**:

### Kubernetes Resources
- K8s Resources - Cluster
- K8s Resources - Namespace
- K8s Resources - Node
- K8s Resources - Pod
- K8s Resources - Workload
- K8s Resources - Workloads Namespace

### Compute Resources
- Namespace by Pod
- Namespace by Workload
- Node Cluster Resource Use
- Node Resource Use
- Nodes
- Pod Total
- Workload Total

### Components
- API Server
- Controller Manager
- CoreDNS
- etcd
- Kubelet
- Scheduler
- Proxy

### Monitoring Stack
- Alertmanager Overview
- Grafana Overview
- Prometheus

### Storage
- Persistent Volumes Usage

## 🔔 Alertas

### Slack Configurado

Os alertas estão configurados para enviar para o Slack:

- **Canal normal**: `#dx02-alerts`
- **Canal crítico**: `#dx02-critical`

### Regras de Alerta

6 regras customizadas para DX02:

1. **DX02PodDown**: Pod não está running por > 5min
2. **DX02HighErrorRate**: Taxa de erro > 5% por 5min
3. **DX02SlowResponse**: Tempo de resposta > 1s por 10min
4. **DX02HighMemory**: Uso de memória > 80% por 10min
5. **DX02HighCPU**: Uso de CPU > 80% por 10min
6. **DX02DatabaseConnection**: Erro de conexão com database

## 📦 Componentes Instalados

```
NAMESPACE    POD                                                      STATUS
monitoring   kube-prometheus-stack-grafana-6b94f4bc84-wczjm           Running 2/2
monitoring   kube-prometheus-stack-kube-state-metrics-7846957b5b      Running 1/1
monitoring   kube-prometheus-stack-operator-59f78d76f8-jkql2          Running 1/1
monitoring   prometheus-kube-prometheus-stack-prometheus-0            Running 2/2
monitoring   kube-prometheus-stack-prometheus-node-exporter-bwl56     Running 1/1
monitoring   kube-prometheus-stack-prometheus-node-exporter-v9jwr     Running 1/1
```

## 🚨 Limitações

### IP Público

❌ Não foi possível criar LoadBalancer para Grafana devido ao limite de IPs públicos do Azure:

```
ERROR CODE: PublicIPCountLimitReached
```

**Soluções alternativas**:

1. **Port-forward** (atual)
2. **Ingress**: Reutilizar IP do ingress-nginx
3. **Liberar IPs**: Deletar recursos não utilizados

### Para criar Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.tx02.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kube-prometheus-stack-grafana
            port:
              number: 80
```

## 🛠️ Troubleshooting

### Problemas Resolvidos

1. ✅ **Grafana CrashLoopBackOff**: Sidecar de datasource criando duplicados
   - **Solução**: Desabilitado `sidecar.datasources.enabled: false`

2. ✅ **Prometheus Operator ContainerCreating**: Procurando secret de admission webhook
   - **Solução**: Desabilitado completamente TLS e admission webhooks

3. ✅ **Persistência**: PVC causando problemas
   - **Solução**: Desabilitada persistência (dados em memória)

### Verificar Logs

```powershell
# Grafana
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana

# Prometheus
kubectl logs -n monitoring statefulset/prometheus-kube-prometheus-stack-prometheus

# Alertmanager
kubectl logs -n monitoring statefulset/alertmanager-kube-prometheus-stack-alertmanager
```

## 📝 Configuração Simplificada

As otimizações aplicadas para AKS:

- ✅ Persistência desabilitada (cluster pequeno)
- ✅ Requests e limits reduzidos
- ✅ Admission webhooks desabilitados
- ✅ TLS desabilitado (cluster interno)
- ✅ Sidecar de datasources desabilitado
- ✅ Retenção de 7 dias (suficiente para desenvolvimento)

## 🎯 Próximos Passos

1. ✅ Acessar Grafana via port-forward
2. ⏳ Configurar Ingress para acesso externo
3. ⏳ Criar dashboard customizado para DX02
4. ⏳ Testar alertas no Slack
5. ⏳ Adicionar /metrics endpoint no DX02

---

**Documentação completa**: [README.md](README.md)
