# Observability Stack - DX02

## 🎯 Overview

Complete observability solution for DX02 application running on Azure AKS using:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and notifications to Slack

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  monitoring namespace                    │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │         kube-prometheus-stack                    │   │
│  │                                                   │   │
│  │  ┌────────────┐  ┌────────────┐  ┌───────────┐  │   │
│  │  │ Prometheus │  │  Grafana   │  │Alertmgr   │  │   │
│  │  │            │  │            │  │           │  │   │
│  │  │ :9090      │  │ :80        │  │ :9093     │  │   │
│  │  └────────────┘  └────────────┘  └───────────┘  │   │
│  │         │                │              │        │   │
│  │         └────────────────┴──────────────┘        │   │
│  │                      │                           │   │
│  │           ┌──────────┴──────────┐                │   │
│  │           │  ServiceMonitor     │                │   │
│  │           │  (dx02-monitor)     │                │   │
│  │           └─────────────────────┘                │   │
│  └──────────────────────────────────────────────────┘   │
│                       │                                  │
└───────────────────────┼──────────────────────────────────┘
                        │
                        ↓
           ┌────────────────────────┐
           │    dx02 namespace      │
           │                        │
           │  ┌──────────────────┐  │
           │  │  DX02 Pods       │  │
           │  │  Port: 3000      │  │
           │  │  /api/health     │  │
           │  └──────────────────┘  │
           └────────────────────────┘
                        │
                        ↓
                ┌───────────────┐
                │  Slack        │
                │  #dx02-alerts │
                └───────────────┘
```

## 🚀 Deployment

### Option 1: GitHub Actions Workflow (Recommended)

1. **Set GitHub Secrets** (if not already set):
   ```
   SLACK_WEBHOOK_URL          # Your Slack webhook URL
   GRAFANA_ADMIN_PASSWORD     # Optional, defaults to "admin"
   ```

2. **Run Workflow**:
   - Go to Actions → Deploy Observability Stack
   - Click "Run workflow"
   - Optionally provide Slack webhook URL
   - Wait ~5 minutes for deployment

### Option 2: Manual Installation (PowerShell)

```powershell
# Set Slack webhook (optional)
$env:SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Run installation script
.\install-observability.ps1
```

### Option 3: Manual Installation (kubectl + helm)

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install stack
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values k8s/observability/prometheus-values.yaml \
  --set grafana.adminPassword=admin \
  --timeout=10m \
  --wait

# Deploy ServiceMonitor
kubectl apply -f k8s/observability/servicemonitor.yaml

# Deploy Grafana Dashboard
kubectl apply -f k8s/observability/grafana-dashboard.yaml
```

## 📈 Accessing Dashboards

### Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open: http://localhost:3000
- **Username**: `admin`
- **Password**: `admin` (or your custom password)

**Pre-configured Dashboard**: DX02 Application Dashboard

### Prometheus

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open: http://localhost:9090

**Useful Queries**:
```promql
# Application uptime
up{namespace="dx02"}

# CPU usage
rate(container_cpu_usage_seconds_total{namespace="dx02"}[5m])

# Memory usage
container_memory_working_set_bytes{namespace="dx02"}

# Pod restarts
kube_pod_container_status_restarts_total{namespace="dx02"}
```

### Alertmanager

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

Open: http://localhost:9093

## 🔔 Alerts Configuration

### Alert Rules

The stack includes custom alerts for DX02:

| Alert Name | Severity | Condition | Duration |
|------------|----------|-----------|----------|
| `DX02ApplicationDown` | Critical | Application is down | 2 minutes |
| `DX02HighMemoryUsage` | Warning | Memory > 90% | 5 minutes |
| `DX02HighCPUUsage` | Warning | CPU > 90% | 5 minutes |
| `DX02PodRestarting` | Warning | Restarts detected | 5 minutes |
| `DX02DatabaseDisconnected` | Critical | DB connection lost | 2 minutes |
| `DX02PodNotReady` | Warning | Pod not ready | 5 minutes |

### Slack Integration

**Setup**:
1. Create a Slack app at https://api.slack.com/apps
2. Enable Incoming Webhooks
3. Create webhook for `#dx02-alerts` channel
4. Set webhook URL in GitHub secrets or environment variable

**Alert Channels**:
- `#dx02-alerts` - All warnings and critical alerts
- `#dx02-critical` - Critical alerts only (with @channel mention)

**Test Alert**:
```bash
# Trigger a test alert
kubectl scale deployment dx02 --replicas=0 -n dx02

# Wait 2 minutes for DX02ApplicationDown alert
# Scale back
kubectl scale deployment dx02 --replicas=2 -n dx02
```

## 📊 Metrics Collected

### Application Metrics
- Request rate and latency (via `/api/health` endpoint)
- Database connection status
- Application uptime

### Container Metrics
- CPU usage
- Memory usage
- Network I/O
- Filesystem usage

### Kubernetes Metrics
- Pod status and restarts
- Deployment replicas
- Node resources
- Persistent volume claims

## 🔧 Configuration

### Prometheus Storage

**Default**: 10Gi Azure Managed Disk (managed-csi)
**Retention**: 7 days
**Size Limit**: 5GB

**Adjust storage**:
```yaml
# Edit k8s/observability/prometheus-values.yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 20Gi  # Increase size
```

### Grafana Persistence

**Default**: 5Gi Azure Managed Disk
**Enabled**: Yes

**Disable persistence** (for testing):
```yaml
grafana:
  persistence:
    enabled: false
```

### Resource Limits

**Prometheus**:
- Requests: 512Mi RAM, 200m CPU
- Limits: 2Gi RAM, 1000m CPU

**Grafana**:
- Requests: 256Mi RAM, 100m CPU
- Limits: 512Mi RAM, 500m CPU

**Adjust** in `k8s/observability/prometheus-values.yaml`

## 🧹 Maintenance

### View Logs

```bash
# Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=50

# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50

# Alertmanager logs
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=50
```

### Check Resource Usage

```bash
# Pods
kubectl top pods -n monitoring

# Nodes
kubectl top nodes

# PVCs
kubectl get pvc -n monitoring
```

### Update Stack

```bash
helm upgrade kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values k8s/observability/prometheus-values.yaml \
  --reuse-values
```

### Uninstall

**Via GitHub Actions**:
- Run "Deploy Observability Stack" workflow
- Check "Destroy stack instead of deploy"

**Via Helm**:
```bash
helm uninstall kube-prometheus-stack -n monitoring
kubectl delete namespace monitoring
```

## 🔍 Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n monitoring

# Describe failing pod
kubectl describe pod <pod-name> -n monitoring

# Check events
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

### Slack Alerts Not Working

1. **Verify webhook URL**:
   ```bash
   kubectl get secret alertmanager-config -n monitoring -o yaml
   ```

2. **Test webhook manually**:
   ```bash
   curl -X POST "YOUR_WEBHOOK_URL" \
     -H 'Content-Type: application/json' \
     -d '{"text": "Test alert from DX02"}'
   ```

3. **Check Alertmanager logs**:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager
   ```

### Metrics Not Showing

1. **Check ServiceMonitor**:
   ```bash
   kubectl get servicemonitor -n monitoring dx02-monitor -o yaml
   ```

2. **Verify endpoint is scrapable**:
   ```bash
   kubectl port-forward -n dx02 svc/dx02-metrics 3000:3000
   curl http://localhost:3000/api/health
   ```

3. **Check Prometheus targets**:
   - Go to Prometheus UI → Status → Targets
   - Look for `dx02-application` job

### Grafana Login Issues

**Reset password**:
```bash
kubectl exec -n monitoring \
  deployment/kube-prometheus-stack-grafana -- \
  grafana-cli admin reset-admin-password newpassword
```

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)

## 🎯 Next Steps

- [ ] Create custom Grafana dashboards for specific metrics
- [ ] Add PagerDuty integration for critical alerts
- [ ] Configure alert silencing rules
- [ ] Set up log aggregation (ELK/Loki)
- [ ] Implement distributed tracing (Jaeger/Tempo)
- [ ] Add cost monitoring dashboards

---

**Maintained by**: DX02 DevOps Team  
**Last Updated**: December 18, 2025  
**Version**: 1.0.0
