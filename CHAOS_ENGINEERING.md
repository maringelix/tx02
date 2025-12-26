# 🔥 Chaos Engineering - Azure Chaos Studio & Chaos Mesh

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Custos](#custos)
- [Arquitetura](#arquitetura)
- [Tipos de Experimentos](#tipos-de-experimentos)
- [Como Usar](#como-usar)
- [Experimentos Disponíveis](#experimentos-disponíveis)
- [Métricas e Observabilidade](#métricas-e-observabilidade)
- [Melhores Práticas](#melhores-práticas)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

Chaos Engineering é a disciplina de experimentar em um sistema para construir confiança na capacidade do sistema de resistir a condições turbulentas em produção.

### Por que Chaos Engineering?

- ✅ **Identificar pontos fracos** antes que causem incidentes
- ✅ **Validar resiliência** da aplicação e infraestrutura
- ✅ **Melhorar observabilidade** através de testes em condições adversas
- ✅ **Aumentar confiança** na capacidade de recuperação do sistema
- ✅ **Documentar comportamento** do sistema sob stress

### Ferramentas Utilizadas

**Azure Chaos Studio**
- Plataforma gerenciada da Microsoft para Chaos Engineering
- Integração nativa com recursos Azure (AKS, VMs, etc)
- Interface web para gerenciar experimentos
- Custo: ~$0.40 USD por hora de experimento

**Chaos Mesh**
- Framework open-source CNCF para Kubernetes
- Mais flexível e customizável
- Gratuito (apenas custos de infraestrutura)
- Dashboard web integrado

---

## 💰 Custos

### Estimativa de Custos

| Componente | Custo Estimado | Período |
|------------|---------------|---------|
| Azure Chaos Studio | $0.40/hora | Por experimento ativo |
| Chaos Mesh (OSS) | $0.00 | Gratuito |
| AKS (já existente) | $0.00 | Sem custo adicional |
| Monitoramento adicional | ~$5/mês | Azure Monitor logs extras |
| **Total estimado** | **~$10-20** | **Para testes completos** |

### Com R$400 de crédito você pode:
- ✅ Executar ~50 horas de experimentos no Azure Chaos Studio
- ✅ Rodar Chaos Mesh ilimitadamente (open source)
- ✅ Fazer testes extensivos por vários dias
- ✅ Implementar e validar melhorias iterativamente

### Otimização de Custos

1. **Use Chaos Mesh para testes iniciais** (gratuito)
2. **Azure Chaos Studio para testes avançados** (pago mas gerenciado)
3. **Execute experimentos em horários específicos** (não deixe 24/7)
4. **Use dry-run para validar sem executar** (custo zero)
5. **Cleanup automático após experimentos** (evita custos residuais)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions                            │
│                                                              │
│  Workflow: chaos-engineering.yml                            │
│  ├─ Setup Chaos Studio                                      │
│  ├─ Install Chaos Mesh                                      │
│  ├─ Run Experiments                                         │
│  └─ Validate & Cleanup                                      │
│                          │                                   │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   Azure AKS Cluster                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Namespace: chaos-testing                               │ │
│  │                                                        │ │
│  │  Chaos Mesh Components:                                │ │
│  │  ├─ Chaos Controller Manager                          │ │
│  │  ├─ Chaos Daemon (on each node)                       │ │
│  │  ├─ Chaos Dashboard                                   │ │
│  │  └─ CRDs (PodChaos, NetworkChaos, StressChaos, etc)  │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Namespace: dx02 (Target Application)                   │ │
│  │                                                        │ │
│  │  ├─ Pod 1 (dx02-app)  ← 🎲 Chaos Experiments          │ │
│  │  ├─ Pod 2 (dx02-app)  ← 🌐 Network Latency            │ │
│  │  └─ Service           ← 🔥 CPU/Memory Stress          │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ↓
┌─────────────────────────────────────────────────────────────┐
│           Observability Stack (Prometheus + Grafana)         │
│                                                              │
│  ├─ Métricas de performance                                 │
│  ├─ Alertas durante experimentos                           │
│  ├─ Dashboards de resiliência                              │
│  └─ Logs de recuperação                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎲 Tipos de Experimentos

### 1. **Pod Chaos** (Falhas de Pods)
**Objetivo**: Validar recuperação automática de pods

**Ações disponíveis**:
- `pod-kill`: Mata pods aleatoriamente
- `pod-failure`: Simula falha completa do pod
- `container-kill`: Mata container específico

**Casos de uso**:
- Testar HPA (Horizontal Pod Autoscaler)
- Validar readiness/liveness probes
- Verificar service mesh failover

### 2. **Network Chaos** (Falhas de Rede)
**Objetivo**: Testar resiliência a problemas de rede

**Ações disponíveis**:
- `delay`: Injeta latência (ex: 200ms)
- `loss`: Perda de pacotes (ex: 30%)
- `duplicate`: Duplicação de pacotes
- `corrupt`: Corrupção de pacotes
- `partition`: Partição de rede (split-brain)

**Casos de uso**:
- Testar timeouts e retries
- Validar circuit breakers
- Simular rede lenta/instável

### 3. **Stress Chaos** (Stress de Recursos)
**Objetivo**: Validar comportamento sob alta carga

**Ações disponíveis**:
- `cpu`: Stress de CPU (ex: 80%)
- `memory`: Stress de memória (ex: 256MB)

**Casos de uso**:
- Testar resource limits
- Validar OOM (Out of Memory) handling
- Verificar throttling e QoS

### 4. **IO Chaos** (Falhas de I/O)
**Objetivo**: Simular problemas de disco

**Ações disponíveis**:
- `delay`: Latência em operações de I/O
- `errno`: Retorna erros em operações de disco
- `mixed`: Combinação de delays e erros

### 5. **Time Chaos** (Manipulação de Tempo)
**Objetivo**: Testar comportamento dependente de tempo

**Ações disponíveis**:
- `offset`: Avança ou atrasa o relógio do sistema

**Casos de uso**:
- Testar expirações de cache
- Validar timeouts
- Verificar agendamentos

---

## 🚀 Como Usar

### Pré-requisitos

1. **Azure Subscription** com créditos disponíveis
2. **AKS Cluster** rodando (tx02-prd-aks)
3. **GitHub Secrets** configurados:
   - `AZURE_CREDENTIALS`: Service Principal

### Executar via GitHub Actions

1. Acesse: **Actions → 🔥 Azure Chaos Engineering**
2. Clique em **Run workflow**
3. Configure os parâmetros:
   - **environment**: `prd` ou `stg`
   - **experiment_type**: Tipo de experimento
   - **duration_minutes**: Duração (recomendado: 5-10 min)
   - **dry_run**: `true` para validar sem executar

### Exemplo: Primeiro Teste (Dry Run)

```yaml
Environment: prd
Experiment Type: pod-chaos
Duration: 5 minutes
Dry Run: true  ← Valida sem executar
```

**O que acontece**:
1. ✅ Instala Chaos Mesh no cluster
2. ✅ Cria experimento de Pod Chaos
3. ✅ Valida configuração
4. ✅ **NÃO executa** (dry run)
5. ✅ Limpa recursos

### Exemplo: Teste Real

```yaml
Environment: prd
Experiment Type: all-experiments
Duration: 10 minutes
Dry Run: false  ← Executa de verdade!
```

**O que acontece**:
1. 🔥 Mata pods aleatoriamente a cada 2 minutos
2. 🌐 Injeta latência de rede (200ms)
3. 🔥 Aplica stress de CPU (80%)
4. 💾 Aplica stress de memória (256MB)
5. 📊 Monitora comportamento do sistema
6. 🧹 Faz cleanup automático ao final

---

## 📋 Experimentos Disponíveis

### Pod Chaos

**Objetivo**: Testar recuperação de falhas de pods

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-experiment
spec:
  action: pod-kill
  mode: one            # mata 1 pod por vez
  duration: "5m"
  selector:
    namespaces:
      - dx02
    labelSelectors:
      "app": "dx02"
  scheduler:
    cron: "@every 2m"  # repete a cada 2 minutos
```

**Métricas a observar**:
- Tempo de recuperação do pod
- Disponibilidade do serviço
- Requests com erro (se houver)
- Alertas disparados

### Network Latency

**Objetivo**: Testar resiliência a latência de rede

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-latency-experiment
spec:
  action: delay
  mode: one
  duration: "5m"
  selector:
    namespaces:
      - dx02
  delay:
    latency: "200ms"   # latência base
    correlation: "0"
    jitter: "50ms"     # variação de latência
```

**Métricas a observar**:
- Response time do endpoint
- Timeouts de requisições
- Circuit breaker activations
- User experience impact

### CPU Stress

**Objetivo**: Validar throttling e resource limits

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress-experiment
spec:
  mode: one
  duration: "5m"
  selector:
    namespaces:
      - dx02
  stressors:
    cpu:
      workers: 2       # 2 workers gerando carga
      load: 80         # 80% de CPU por worker
```

**Métricas a observar**:
- CPU throttling
- Response time degradation
- HPA scaling triggers
- Resource limit violations

### Memory Stress

**Objetivo**: Testar limites de memória e OOM handling

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: memory-stress-experiment
spec:
  mode: one
  duration: "5m"
  selector:
    namespaces:
      - dx02
  stressors:
    memory:
      workers: 1
      size: "256MB"    # consome 256MB
```

**Métricas a observar**:
- Memory usage
- OOM kills
- Pod restarts
- Performance degradation

---

## 📊 Métricas e Observabilidade

### Prometheus Queries

**Taxa de erro durante experimento**:
```promql
rate(http_requests_total{status=~"5.."}[5m])
```

**Latência P99 durante experimento**:
```promql
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

**Pod restarts durante experimento**:
```promql
increase(kube_pod_container_status_restarts_total{namespace="dx02"}[10m])
```

**CPU throttling**:
```promql
rate(container_cpu_cfs_throttled_seconds_total{namespace="dx02"}[5m])
```

### Grafana Dashboards

**Dashboard recomendado**: Kubernetes Cluster Monitoring

**Painéis importantes**:
1. **Pod Health**: Uptime, restarts, ready status
2. **Response Time**: P50, P95, P99 latency
3. **Error Rate**: 5xx errors, timeouts
4. **Resource Usage**: CPU, Memory, Network
5. **HPA**: Current replicas, desired replicas

### Azure Monitor

**Queries KQL úteis**:

```kql
// Erros durante experimento
ContainerLog
| where Namespace == "dx02"
| where LogEntry contains "error"
| summarize count() by bin(TimeGenerated, 1m)
```

```kql
// Pod events durante experimento
KubePodInventory
| where Namespace == "dx02"
| where TimeGenerated > ago(30m)
| project TimeGenerated, Name, PodStatus
```

---

## ✅ Melhores Práticas

### Antes de Executar

1. **✅ Comunicar ao time**: Avise sobre o experimento
2. **✅ Horário adequado**: Evite horários de pico (se produção)
3. **✅ Monitoramento ativo**: Tenha Grafana aberto
4. **✅ Backup de dados**: Certifique-se que backups estão ok
5. **✅ Rollback plan**: Tenha plano de reversão

### Durante o Experimento

1. **📊 Monitore métricas** em tempo real
2. **📝 Documente comportamentos** inesperados
3. **⏱️ Respeite o tempo** definido (não prolongue sem motivo)
4. **🚨 Esteja pronto para abortar** se necessário

### Após o Experimento

1. **🧹 Cleanup**: Certifique-se que recursos foram limpos
2. **📈 Analise métricas**: Compare before/during/after
3. **📝 Documente aprendizados**: O que funcionou/falhou
4. **🔧 Implemente melhorias**: Baseado nos resultados
5. **♻️ Repita**: Valide que melhorias funcionaram

### Princípios de Chaos Engineering

1. **Comece pequeno**: Dry run → Um experimento → Todos
2. **Aumente gradualmente**: 1 pod → Múltiplos pods → Node
3. **Automatize**: Use GitHub Actions para repetibilidade
4. **Minimize blast radius**: Limite escopo dos experimentos
5. **Aprenda com falhas**: Cada falha é uma oportunidade

---

## 🛠️ Troubleshooting

### Chaos Mesh não instala

**Erro**: `CRDs already exist`

**Solução**:
```bash
# Limpar instalação anterior
helm uninstall chaos-mesh -n chaos-testing
kubectl delete namespace chaos-testing
kubectl delete crd $(kubectl get crd | grep chaos-mesh | awk '{print $1}')

# Reinstalar
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-testing --create-namespace
```

### Experimento não funciona

**Erro**: `Selector não encontra pods`

**Solução**:
```bash
# Verificar labels dos pods
kubectl get pods -n dx02 --show-labels

# Ajustar selector no experimento para match com labels reais
```

### Azure Chaos Studio não habilita

**Erro**: `403 Forbidden`

**Solução**:
```bash
# Garantir que Service Principal tem permissões
az role assignment create \
  --assignee <service-principal-id> \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>
```

### Pods não se recuperam

**Problema**: Pods mortos não voltam

**Solução**:
```bash
# Verificar HPA
kubectl get hpa -n dx02

# Verificar resource limits
kubectl describe deployment dx02 -n dx02

# Verificar eventos
kubectl get events -n dx02 --sort-by='.lastTimestamp'
```

### Performance degradada após experimento

**Problema**: Sistema lento mesmo após cleanup

**Solução**:
```bash
# Verificar chaos experiments ativos
kubectl get podchaos,networkchaos,stresschaos --all-namespaces

# Forçar delete se necessário
kubectl delete podchaos --all --all-namespaces
kubectl delete networkchaos --all --all-namespaces
kubectl delete stresschaos --all --all-namespaces

# Restart dos pods se necessário
kubectl rollout restart deployment/dx02 -n dx02
```

---

## 📚 Recursos Adicionais

### Documentação Oficial

- [Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/)
- [Chaos Mesh](https://chaos-mesh.org/docs/)
- [Principles of Chaos Engineering](https://principlesofchaos.org/)

### Tutoriais e Guias

- [Chaos Engineering with Kubernetes](https://kubernetes.io/blog/2020/12/02/chaos-engineering-with-kubernetes/)
- [Getting Started with Chaos Mesh](https://chaos-mesh.org/docs/quick-start/)
- [Azure AKS Chaos Testing](https://learn.microsoft.com/en-us/azure/architecture/framework/resiliency/chaos-engineering)

### Ferramentas Relacionadas

- **Litmus**: Outra ferramenta CNCF para Chaos Engineering
- **Gremlin**: Plataforma comercial para Chaos Engineering
- **Pumba**: Chaos testing para containers Docker

---

## 🎯 Próximos Passos

Após implementar Chaos Engineering, considere:

1. **🔄 Chaos Experiments Agendados**: Executar automaticamente em horários específicos
2. **📊 Game Days**: Sessões dedicadas de teste de resiliência com o time
3. **🤖 Chaos Automation**: Integrar no pipeline CI/CD
4. **📈 SLO/SLA Validation**: Usar chaos para validar SLOs definidos
5. **🌐 Multi-Region Chaos**: Testar failover entre regiões

---

## 💡 Dicas Finais

### Para o seu budget de R$400:

1. **Use Chaos Mesh primeiro** (gratuito, open source)
2. **Azure Chaos Studio apenas para testes avançados** (pago)
3. **Execute experimentos curtos** (5-10 minutos)
4. **Dry run sempre antes de executar** (evita surpresas)
5. **Cleanup automático** (evita custos desnecessários)

### Experimentos recomendados (em ordem):

1. ✅ **Pod Chaos (dry run)** - Validar configuração
2. ✅ **Pod Chaos (real)** - Testar recuperação
3. ✅ **Network Latency** - Testar timeouts
4. ✅ **CPU Stress** - Testar resource limits
5. ✅ **All Experiments** - Teste completo

**Custo estimado total**: ~$10-15 USD para todos os testes

---

**Última atualização**: 26/12/2025  
**Status**: ✅ Pronto para uso  
**Custo estimado**: ~$10-20 USD para testes completos
