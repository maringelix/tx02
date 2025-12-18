# Configuração de Alertas no Slack

## ✅ Status Atual

O Alertmanager está **rodando e funcional**, mas os alertas do Slack estão **desabilitados** para evitar erros de configuração.

```
alertmanager-kube-prometheus-stack-alertmanager-0   2/2   Running
```

## 🔔 Como Habilitar Alertas no Slack

### 1. Criar Webhook do Slack

1. Acesse: https://api.slack.com/apps
2. **Create New App** → From scratch
3. Nome: `DX02 Alerts` | Workspace: Seu workspace
4. **Incoming Webhooks** → Activate
5. **Add New Webhook to Workspace**
6. Selecionar canal: `#dx02-alerts`
7. Copiar Webhook URL (ex: `https://hooks.slack.com/services/TXXXXXX/BXXXXXX/XXXXXXXXXXXXXXX`)

### 2. Adicionar Webhook nos GitHub Secrets

```bash
# No repositório TX02 no GitHub:
Settings → Secrets and variables → Actions → New repository secret

Name: SLACK_WEBHOOK_URL
Value: https://hooks.slack.com/services/TXXXXXX/BXXXXXX/XXXXXXXXXXXXXXX
```

### 3. Atualizar prometheus-values.yaml

Edite `k8s/observability/prometheus-values.yaml`:

```yaml
# Alertmanager Configuration
alertmanager:
  enabled: true
  
  config:
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/TXXXXXX/BXXXXXX/XXXXXXXXXXXXXXX'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack-notifications'
      routes:
      - match:
          alertname: Watchdog
        receiver: 'null'
      - match:
          severity: critical
        receiver: 'slack-critical'
        continue: true
      - match:
          severity: warning
        receiver: 'slack-notifications'
        continue: true
    
    receivers:
    - name: 'null'
    
    - name: 'slack-notifications'
      slack_configs:
      - channel: '#dx02-alerts'
        title: '{{ .Status | toUpper }} - DX02 Alert'
        text: |
          *Alert:* {{ .CommonLabels.alertname }}
          *Severity:* {{ .CommonLabels.severity }}
          *Summary:* {{ .CommonAnnotations.summary }}
          *Description:* {{ .CommonAnnotations.description }}
          *Cluster:* tx02-prd-aks
          *Namespace:* {{ .CommonLabels.namespace }}
        send_resolved: true
    
    - name: 'slack-critical'
      slack_configs:
      - channel: '#dx02-critical'
        title: ':fire: CRITICAL ALERT - DX02'
        text: |
          <!channel>
          *Alert:* {{ .CommonLabels.alertname }}
          *Severity:* CRITICAL
          *Summary:* {{ .CommonAnnotations.summary }}
          *Description:* {{ .CommonAnnotations.description }}
          *Cluster:* tx02-prd-aks
        send_resolved: true
```

### 4. Aplicar Configuração

**Via Workflow (Recomendado)**:
```
Actions → 📊 Deploy Observability Stack → Run workflow
Input: Cole seu Slack Webhook URL
```

**Via Helm Local**:
```powershell
cd C:\Files\Learn\Projetos\tx01\tx02

helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values k8s/observability/prometheus-values.yaml
```

## 🧪 Testar Alertas

### 1. Forçar Alerta de Pod Down

```powershell
# Deletar pod do DX02 para gerar alerta
kubectl delete pod -n dx02 -l app=dx02
```

Após 5 minutos, deve receber alerta no Slack:

```
🔴 FIRING - DX02 Alert

Alert: DX02PodDown
Severity: critical
Summary: DX02 pod is down
Description: DX02 pod has been down for more than 5 minutes
Cluster: tx02-prd-aks
Namespace: dx02
```

### 2. Ver Alertas Ativos

```powershell
# Port-forward Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

Acesse: **http://localhost:9093**

### 3. Ver Regras no Prometheus

```powershell
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Acesse: **http://localhost:9090/alerts**

## 📊 Regras de Alerta Configuradas

### 1. DX02PodDown (Critical)
- **Condição**: Pod não está running por > 5min
- **Canal**: #dx02-critical

### 2. DX02HighErrorRate (Critical)
- **Condição**: Taxa de erro > 5% por 5min
- **Canal**: #dx02-critical

### 3. DX02SlowResponse (Warning)
- **Condição**: Tempo de resposta > 1s por 10min
- **Canal**: #dx02-alerts

### 4. DX02HighMemory (Warning)
- **Condição**: Uso de memória > 80% por 10min
- **Canal**: #dx02-alerts

### 5. DX02HighCPU (Warning)
- **Condição**: Uso de CPU > 80% por 10min
- **Canal**: #dx02-alerts

### 6. DX02DatabaseConnection (Critical)
- **Condição**: Erro de conexão com database
- **Canal**: #dx02-critical

## 🔧 Troubleshooting

### Alertmanager não está enviando alertas

```powershell
# Verificar logs
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager

# Verificar configuração
kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o yaml
```

### Webhook URL inválida

Erro: `unsupported scheme "" for URL`

**Solução**: Certifique-se que o Slack webhook está no formato correto:
```
https://hooks.slack.com/services/TXXXXXX/BXXXXXX/XXXXXXXXXXXXXXX
```

### Alertas não estão disparando

1. Verificar regras no Prometheus: http://localhost:9090/alerts
2. Verificar ServiceMonitor: `kubectl get servicemonitor -n monitoring`
3. Verificar se métricas estão sendo coletadas: http://localhost:9090/targets

## 📝 Configuração Atual (Sem Slack)

Por padrão, o Alertmanager está configurado com receiver `null` (sem notificações) para garantir que rode sem erros.

**Para habilitar Slack**: Siga os passos 1-4 acima.

---

**Status**: ⏳ Alertmanager funcional, Slack não configurado  
**Próximo passo**: Adicionar SLACK_WEBHOOK_URL e atualizar values.yaml
