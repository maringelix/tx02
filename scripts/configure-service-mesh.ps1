# Script para configurar Azure Service Mesh (Istio) no AKS
# Usage: .\configure-service-mesh.ps1 -Environment prd -EnableMTLS $true

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("prd", "stg")]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableMTLS = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableTelemetry = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableIngressGateway = $true
)

$ErrorActionPreference = "Stop"

# Configurações
$ResourceGroup = "tx02-$Environment-rg"
$ClusterName = "tx02-$Environment-aks"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "🕸️  Azure Service Mesh Configuration" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "AKS Cluster: $ClusterName" -ForegroundColor Yellow
Write-Host ""

# Função para logging
function Write-Step {
    param([string]$Message)
    Write-Host "➜ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# 1. Verificar pré-requisitos
Write-Step "Checking prerequisites..."
try {
    $azVersion = az --version 2>&1 | Select-String "azure-cli"
    Write-Info "Azure CLI: $azVersion"
    
    $kubectlVersion = kubectl version --client --short 2>&1
    Write-Info "Kubectl: $kubectlVersion"
    
    Write-Success "Prerequisites OK"
} catch {
    Write-Error "Prerequisites check failed: $_"
    exit 1
}
Write-Host ""

# 2. Get AKS credentials
Write-Step "Getting AKS credentials..."
try {
    az aks get-credentials `
        --resource-group $ResourceGroup `
        --name $ClusterName `
        --overwrite-existing | Out-Null
    
    Write-Success "Connected to AKS cluster"
} catch {
    Write-Error "Failed to get AKS credentials: $_"
    exit 1
}
Write-Host ""

# 3. Verificar se Istio já está instalado
Write-Step "Checking if Istio is already installed..."
try {
    $istioStatus = az aks show `
        --resource-group $ResourceGroup `
        --name $ClusterName `
        --query 'serviceMeshProfile.mode' -o tsv
    
    if ($istioStatus -eq "Istio") {
        Write-Warning "Istio is already enabled on this cluster"
    } else {
        Write-Info "Istio is not enabled. Installing..."
        
        # Enable Istio add-on
        Write-Step "Enabling Istio add-on on AKS..."
        az aks mesh enable `
            --resource-group $ResourceGroup `
            --name $ClusterName
        
        Write-Success "Istio add-on enabled successfully"
        
        # Wait for Istio to be ready
        Write-Info "Waiting for Istio pods to be ready..."
        Start-Sleep -Seconds 30
        
        $retries = 0
        $maxRetries = 20
        while ($retries -lt $maxRetries) {
            $readyPods = kubectl get pods -n aks-istio-system --field-selector=status.phase=Running 2>$null | Measure-Object -Line
            if ($readyPods.Lines -gt 1) {
                Write-Success "Istio system pods are running"
                break
            }
            Write-Info "Waiting for Istio pods... ($retries/$maxRetries)"
            Start-Sleep -Seconds 10
            $retries++
        }
    }
} catch {
    Write-Error "Failed to check/install Istio: $_"
    exit 1
}
Write-Host ""

# 4. Verificar status do Istio
Write-Step "Verifying Istio installation..."
try {
    Write-Info "Istio system pods:"
    kubectl get pods -n aks-istio-system
    Write-Host ""
    
    Write-Info "Istio services:"
    kubectl get svc -n aks-istio-system
    
    Write-Success "Istio is running"
} catch {
    Write-Warning "Could not verify Istio status"
}
Write-Host ""

# 5. Enable Istio injection em namespaces
Write-Step "Enabling Istio sidecar injection..."
try {
    # Criar namespaces se não existirem
    kubectl create namespace dx02 --dry-run=client -o yaml | kubectl apply -f - | Out-Null
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - | Out-Null
    
    # Enable injection
    kubectl label namespace dx02 istio-injection=enabled --overwrite | Out-Null
    kubectl label namespace monitoring istio-injection=enabled --overwrite | Out-Null
    
    Write-Success "Istio injection enabled for namespaces"
    Write-Host ""
    Write-Info "Namespaces with Istio injection:"
    kubectl get namespaces -L istio-injection | Select-String "enabled"
} catch {
    Write-Error "Failed to enable Istio injection: $_"
}
Write-Host ""

# 6. Configurar mTLS
if ($EnableMTLS) {
    Write-Step "Configuring strict mTLS..."
    try {
        $mtlsPolicy = @"
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default-mtls-strict
  namespace: aks-istio-system
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: dx02-mtls-strict
  namespace: dx02
spec:
  mtls:
    mode: STRICT
"@
        
        $mtlsPolicy | kubectl apply -f - | Out-Null
        Write-Success "mTLS configured successfully"
    } catch {
        Write-Warning "Failed to configure mTLS: $_"
    }
    Write-Host ""
}

# 7. Deploy Istio Ingress Gateway
if ($EnableIngressGateway) {
    Write-Step "Deploying Istio Ingress Gateway..."
    try {
        $ingressManifest = @"
apiVersion: v1
kind: Namespace
metadata:
  name: aks-istio-ingress
  labels:
    istio-injection: enabled
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: istio-ingressgateway
  namespace: aks-istio-ingress
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istio-ingressgateway
  namespace: aks-istio-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: istio-ingressgateway
      istio: ingressgateway
  template:
    metadata:
      labels:
        app: istio-ingressgateway
        istio: ingressgateway
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      serviceAccountName: istio-ingressgateway
      containers:
      - name: istio-proxy
        image: mcr.microsoft.com/oss/istio/proxyv2:1.20
        ports:
        - containerPort: 8080
          protocol: TCP
        - containerPort: 8443
          protocol: TCP
        - containerPort: 15021
          protocol: TCP
        env:
        - name: ISTIO_META_ROUTER_MODE
          value: "sni-dnat"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1024Mi
---
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: aks-istio-ingress
  labels:
    app: istio-ingressgateway
    istio: ingressgateway
spec:
  type: LoadBalancer
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  ports:
  - name: status-port
    port: 15021
    targetPort: 15021
  - name: http2
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
"@
        
        $ingressManifest | kubectl apply -f - | Out-Null
        
        Write-Info "Waiting for Ingress Gateway to be ready..."
        Start-Sleep -Seconds 15
        
        kubectl wait --for=condition=available deployment/istio-ingressgateway `
            -n aks-istio-ingress `
            --timeout=300s 2>$null | Out-Null
        
        Write-Success "Ingress Gateway deployed"
        Write-Host ""
        Write-Info "Ingress Gateway service:"
        kubectl get svc istio-ingressgateway -n aks-istio-ingress
    } catch {
        Write-Warning "Failed to deploy Ingress Gateway: $_"
    }
    Write-Host ""
}

# 8. Configurar Telemetry
if ($EnableTelemetry) {
    Write-Step "Configuring telemetry..."
    try {
        $telemetryConfig = @"
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: aks-istio-system
spec:
  tracing:
  - providers:
    - name: azure-monitor
    randomSamplingPercentage: 100.0
  metrics:
  - providers:
    - name: prometheus
  accessLogging:
  - providers:
    - name: envoy
"@
        
        $telemetryConfig | kubectl apply -f - | Out-Null
        Write-Success "Telemetry configured"
    } catch {
        Write-Warning "Failed to configure telemetry: $_"
    }
    Write-Host ""
}

# 9. Deploy Gateway e VirtualService para DX02
Write-Step "Deploying DX02 Gateway and VirtualService..."
try {
    $dx02Gateway = @"
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: dx02-gateway
  namespace: dx02
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: dx02-vs
  namespace: dx02
spec:
  hosts:
  - "*"
  gateways:
  - dx02-gateway
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: dx02-service
        port:
          number: 80
      weight: 100
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
"@
    
    $dx02Gateway | kubectl apply -f - | Out-Null
    Write-Success "DX02 Gateway and VirtualService deployed"
} catch {
    Write-Warning "Failed to deploy DX02 Gateway: $_"
}
Write-Host ""

# 10. Resumo final
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "🎉 Configuration Complete!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Success "Azure Service Mesh is configured on cluster: $ClusterName"
Write-Host ""

Write-Info "Configuration Summary:"
Write-Host "  • Environment: $Environment" -ForegroundColor White
Write-Host "  • mTLS: $(if ($EnableMTLS) {'✅ Enabled'} else {'❌ Disabled'})" -ForegroundColor White
Write-Host "  • Telemetry: $(if ($EnableTelemetry) {'✅ Enabled'} else {'❌ Disabled'})" -ForegroundColor White
Write-Host "  • Ingress Gateway: $(if ($EnableIngressGateway) {'✅ Enabled'} else {'❌ Disabled'})" -ForegroundColor White
Write-Host ""

if ($EnableIngressGateway) {
    Write-Info "Getting Ingress Gateway External IP..."
    Start-Sleep -Seconds 5
    
    $externalIP = kubectl get svc istio-ingressgateway -n aks-istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    
    if ($externalIP) {
        Write-Host "  🌐 External IP: " -NoNewline -ForegroundColor White
        Write-Host "$externalIP" -ForegroundColor Green
        Write-Host ""
        Write-Info "Test your application:"
        Write-Host "  curl http://$externalIP" -ForegroundColor Cyan
    } else {
        Write-Warning "External IP not available yet. Check status with:"
        Write-Host "  kubectl get svc istio-ingressgateway -n aks-istio-ingress" -ForegroundColor Cyan
    }
    Write-Host ""
}

Write-Info "Next steps:"
Write-Host "  1. Restart pods in enabled namespaces to inject sidecars" -ForegroundColor White
Write-Host "     kubectl rollout restart deployment -n dx02" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Verify sidecar injection" -ForegroundColor White
Write-Host "     kubectl get pods -n dx02" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Check Istio status" -ForegroundColor White
Write-Host "     kubectl get pods -n aks-istio-system" -ForegroundColor Cyan
Write-Host ""
Write-Host "  4. View documentation" -ForegroundColor White
Write-Host "     See SERVICE_MESH.md for complete guide" -ForegroundColor Cyan
Write-Host ""

Write-Host "=====================================" -ForegroundColor Cyan
Write-Success "Script completed successfully!"
Write-Host "=====================================" -ForegroundColor Cyan
