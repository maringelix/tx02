# 🕸️ Azure Service Mesh (Istio) - Guia Completo

[![Istio](https://img.shields.io/badge/Istio-1.20-blue.svg)](https://istio.io/)
[![AKS](https://img.shields.io/badge/AKS-Integrated-green.svg)](https://learn.microsoft.com/en-us/azure/aks/istio-about)
[![mTLS](https://img.shields.io/badge/Security-mTLS%20Enabled-success.svg)](https://istio.io/latest/docs/concepts/security/)

Documentação completa sobre a implementação e uso do **Azure Service Mesh** (baseado em Istio) no projeto TX02.

---

## ⚠️ **Limitações do Azure Service Mesh**

> 🔔 **Importante:** O Azure Service Mesh é uma implementação gerenciada do Istio com algumas limitações:

- ❌ **Telemetry API** (v1alpha1) não é suportada - o Azure usa configuração built-in
- ❌ Alguns recursos avançados do Istio podem não estar disponíveis
- ✅ **Telemetry automática** já vem configurada com Azure Monitor e Prometheus
- ✅ mTLS, Traffic Management e Observability básica são totalmente suportados

**Documentação oficial:** [Azure AKS Istio Add-on Limitations](https://learn.microsoft.com/en-us/azure/aks/istio-about#limitations)

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Arquitetura](#-arquitetura)
- [Recursos Implementados](#-recursos-implementados)
- [Instalação](#-instalação)
- [Configuração](#-configuração)
- [Traffic Management](#-traffic-management)
- [Segurança](#-segurança)
- [Observabilidade](#-observabilidade)
- [Troubleshooting](#-troubleshooting)
- [Best Practices](#-best-practices)

---

## 🎯 Visão Geral

O **Azure Service Mesh** é uma camada de infraestrutura dedicada que gerencia a comunicação service-to-service dentro de um cluster Kubernetes. Baseado no **Istio**, oferece:

### 🌟 Principais Benefícios

- **🔒 Segurança:** mTLS automático entre serviços
- **📊 Observabilidade:** Métricas, logs e tracing detalhados
- **🎯 Traffic Management:** Roteamento avançado, circuit breakers, retries
- **🛡️ Resiliência:** Timeout, retries, failover automático
- **🚀 Deploy Seguro:** Canary, blue/green, A/B testing
- **📈 Performance:** Load balancing inteligente

### ⚙️ Componentes Principais

```
┌─────────────────────────────────────────────────────────────┐
│                    AKS CLUSTER (TX02)                       │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │          aks-istio-system (Control Plane)          │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │   │
│  │  │  Istiod  │  │  Pilot   │  │   Galley     │    │   │
│  │  │(Control) │  │(Traffic) │  │(Config)      │    │   │
│  │  └──────────┘  └──────────┘  └──────────────┘    │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │       aks-istio-ingress (Ingress Gateway)          │   │
│  │  ┌──────────────────────────────────────────┐     │   │
│  │  │   Istio Ingress Gateway (LoadBalancer)   │     │   │
│  │  │   External IP: xx.xx.xx.xx               │     │   │
│  │  └──────────────────────────────────────────┘     │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │           dx02 namespace (Application)             │   │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────┐    │   │
│  │  │  Pod DX02  │  │  Pod DX02  │  │ Pod DX02 │    │   │
│  │  │ ┌────────┐ │  │ ┌────────┐ │  │┌────────┐│    │   │
│  │  │ │  App   │ │  │ │  App   │ │  ││  App   ││    │   │
│  │  │ └────────┘ │  │ └────────┘ │  │└────────┘│    │   │
│  │  │ ┌────────┐ │  │ ┌────────┐ │  │┌────────┐│    │   │
│  │  │ │Envoy   │ │  │ │Envoy   │ │  ││Envoy   ││    │   │
│  │  │ │Sidecar │ │  │ │Sidecar │ │  ││Sidecar││    │   │
│  │  │ └────────┘ │  │ └────────┘ │  │└────────┘│    │   │
│  │  └────────────┘  └────────────┘  └──────────┘    │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│                        mTLS Encrypted                       │
│                     ←──────────────────→                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Arquitetura

### Data Plane (Envoy Sidecars)

O **Envoy Sidecar** é automaticamente injetado em cada pod:

- **Intercepta** todo tráfego de entrada e saída
- **Aplica** políticas de segurança e roteamento
- **Coleta** métricas e telemetria
- **Gerencia** mTLS automático

### Control Plane (Istiod)

O **Istiod** é o cérebro do Service Mesh:

- **Pilot:** Gerencia configuração de traffic routing
- **Citadel:** Gerencia certificados e identidades
- **Galley:** Valida e distribui configuração

---

## ✅ Recursos Implementados

### 🔒 Segurança

- [x] **mTLS Strict Mode** - Comunicação criptografada obrigatória
- [x] **PeerAuthentication** - Políticas de autenticação por namespace
- [x] **Service Accounts** - Identidades para cada serviço
- [x] **RBAC** - Controle de acesso granular

### 🌐 Traffic Management

- [x] **Gateway** - Entrada de tráfego externo
- [x] **VirtualService** - Roteamento inteligente
- [x] **DestinationRule** - Load balancing e circuit breakers
- [x] **Timeout & Retries** - Resiliência automática

### 📊 Observabilidade

- [x] **Metrics (Prometheus)** - Métricas de performance
- [x] **Tracing (Azure Monitor)** - Distributed tracing
- [x] **Access Logs** - Logs de acesso detalhados
- [x] **Service Graph** - Visualização de dependências

### 🚀 Deployment Strategies

- [x] **Canary Releases** - Deploy gradual
- [x] **Traffic Splitting** - A/B testing
- [x] **Circuit Breaking** - Proteção contra falhas em cascata
- [x] **Fault Injection** - Testes de resiliência

---

## 🚀 Instalação

### Pré-requisitos

```bash
# 1. Azure CLI instalado
az --version

# 2. Kubectl configurado
kubectl version --client

# 3. Cluster AKS ativo
az aks show --resource-group tx02-prd-rg --name tx02-prd-aks
```

### Via GitHub Actions (Recomendado)

1. Acesse: **Actions** → **🕸️ Configure Azure Service Mesh**

2. Clique em **Run workflow**

3. Configure os parâmetros:
   ```yaml
   Environment: prd
   Enable mTLS: true
   Enable Telemetry: true
   Enable Ingress Gateway: true
   ```

4. Aguarde a conclusão (~5-10 minutos)

### Via CLI Manual

```bash
# 1. Enable Istio add-on no AKS
az aks mesh enable \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks

# 2. Verificar instalação
kubectl get pods -n aks-istio-system

# 3. Enable Istio injection no namespace
kubectl label namespace dx02 istio-injection=enabled

# 4. Restart pods para injetar sidecars
kubectl rollout restart deployment -n dx02
```

### Via PowerShell Script

```powershell
# Executar script helper
.\scripts\configure-service-mesh.ps1 -Environment prd -EnableMTLS $true
```

---

## ⚙️ Configuração

### 1. Enable Sidecar Injection

```bash
# Enable para namespace específico
kubectl label namespace dx02 istio-injection=enabled

# Verificar namespaces com injection
kubectl get namespaces -L istio-injection
```

### 2. Configurar mTLS Strict

```yaml
# mtls-strict.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default-mtls-strict
  namespace: dx02
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f mtls-strict.yaml
```

### 3. Deploy Gateway e VirtualService

```yaml
# gateway.yaml
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
```

```bash
kubectl apply -f gateway.yaml
```

### 4. Obter IP do Ingress Gateway

```bash
kubectl get svc istio-ingressgateway -n aks-istio-ingress

# Output:
# NAME                   TYPE           EXTERNAL-IP      PORT(S)
# istio-ingressgateway   LoadBalancer   20.245.123.456   80:31234/TCP
```

### 5. Testar aplicação

```bash
# Via Ingress Gateway
curl http://20.245.123.456

# Verificar tráfego com sidecars
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- curl localhost:15000/stats
```

---

## 🎯 Traffic Management

### Canary Deployment (10% / 90%)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: dx02-canary
  namespace: dx02
spec:
  hosts:
  - dx02-service
  http:
  - match:
    - headers:
        x-version:
          exact: "v2"
    route:
    - destination:
        host: dx02-service
        subset: v2
      weight: 10
  - route:
    - destination:
        host: dx02-service
        subset: v1
      weight: 90
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: dx02-destination
  namespace: dx02
spec:
  host: dx02-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

### Circuit Breaker

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: dx02-circuit-breaker
  namespace: dx02
spec:
  host: dx02-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 40
```

### Fault Injection (Testing)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: dx02-fault-injection
  namespace: dx02
spec:
  hosts:
  - dx02-service
  http:
  - fault:
      delay:
        percentage:
          value: 10.0
        fixedDelay: 5s
      abort:
        percentage:
          value: 5.0
        httpStatus: 503
    route:
    - destination:
        host: dx02-service
```

### Traffic Mirroring

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: dx02-mirror
  namespace: dx02
spec:
  hosts:
  - dx02-service
  http:
  - route:
    - destination:
        host: dx02-service
        subset: v1
      weight: 100
    mirror:
      host: dx02-service
      subset: v2
    mirrorPercentage:
      value: 100.0
```

---

## 🔒 Segurança

### mTLS Verification

```bash
# Verificar status mTLS
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  openssl s_client -showcerts -connect dx02-service:80

# Verificar certificados
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl http://localhost:15000/certs
```

### Authorization Policies

```yaml
# Deny all por padrão
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: dx02
spec:
  {}
---
# Allow específico
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: dx02
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/dx02/sa/frontend"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

### Request Authentication (JWT)

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: dx02
spec:
  selector:
    matchLabels:
      app: dx02
  jwtRules:
  - issuer: "https://login.microsoftonline.com/<tenant-id>/v2.0"
    jwksUri: "https://login.microsoftonline.com/<tenant-id>/discovery/v2.0/keys"
```

---

## 📊 Observabilidade

### Prometheus Metrics

```bash
# Port-forward para Prometheus
kubectl port-forward -n aks-istio-system \
  svc/prometheus 9090:9090

# Acessar: http://localhost:9090
```

**Métricas importantes:**
- `istio_requests_total` - Total de requests
- `istio_request_duration_milliseconds` - Latência
- `istio_request_bytes` - Tamanho de requests
- `istio_response_bytes` - Tamanho de responses

### Service Graph

```bash
# Visualizar topologia de serviços
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl http://localhost:15000/clusters
```

### Distributed Tracing (Azure Monitor)

Já configurado automaticamente! Traces são enviados para **Azure Application Insights**.

```bash
# Verificar configuração de tracing
kubectl get telemetry -n aks-istio-system -o yaml
```

### Access Logs

```bash
# Visualizar logs do Envoy sidecar
kubectl logs <pod-name> -n dx02 -c istio-proxy

# Logs em tempo real
kubectl logs -f <pod-name> -n dx02 -c istio-proxy --tail=100
```

### Dashboards Grafana

```bash
# Port-forward para Grafana (se configurado)
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Acessar: http://localhost:3000
# Dashboards: Istio Service Dashboard, Istio Mesh Dashboard
```

---

## 🔧 Troubleshooting

### Problema: Sidecar não injetado

```bash
# Verificar se namespace tem label
kubectl get namespace dx02 --show-labels

# Se não tiver, adicionar:
kubectl label namespace dx02 istio-injection=enabled

# Restart pods
kubectl rollout restart deployment -n dx02
```

### Problema: Pods não iniciam após injection

```bash
# Verificar logs do init container
kubectl logs <pod-name> -n dx02 -c istio-init

# Verificar eventos
kubectl describe pod <pod-name> -n dx02

# Verificar recursos
kubectl top pod <pod-name> -n dx02
```

### Problema: mTLS errors

```bash
# Verificar políticas de autenticação
kubectl get peerauthentication --all-namespaces

# Verificar certificados
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  ls -la /etc/certs/

# Logs do Envoy
kubectl logs <pod-name> -n dx02 -c istio-proxy | grep -i tls
```

### Problema: Gateway não responde

```bash
# Verificar status do Gateway
kubectl get gateway -n dx02

# Verificar Ingress Gateway pods
kubectl get pods -n aks-istio-ingress

# Verificar logs
kubectl logs -n aks-istio-ingress \
  deployment/istio-ingressgateway

# Verificar External IP
kubectl get svc istio-ingressgateway -n aks-istio-ingress
```

### Problema: High latency

```bash
# Verificar métricas de latência
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl http://localhost:15000/stats/prometheus | grep latency

# Analisar configuração de timeout
kubectl get virtualservice -n dx02 -o yaml

# Verificar resource limits
kubectl describe pod <pod-name> -n dx02
```

### Debug Mode

```bash
# Enable debug logs no Envoy
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl -X POST http://localhost:15000/logging?level=debug

# Dump configuração do Envoy
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl http://localhost:15000/config_dump > envoy-config.json
```

---

## 📚 Best Practices

### 1. **Sempre use mTLS Strict**
```yaml
# Recomendado para produção
spec:
  mtls:
    mode: STRICT
```

### 2. **Configure Timeouts e Retries**
```yaml
http:
- route:
  - destination:
      host: service
  timeout: 30s
  retries:
    attempts: 3
    perTryTimeout: 10s
```

### 3. **Use Circuit Breakers**
Proteja seus serviços de falhas em cascata.

### 4. **Implemente Authorization Policies**
Use "deny by default" e permita apenas o necessário.

### 5. **Monitor Métricas**
Configure alertas para:
- Alta latência (> 1s)
- Taxa de erro (> 1%)
- Circuit breakers abertos
- Baixa taxa de sucesso mTLS

### 6. **Use Resource Limits**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 7. **Gradual Rollouts**
Sempre use canary ou blue/green para deploys.

### 8. **Test Fault Injection**
Teste regularmente resiliência com fault injection em staging.

### 9. **Keep Istio Updated**
Mantenha a versão do Istio atualizada para security patches.

### 10. **Use Namespace Isolation**
Configure políticas por namespace para melhor segurança.

---

## 📖 Referências

### Documentação Oficial

- [Istio Documentation](https://istio.io/latest/docs/)
- [Azure AKS Istio Add-on](https://learn.microsoft.com/en-us/azure/aks/istio-about)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)

### Tutoriais e Guias

- [Istio in Action](https://www.manning.com/books/istio-in-action)
- [Azure Service Mesh Workshop](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-addon)
- [Istio Best Practices](https://istio.io/latest/docs/ops/best-practices/)

### Comandos Úteis

```bash
# Listar todos recursos Istio
kubectl get gateway,virtualservice,destinationrule,serviceentry -A

# Status do Istio
kubectl get pods -n aks-istio-system

# Logs do control plane
kubectl logs -n aks-istio-system deployment/istiod

# Verificar configuração de um serviço
istioctl analyze -n dx02

# Gerar relatório de configuração
istioctl proxy-config all <pod-name> -n dx02

# Verificar mTLS status
istioctl authn tls-check <pod-name>.<namespace>
```

---

## 🎉 Conclusão

O **Azure Service Mesh** está agora completamente configurado no projeto TX02, oferecendo:

✅ **Segurança** robusta com mTLS automático  
✅ **Observabilidade** completa com métricas e tracing  
✅ **Traffic Management** avançado com canary e circuit breakers  
✅ **Resiliência** com retries, timeouts e fault injection  

Para dúvidas ou problemas, consulte a seção [Troubleshooting](#-troubleshooting) ou abra uma issue no repositório.

---

**Última atualização:** 24/12/2025  
**Versão:** 1.0.0  
**Autor:** maringelix
