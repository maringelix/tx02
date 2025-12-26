# 🛡️ Security Infrastructure - cert-manager & WAF

Este documento descreve a infraestrutura de segurança implementada no TX02, incluindo gerenciamento automático de certificados SSL/TLS com cert-manager e Let's Encrypt, além de Web Application Firewall (WAF) com Azure Application Gateway.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [cert-manager](#cert-manager)
- [Azure Application Gateway com WAF](#azure-application-gateway-com-waf)
- [Deployment](#deployment)
- [Configuração](#configuração)
- [Troubleshooting](#troubleshooting)
- [Monitoramento](#monitoramento)
- [Melhores Práticas](#melhores-práticas)

## 🎯 Visão Geral

### Arquitetura

```
Internet
    ↓
Azure Application Gateway (WAF)
    ↓ [Public IP]
    ↓
Nginx Ingress Controller
    ↓ [TLS termination via cert-manager]
    ↓
Istio Service Mesh
    ↓
DX02 Application Pods
```

### Componentes

| Componente | Função | Tecnologia |
|------------|--------|------------|
| **cert-manager** | Gerenciamento automático de certificados SSL/TLS | Kubernetes Operator |
| **Let's Encrypt** | Autoridade Certificadora (CA) gratuita | ACME Protocol |
| **Application Gateway** | Load Balancer L7 com WAF | Azure Resource |
| **WAF Policy** | Web Application Firewall | OWASP Top 10 Protection |
| **AGIC** | Integração AKS ↔ App Gateway | Kubernetes Ingress Controller |

## 📜 cert-manager

### O que é cert-manager?

cert-manager é um operador Kubernetes que automatiza o gerenciamento de certificados SSL/TLS. Ele pode:

- ✅ Solicitar certificados de múltiplas CAs (Let's Encrypt, Venafi, HashiCorp Vault)
- ✅ Renovar certificados automaticamente antes do vencimento
- ✅ Armazenar certificados como Kubernetes Secrets
- ✅ Configurar Ingress com TLS automaticamente

### Instalação

cert-manager é instalado via Helm Chart:

```bash
# Via workflow
gh workflow run security-infrastructure.yml \
  -f environment=prd \
  -f install_cert_manager=true \
  -f letsencrypt_email=admin@example.com \
  -f use_letsencrypt_prod=false

# Manual via Helm
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true
```

### ClusterIssuer Configuration

#### Staging (para testes)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

#### Production

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Solicitando Certificados

#### Via Ingress Annotation (Recomendado)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dx02
  namespace: dx02
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - dx02.example.com
    secretName: dx02-tls-secret
  rules:
  - host: dx02.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dx02-service
            port:
              number: 80
```

#### Via Certificate Resource

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dx02-cert
  namespace: dx02
spec:
  secretName: dx02-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - dx02.example.com
  - www.dx02.example.com
```

### Verificação

```bash
# Verificar ClusterIssuers
kubectl get clusterissuer

# Verificar certificados
kubectl get certificate -n dx02

# Ver status detalhado
kubectl describe certificate dx02-cert -n dx02

# Ver secret do certificado
kubectl get secret dx02-tls-secret -n dx02 -o yaml
```

### Renovação Automática

cert-manager renova certificados automaticamente:

- ⏰ **Timing**: 30 dias antes do vencimento
- 🔄 **Tentativas**: A cada 12 horas se falhar
- 📧 **Notificações**: Via email configurado no ClusterIssuer

## 🛡️ Azure Application Gateway com WAF

### O que é Application Gateway?

Azure Application Gateway é um load balancer de camada 7 (HTTP/HTTPS) que oferece:

- ✅ SSL/TLS termination
- ✅ Web Application Firewall (WAF)
- ✅ URL-based routing
- ✅ Cookie-based session affinity
- ✅ Auto-scaling
- ✅ Multi-site hosting

### WAF Protection

O WAF protege contra:

| Ameaça | Descrição | OWASP Top 10 |
|--------|-----------|--------------|
| SQL Injection | Injeção de código SQL | #1 |
| XSS | Cross-Site Scripting | #3 |
| LFI/RFI | Local/Remote File Inclusion | #5 |
| RCE | Remote Code Execution | #8 |
| XXE | XML External Entity | #4 |
| CSRF | Cross-Site Request Forgery | #7 |

### Arquitetura

```
┌─────────────────────────────────────────┐
│     Azure Application Gateway           │
│  ┌─────────────┐  ┌─────────────────┐  │
│  │  Frontend   │  │   WAF Policy    │  │
│  │  (Port 80)  │  │  (Prevention)   │  │
│  └──────┬──────┘  └────────┬────────┘  │
│         │                   │            │
│  ┌──────▼───────────────────▼────────┐  │
│  │      Backend Pool (AKS)          │  │
│  │   nginx-ingress-controller       │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Deployment

```bash
# Via workflow
gh workflow run security-infrastructure.yml \
  -f environment=prd \
  -f deploy_app_gateway=true \
  -f app_gateway_sku=WAF_v2 \
  -f waf_mode=Detection

# Manual
az network application-gateway create \
  --resource-group tx02-prd-rg \
  --name tx02-prd-appgw \
  --location eastus \
  --sku WAF_v2 \
  --capacity 2 \
  --vnet-name tx02-prd-vnet \
  --subnet appgw-subnet \
  --public-ip-address tx02-prd-appgw-pip
```

### WAF Modes

#### Detection Mode (Recomendado para início)

```bash
# Apenas detecta e loga ataques, não bloqueia
az network application-gateway waf-policy policy-setting update \
  --resource-group tx02-prd-rg \
  --policy-name tx02-prd-appgw-waf-policy \
  --mode Detection \
  --state Enabled
```

**Vantagens:**
- ✅ Não quebra aplicações legítimas
- ✅ Permite ajustar regras antes de bloquear
- ✅ Útil para validação inicial

#### Prevention Mode (Produção)

```bash
# Bloqueia ataques detectados
az network application-gateway waf-policy policy-setting update \
  --resource-group tx02-prd-rg \
  --policy-name tx02-prd-appgw-waf-policy \
  --mode Prevention \
  --state Enabled
```

**Vantagens:**
- ✅ Proteção ativa contra ataques
- ✅ Bloqueia requisições maliciosas
- ✅ Compliance com segurança

### AGIC (Application Gateway Ingress Controller)

AGIC integra AKS com Application Gateway:

```bash
# Habilitar AGIC no AKS
az aks enable-addons \
  --resource-group tx02-prd-rg \
  --name tx02-prd-aks \
  --addons ingress-appgw \
  --appgw-id /subscriptions/.../tx02-prd-appgw
```

#### Ingress com AGIC

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dx02-appgw
  namespace: dx02
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/waf-policy-for-path: "/subscriptions/.../waf-policy"
spec:
  rules:
  - host: dx02.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dx02-service
            port:
              number: 80
```

## 🚀 Deployment

### Pré-requisitos

1. **Azure Credentials** configuradas como secret no GitHub
2. **AKS Cluster** rodando e acessível
3. **VNet** com subnet disponível para Application Gateway
4. **Domínio** apontando para o IP público (para Let's Encrypt)

### Deploy Completo

```bash
# 1. Deploy cert-manager + Application Gateway
gh workflow run security-infrastructure.yml \
  -f environment=prd \
  -f install_cert_manager=true \
  -f letsencrypt_email=admin@yourdomain.com \
  -f use_letsencrypt_prod=false \
  -f deploy_app_gateway=true \
  -f app_gateway_sku=WAF_v2 \
  -f waf_mode=Detection

# 2. Aguardar conclusão (10-15 minutos)

# 3. Configurar DNS
APPGW_IP=$(az network public-ip show \
  --resource-group tx02-prd-rg \
  --name tx02-prd-appgw-pip \
  --query ipAddress -o tsv)

echo "Configure DNS A record: dx02.example.com -> $APPGW_IP"

# 4. Aguardar emissão do certificado
kubectl get certificate -n dx02 -w
```

### Deploy Apenas cert-manager

```bash
gh workflow run security-infrastructure.yml \
  -f environment=prd \
  -f install_cert_manager=true \
  -f letsencrypt_email=admin@yourdomain.com \
  -f use_letsencrypt_prod=false \
  -f deploy_app_gateway=false
```

### Deploy Apenas Application Gateway

```bash
gh workflow run security-infrastructure.yml \
  -f environment=prd \
  -f install_cert_manager=false \
  -f deploy_app_gateway=true \
  -f app_gateway_sku=WAF_v2 \
  -f waf_mode=Detection
```

## ⚙️ Configuração

### Staging → Production (Let's Encrypt)

```bash
# 1. Testar com staging primeiro
# (certificados staging têm limite mais alto de rate limit)

# 2. Após confirmar que funciona, migrar para production
kubectl delete clusterissuer letsencrypt-staging

# 3. Criar production issuer
gh workflow run security-infrastructure.yml \
  -f environment=prd \
  -f install_cert_manager=true \
  -f letsencrypt_email=admin@yourdomain.com \
  -f use_letsencrypt_prod=true

# 4. Atualizar Ingress para usar production issuer
kubectl annotate ingress dx02 -n dx02 \
  cert-manager.io/cluster-issuer=letsencrypt-prod \
  --overwrite

# 5. Deletar certificado antigo para forçar reemissão
kubectl delete certificate dx02-tls-cert -n dx02
kubectl delete secret dx02-tls-secret -n dx02
```

### Wildcard Certificates

Para certificados wildcard, use DNS-01 challenge:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-dns-account-key
    solvers:
    - dns01:
        azureDNS:
          clientID: <azure-sp-client-id>
          clientSecretSecretRef:
            name: azuredns-config
            key: client-secret
          subscriptionID: <subscription-id>
          tenantID: <tenant-id>
          resourceGroupName: dns-rg
          hostedZoneName: example.com
```

### Custom WAF Rules

```bash
# Adicionar regra customizada
az network application-gateway waf-policy custom-rule create \
  --resource-group tx02-prd-rg \
  --policy-name tx02-prd-appgw-waf-policy \
  --name BlockBadUserAgent \
  --priority 1 \
  --rule-type MatchRule \
  --action Block \
  --match-conditions \
    RequestHeaders.User-Agent Contains "BadBot"
```

## 🔍 Troubleshooting

### cert-manager Issues

#### Certificado não sendo emitido

```bash
# Verificar status
kubectl describe certificate dx02-cert -n dx02

# Ver logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager -f

# Verificar CertificateRequest
kubectl get certificaterequest -n dx02

# Verificar Order e Challenge
kubectl get order,challenge -n dx02
```

**Problemas comuns:**

1. **DNS não resolvendo**: Aguardar propagação DNS (até 48h)
2. **HTTP-01 challenge falhou**: Verificar se Ingress está acessível na porta 80
3. **Rate limit atingido**: Usar staging enquanto testa, production após confirmar

#### Renovação falhou

```bash
# Forçar renovação manual
kubectl delete secret dx02-tls-secret -n dx02
# cert-manager vai recriar automaticamente
```

### Application Gateway Issues

#### Backend não saudável

```bash
# Verificar backend pool
az network application-gateway show-backend-health \
  --resource-group tx02-prd-rg \
  --name tx02-prd-appgw

# Ver logs do AGIC
kubectl logs -n kube-system -l app=ingress-appgw -f
```

#### WAF bloqueando tráfego legítimo

```bash
# Ver logs do WAF
az monitor diagnostic-settings create \
  --resource /subscriptions/.../tx02-prd-appgw \
  --name waf-logs \
  --workspace <log-analytics-workspace-id> \
  --logs '[{"category": "ApplicationGatewayFirewallLog", "enabled": true}]'

# Criar exclusão de regra
az network application-gateway waf-policy managed-rule exclusion add \
  --resource-group tx02-prd-rg \
  --policy-name tx02-prd-appgw-waf-policy \
  --match-variable RequestHeaderNames \
  --selector-match-operator Contains \
  --selector "X-Custom-Header"
```

## 📊 Monitoramento

### cert-manager Metrics

```bash
# Prometheus metrics
kubectl port-forward -n cert-manager svc/cert-manager 9402:9402
curl http://localhost:9402/metrics
```

**Métricas importantes:**

- `certmanager_certificate_expiration_timestamp_seconds`
- `certmanager_certificate_renewal_timestamp_seconds`
- `certmanager_controller_sync_call_count`

### Application Gateway Metrics

```bash
# Via Azure Monitor
az monitor metrics list \
  --resource /subscriptions/.../tx02-prd-appgw \
  --metric "Throughput,ResponseStatus,HealthyHostCount"
```

**Métricas importantes:**

- **HealthyHostCount**: Backends saudáveis
- **ResponseStatus**: Códigos HTTP (200, 4xx, 5xx)
- **TotalRequests**: Requisições totais
- **FailedRequests**: Requisições falhadas
- **Throughput**: Taxa de transferência

### Alertas

```yaml
# Azure Monitor Alert
az monitor metrics alert create \
  --name "AppGW-UnhealthyBackend" \
  --resource-group tx02-prd-rg \
  --scopes /subscriptions/.../tx02-prd-appgw \
  --condition "avg HealthyHostCount < 1" \
  --description "Application Gateway backend unhealthy"
```

## ✅ Melhores Práticas

### Segurança

1. **Staging antes de Production**
   - ✅ Sempre testar com Let's Encrypt staging primeiro
   - ✅ Rate limits são mais altos no staging

2. **WAF em Detection Mode inicialmente**
   - ✅ Coletar logs por 1-2 semanas
   - ✅ Ajustar regras para reduzir falsos positivos
   - ✅ Depois migrar para Prevention Mode

3. **Renovação Automática**
   - ✅ Não confiar em renovação manual
   - ✅ Monitorar expiração de certificados
   - ✅ Configurar alertas 30 dias antes

### Performance

1. **Caching de certificados**
   - ✅ cert-manager mantém certificados em Secrets
   - ✅ Não há impacto de performance na renovação

2. **Application Gateway Capacity**
   - ✅ Usar auto-scaling para cargas variáveis
   - ✅ Mínimo 2 instâncias para HA

3. **Connection Pooling**
   - ✅ Configurar timeouts adequados
   - ✅ Reutilizar conexões backend

### Custos

| Recurso | Custo Mensal (estimado) |
|---------|-------------------------|
| cert-manager | $0 (open source) |
| Let's Encrypt | $0 (gratuito) |
| Application Gateway WAF_v2 | ~$250 |
| Public IP | ~$4 |
| **Total** | **~$254/mês** |

**Otimizações:**

- ✅ Usar Standard_v2 se WAF não for necessário (~$125/mês)
- ✅ Desligar instâncias não-prod fora do horário comercial

## 📚 Referências

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Azure Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/)
- [AGIC Documentation](https://azure.github.io/application-gateway-kubernetes-ingress/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

## 🆘 Suporte

Para problemas ou dúvidas:

1. Verificar [Troubleshooting](#troubleshooting)
2. Consultar logs: `kubectl logs -n cert-manager -l app=cert-manager`
3. Verificar issues no GitHub do [cert-manager](https://github.com/cert-manager/cert-manager/issues)
4. Abrir ticket no Azure Support (Application Gateway)
