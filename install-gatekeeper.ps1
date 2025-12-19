# OPA Gatekeeper Installation Script for AKS
# This script installs OPA Gatekeeper and applies security policies

Write-Host "🔒 Installing OPA Gatekeeper on AKS..." -ForegroundColor Cyan

# Check if kubectl is available
if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl not found. Please install kubectl first." -ForegroundColor Red
    exit 1
}

# Check if connected to AKS
Write-Host "`n📡 Checking AKS connection..." -ForegroundColor Yellow
$context = kubectl config current-context 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not connected to AKS. Please run 'az aks get-credentials' first." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Connected to: $context" -ForegroundColor Green

# Install OPA Gatekeeper using Helm
Write-Host "`n📦 Installing OPA Gatekeeper via Helm..." -ForegroundColor Yellow

# Add Gatekeeper Helm repository
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update

# Create gatekeeper-system namespace
kubectl create namespace gatekeeper-system --dry-run=client -o yaml | kubectl apply -f -

# Install Gatekeeper
helm upgrade --install gatekeeper gatekeeper/gatekeeper `
    --namespace gatekeeper-system `
    --set enableExternalData=false `
    --set validatingWebhookTimeoutSeconds=5 `
    --set mutatingWebhookTimeoutSeconds=2 `
    --set audit.replicas=1 `
    --set replicas=2 `
    --wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ OPA Gatekeeper installed successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to install OPA Gatekeeper" -ForegroundColor Red
    exit 1
}

# Wait for Gatekeeper to be ready
Write-Host "`n⏳ Waiting for Gatekeeper pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=gatekeeper --namespace gatekeeper-system --timeout=120s

# Apply constraint templates and policies
Write-Host "`n📜 Applying Gatekeeper policies..." -ForegroundColor Yellow

$policiesPath = Join-Path $PSScriptRoot "k8s\policies"
if (Test-Path $policiesPath) {
    kubectl apply -f $policiesPath -R
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Policies applied successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some policies may have failed to apply" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Policies directory not found: $policiesPath" -ForegroundColor Yellow
    Write-Host "   Gatekeeper is installed but no policies are applied yet." -ForegroundColor Yellow
}

# Display status
Write-Host "`n📊 Gatekeeper Status:" -ForegroundColor Cyan
kubectl get pods -n gatekeeper-system
kubectl get constrainttemplates
kubectl get constraints --all-namespaces

Write-Host "`n✅ OPA Gatekeeper installation complete!" -ForegroundColor Green
Write-Host "📖 See k8s/policies/README.md for policy documentation" -ForegroundColor Cyan
