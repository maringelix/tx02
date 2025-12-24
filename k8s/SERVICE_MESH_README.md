# 🕸️ Service Mesh Kubernetes Manifests

Exemplos de manifestos Istio para o projeto DX02.

## 📋 Arquivos

- `service-mesh-examples.yaml` - Exemplos completos de configurações Istio

## 🚀 Como Usar

### 1. Pré-requisitos

Certifique-se de que o Service Mesh está instalado:

```bash
# Verificar se Istio está rodando
kubectl get pods -n aks-istio-system

# Verificar se namespace tem Istio injection habilitado
kubectl get namespace dx02 -L istio-injection
```

### 2. Aplicar Configurações Básicas

```bash
# Gateway e VirtualService básico
kubectl apply -f service-mesh-examples.yaml

# Verificar
kubectl get gateway,virtualservice -n dx02
```

### 3. Obter IP do Ingress Gateway

```bash
kubectl get svc istio-ingressgateway -n aks-istio-ingress

# Output:
# NAME                   TYPE           EXTERNAL-IP      PORT(S)
# istio-ingressgateway   LoadBalancer   20.245.123.456   80:31234/TCP
```

### 4. Testar Aplicação

```bash
# Via Ingress Gateway
curl http://20.245.123.456

# Verificar métricas
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl localhost:15000/stats/prometheus
```

## 📦 Configurações Disponíveis

### Básicas
- **Gateway** - Entry point para tráfego externo
- **VirtualService** - Roteamento de tráfego
- **DestinationRule** - Load balancing e circuit breaker
- **PeerAuthentication** - mTLS enforcement
- **AuthorizationPolicy** - Controle de acesso

### Avançadas
- **Canary Deployment** - Deploy gradual (90/10)
- **Traffic Mirroring** - Espelhamento de tráfego
- **Fault Injection** - Testes de resiliência
- **JWT Authentication** - Validação de tokens
- **Retry/Timeout Policies** - Políticas de resiliência

## 🎯 Cenários de Uso

### Canary Deployment

```bash
# Aplicar canary (90% v1, 10% v2)
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: dx02-canary
  namespace: dx02
spec:
  hosts:
  - dx02-service
  http:
  - route:
    - destination:
        host: dx02-service
        subset: v1
      weight: 90
    - destination:
        host: dx02-service
        subset: v2
      weight: 10
EOF

# Verificar tráfego
watch -n 1 'curl -s http://INGRESS_IP | grep version'
```

### Circuit Breaker

```bash
# Configurar circuit breaker
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: dx02-circuit-breaker
  namespace: dx02
spec:
  host: dx02-service
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
EOF

# Monitorar ejections
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl localhost:15000/stats | grep outlier
```

### Fault Injection (Testing)

```bash
# Injetar delay de 5s em 10% das requests
kubectl apply -f - <<EOF
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
    route:
    - destination:
        host: dx02-service
EOF

# Testar latência
time curl http://INGRESS_IP
```

## 🔍 Debug

### Verificar Configuração Istio

```bash
# Verificar se sidecar está injetado
kubectl get pods -n dx02 -o jsonpath='{.items[*].spec.containers[*].name}'
# Deve mostrar: app istio-proxy

# Ver configuração do Envoy
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl localhost:15000/config_dump > envoy-config.json

# Verificar rotas
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl localhost:15000/routes
```

### Verificar mTLS

```bash
# Verificar certificados
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl localhost:15000/certs

# Verificar status mTLS
kubectl exec -it <pod-name> -n dx02 -c istio-proxy -- \
  curl localhost:15000/stats | grep ssl
```

### Logs do Envoy Sidecar

```bash
# Ver logs do sidecar
kubectl logs <pod-name> -n dx02 -c istio-proxy

# Logs em tempo real
kubectl logs -f <pod-name> -n dx02 -c istio-proxy --tail=50
```

## 📚 Documentação

Para mais detalhes, consulte:
- [SERVICE_MESH.md](../SERVICE_MESH.md) - Documentação completa
- [Istio Documentation](https://istio.io/latest/docs/)
- [Azure AKS Istio Add-on](https://learn.microsoft.com/en-us/azure/aks/istio-about)

## 🎯 Próximos Passos

1. ✅ Deploy do Service Mesh
2. ✅ Configuração básica (Gateway, VirtualService)
3. ⬜ Implementar Canary Deployment
4. ⬜ Configurar mTLS Strict em todos os namespaces
5. ⬜ Integrar com Grafana para dashboards Istio
6. ⬜ Configurar Authorization Policies
7. ⬜ Implementar rate limiting
8. ⬜ Configurar external service entries

## 💡 Dicas

- Sempre teste configurações em staging primeiro
- Use `kubectl apply` com `--dry-run=client` para validar
- Configure alertas para circuit breakers abertos
- Monitor latency e error rates após mudanças
- Use fault injection em staging para testar resiliência

---

**Criado em:** 24/12/2025  
**Autor:** maringelix
