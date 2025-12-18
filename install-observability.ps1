# Azure Observability Stack Installation
# Prometheus + Grafana + Alertmanager for AKS

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Azure AKS Observability Stack" -ForegroundColor Cyan
Write-Host "Prometheus + Grafana + Alerts" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Prerequisites check
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (!(Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: helm not found" -ForegroundColor Red
    Write-Host "Install from: https://github.com/helm/helm/releases" -ForegroundColor Yellow
    exit 1
}

if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: kubectl not found" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Helm and kubectl found" -ForegroundColor Green
Write-Host ""

# Check cluster connectivity
Write-Host "Checking AKS cluster connectivity..." -ForegroundColor Yellow
$clusterInfo = kubectl cluster-info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Cannot connect to AKS cluster" -ForegroundColor Red
    Write-Host "Run: az aks get-credentials --resource-group <rg> --name tx02-prd-aks" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Connected to AKS cluster" -ForegroundColor Green
Write-Host ""

# Check cluster capacity
Write-Host "Checking cluster capacity..." -ForegroundColor Yellow
$nodes = kubectl get nodes --no-headers 2>$null
$nodeCount = ($nodes | Measure-Object).Count
$readyNodes = ($nodes | Select-String "Ready" | Measure-Object).Count

Write-Host "Nodes: $nodeCount (Ready: $readyNodes)" -ForegroundColor White

$allPods = kubectl get pods -A --no-headers --field-selector=status.phase!=Succeeded,status.phase!=Failed 2>$null
$totalPods = ($allPods | Measure-Object).Count
$maxPods = $readyNodes * 30  # Azure AKS default is 30 pods per node
$freeSlots = $maxPods - $totalPods

Write-Host "Pods: $totalPods / $maxPods (Free: $freeSlots)" -ForegroundColor White

if ($freeSlots -lt 10) {
    Write-Host "WARNING: Low capacity (need 10+ free slots)" -ForegroundColor Yellow
    Write-Host "Observability stack needs ~6-8 pods" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne "y") {
        exit 1
    }
}
Write-Host "✅ Sufficient capacity" -ForegroundColor Green
Write-Host ""

# Add Helm repository
Write-Host "Adding Helm repository..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>$null | Out-Null
helm repo update | Out-Null
Write-Host "✅ Helm repo added and updated" -ForegroundColor Green
Write-Host ""

# Create namespace
Write-Host "Creating monitoring namespace..." -ForegroundColor Yellow
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - | Out-Null
Write-Host "✅ Namespace created" -ForegroundColor Green
Write-Host ""

# Check if Slack webhook is configured
$slackWebhook = $env:SLACK_WEBHOOK_URL
if ([string]::IsNullOrEmpty($slackWebhook)) {
    Write-Host "WARNING: SLACK_WEBHOOK_URL not set" -ForegroundColor Yellow
    Write-Host "Slack alerts will not work" -ForegroundColor Yellow
    Write-Host "Set via: `$env:SLACK_WEBHOOK_URL='https://hooks.slack.com/...'" -ForegroundColor White
    Write-Host ""
    $slackWebhook = "https://hooks.slack.com/services/PLACEHOLDER/REPLACE/ME"
}

# Create Alertmanager config secret
Write-Host "Creating Alertmanager configuration..." -ForegroundColor Yellow
@"
global:
  resolve_timeout: 5m
  slack_api_url: '$slackWebhook'

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
    receiver: 'slack-notifications'
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
    title: '{{ .Status | toUpper }}{{ if eq .Status "firing" }} :fire:{{ else }} :white_check_mark:{{ end }}'
    text: >-
      *Alert:* {{ .CommonLabels.alertname }}
      
      *Severity:* {{ .CommonLabels.severity }}
      
      *Summary:* {{ .CommonAnnotations.summary }}
      
      *Description:* {{ .CommonAnnotations.description }}
      
      *Cluster:* tx02-prd-aks
      
      *Namespace:* {{ .CommonLabels.namespace }}
    send_resolved: true

inhibit_rules:
- source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  equal: ['alertname', 'cluster', 'service']
"@ | kubectl create secret generic alertmanager-config `
  --from-file=alertmanager.yaml=/dev/stdin `
  --namespace monitoring `
  --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "✅ Alertmanager config created" -ForegroundColor Green
Write-Host ""

# Install kube-prometheus-stack
Write-Host "Installing kube-prometheus-stack..." -ForegroundColor Cyan
Write-Host "This will take 3-5 minutes..." -ForegroundColor Yellow
Write-Host ""

$helmInstall = helm upgrade --install kube-prometheus-stack `
  prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values k8s/observability/prometheus-values.yaml `
  --set grafana.adminPassword=admin `
  --set alertmanager.config.global.slack_api_url="$slackWebhook" `
  --timeout=10m `
  --wait

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install kube-prometheus-stack" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ kube-prometheus-stack installed successfully" -ForegroundColor Green
Write-Host ""

# Wait for pods to be ready
Write-Host "Waiting for pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s | Out-Null
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s | Out-Null

Write-Host "✅ All pods are ready" -ForegroundColor Green
Write-Host ""

# Display status
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Deployed Resources:" -ForegroundColor Cyan
kubectl get pods -n monitoring -o wide
Write-Host ""

Write-Host "Services:" -ForegroundColor Cyan
kubectl get svc -n monitoring
Write-Host ""

# Access instructions
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Access Grafana Dashboard:" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Port-forward to Grafana:" -ForegroundColor Yellow
Write-Host "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80" -ForegroundColor White
Write-Host ""
Write-Host "2. Open browser:" -ForegroundColor Yellow
Write-Host "   http://localhost:3000" -ForegroundColor White
Write-Host ""
Write-Host "3. Login credentials:" -ForegroundColor Yellow
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: admin" -ForegroundColor White
Write-Host ""

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Access Prometheus:" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090" -ForegroundColor White
Write-Host "http://localhost:9090" -ForegroundColor White
Write-Host ""

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Access Alertmanager:" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093" -ForegroundColor White
Write-Host "http://localhost:9093" -ForegroundColor White
Write-Host ""

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Useful Commands:" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "View logs:" -ForegroundColor Yellow
Write-Host "  kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=50" -ForegroundColor White
Write-Host "  kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50" -ForegroundColor White
Write-Host ""
Write-Host "Check metrics:" -ForegroundColor Yellow
Write-Host "  kubectl top nodes" -ForegroundColor White
Write-Host "  kubectl top pods -n dx02" -ForegroundColor White
Write-Host ""
Write-Host "Uninstall (if needed):" -ForegroundColor Yellow
Write-Host "  helm uninstall kube-prometheus-stack -n monitoring" -ForegroundColor White
Write-Host "  kubectl delete namespace monitoring" -ForegroundColor White
Write-Host ""

Write-Host "Done! 🎉" -ForegroundColor Green
