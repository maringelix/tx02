# 📊 Estratégia de Logs Centralizados

## Visão Geral

Este documento descreve a implementação de logs centralizados no TX02 usando **Azure Log Analytics**. A solução coleta logs de todas as fontes da aplicação e infraestrutura em um único local, facilitando troubleshooting, auditoria e análise de comportamento.

---

## 📋 Índice

1. [Arquitetura](#arquitetura)
2. [Componentes](#componentes)
3. [Configuração](#configuração)
4. [Queries Úteis](#queries-úteis)
5. [Alertas](#alertas)
6. [Custos](#custos)
7. [Integração com Grafana](#integração-com-grafana)
8. [Troubleshooting](#troubleshooting)
9. [Referências](#referências)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                     TX02 Production                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   AKS Pods   │────────▶│ OMS Agent    │                  │
│  │  (DX02 App)  │  logs   │ (Container   │                  │
│  └──────────────┘         │  Insights)   │                  │
│                           └───────┬──────┘                   │
│                                   │                          │
│  ┌──────────────┐                 │                          │
│  │ AKS Control  │─────────────────┤                          │
│  │    Plane     │  diagnostics    │                          │
│  │ (API, etc)   │                 │                          │
│  └──────────────┘                 │                          │
│                                   │                          │
│  ┌──────────────┐                 │                          │
│  │  Azure SQL   │─────────────────┘                          │
│  │  (optional)  │  diagnostics                               │
│  └──────────────┘                                            │
│                                                               │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ▼
            ┌─────────────────────────────┐
            │   Log Analytics Workspace   │
            │      tx02-prd-logs          │
            ├─────────────────────────────┤
            │ - Container logs            │
            │ - Kubernetes events         │
            │ - Control plane logs        │
            │ - Performance metrics       │
            │ - Custom queries            │
            └────────┬────────────────┬───┘
                     │                │
            ┌────────▼─────┐   ┌──────▼──────┐
            │ Azure Portal │   │   Grafana   │
            │   (Logs)     │   │ (optional)  │
            └──────────────┘   └─────────────┘
```

---

## 🧩 Componentes

### 1. **Log Analytics Workspace**
- **Nome:** `tx02-prd-logs`
- **Região:** East US
- **Retenção:** 30-180 dias (configurável)
- **Camada:** Free tier (primeiros 5 GB/mês gratuitos)

### 2. **Container Insights (OMS Agent)**
Coleta logs e métricas de:
- ✅ Logs de containers (stdout/stderr)
- ✅ Eventos do Kubernetes
- ✅ Métricas de performance (CPU, memória, disco, rede)
- ✅ Inventário de pods, nodes, serviços

### 3. **AKS Diagnostic Settings**
Logs do control plane:
- `kube-apiserver` - Logs do API server
- `kube-controller-manager` - Controller manager logs
- `kube-scheduler` - Scheduler logs
- `kube-audit` - Audit logs (acesso à API)
- `cluster-autoscaler` - Autoscaler events

### 4. **Queries KQL (Kusto Query Language)**
Queries salvas para troubleshooting rápido:
- Failed Pods
- Container Error Logs
- High CPU Containers
- Pod Restart Count

---

## ⚙️ Configuração

### Pré-requisitos

1. **AKS Cluster:** `tx02-prd-aks` (já implantado)
2. **Resource Group:** `tx02-prd-rg`
3. **Permissões:** Service Principal com `Contributor` role
4. **Secrets GitHub:**
   - `AZURE_CREDENTIALS` (já configurado)

### Executar Configuração

1. Acesse **GitHub Actions** no repositório TX02
2. Execute workflow: **"📊 Configure Centralized Logging"**
3. Parâmetros:
   - **Environment:** `prd`
   - **Retention days:** `30` (recomendado para começar)
   - **Enable Container Insights:** `true`

### Tempo de Execução
- **Criação inicial:** ~5-10 minutos
- **Atualização:** ~2-3 minutos
- **Propagação de logs:** Até 15 minutos após primeira configuração

---

## 🔍 Queries Úteis

### Acessar Logs

1. Portal Azure → **Log Analytics Workspaces**
2. Selecione `tx02-prd-logs`
3. Menu lateral → **Logs**
4. Execute queries KQL

### Queries Básicas

#### 1. **Logs da Aplicação DX02 (últimas 24h)**
```kql
ContainerLog
| where Name contains "dx02"
| where TimeGenerated > ago(24h)
| project TimeGenerated, Computer, ContainerID, LogEntry
| order by TimeGenerated desc
```

#### 2. **Erros da Aplicação**
```kql
ContainerLog
| where Name contains "dx02"
| where LogEntry has_any ("error", "Error", "ERROR", "exception", "Exception")
| where TimeGenerated > ago(1h)
| project TimeGenerated, LogEntry
| order by TimeGenerated desc
```

#### 3. **Pods com Status Failed**
```kql
KubePodInventory
| where PodStatus == "Failed"
| summarize count() by Name, Namespace, Computer
| order by count_ desc
```

#### 4. **Top 10 Containers por Uso de CPU**
```kql
Perf
| where ObjectName == "K8SContainer" 
| where CounterName == "cpuUsageNanoCores"
| summarize AvgCPU = avg(CounterValue) by Computer, InstanceName
| top 10 by AvgCPU desc
```

#### 5. **Eventos do Kubernetes (últimas 6h)**
```kql
KubeEvents
| where TimeGenerated > ago(6h)
| project TimeGenerated, Namespace, Name, Reason, Message, Type
| order by TimeGenerated desc
```

#### 6. **Pods com Restart Count > 5**
```kql
KubePodInventory
| summarize RestartCount = max(PodRestartCount) by Name, Namespace
| where RestartCount > 5
| order by RestartCount desc
```

#### 7. **Uso de Memória por Namespace**
```kql
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "memoryRssBytes"
| summarize AvgMemoryMB = avg(CounterValue) / 1024 / 1024 by Namespace
| order by AvgMemoryMB desc
```

#### 8. **Logs de Deploy da Aplicação**
```kql
ContainerLog
| where Name contains "dx02"
| where LogEntry has_any ("deployment", "started", "shutdown", "ready", "health")
| where TimeGenerated > ago(2h)
| project TimeGenerated, LogEntry
| order by TimeGenerated desc
```

### Queries Avançadas

#### 9. **Taxa de Erros por Hora (últimas 24h)**
```kql
ContainerLog
| where Name contains "dx02"
| where TimeGenerated > ago(24h)
| extend IsError = iff(LogEntry has_any ("error", "Error", "ERROR"), 1, 0)
| summarize ErrorCount = sum(IsError), TotalLogs = count() by bin(TimeGenerated, 1h)
| extend ErrorRate = round(100.0 * ErrorCount / TotalLogs, 2)
| project TimeGenerated, ErrorCount, TotalLogs, ErrorRate
| order by TimeGenerated desc
```

#### 10. **Correlação entre CPU e Memory por Pod**
```kql
let cpu = Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores"
| summarize AvgCPU = avg(CounterValue) by InstanceName;
let memory = Perf
| where ObjectName == "K8SContainer"
| where CounterName == "memoryRssBytes"
| summarize AvgMemoryMB = avg(CounterValue) / 1024 / 1024 by InstanceName;
cpu
| join kind=inner (memory) on InstanceName
| project InstanceName, AvgCPU, AvgMemoryMB
| order by AvgCPU desc
```

---

## 🚨 Alertas

### Criar Alertas no Portal

1. **Portal Azure** → **Log Analytics Workspace** → `tx02-prd-logs`
2. Menu → **Alerts** → **New alert rule**
3. Configure:
   - **Scope:** tx02-prd-logs workspace
   - **Condition:** Custom log search (KQL query)
   - **Actions:** Email, Slack webhook, etc.

### Exemplos de Alertas Recomendados

#### Alerta 1: Pod Failures
```kql
KubePodInventory
| where PodStatus == "Failed"
| summarize FailedPods = count() by Namespace
| where FailedPods > 0
```
- **Threshold:** > 0 failed pods
- **Frequency:** Every 5 minutes
- **Action:** Send email/Slack notification

#### Alerta 2: High Error Rate
```kql
ContainerLog
| where Name contains "dx02"
| where LogEntry has_any ("error", "Error", "ERROR")
| summarize ErrorCount = count() by bin(TimeGenerated, 5m)
| where ErrorCount > 10
```
- **Threshold:** > 10 errors in 5 minutes
- **Frequency:** Every 5 minutes
- **Action:** Send email/Slack notification

#### Alerta 3: Pod Restarts
```kql
KubePodInventory
| summarize RestartCount = max(PodRestartCount) by Name, Namespace
| where RestartCount > 5
```
- **Threshold:** > 5 restarts
- **Frequency:** Every 15 minutes
- **Action:** Send email notification

#### Alerta 4: High Memory Usage
```kql
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "memoryRssBytes"
| summarize AvgMemoryGB = avg(CounterValue) / 1024 / 1024 / 1024 by InstanceName
| where AvgMemoryGB > 1.5
```
- **Threshold:** > 1.5 GB memory usage
- **Frequency:** Every 10 minutes
- **Action:** Send warning notification

---

## 💰 Custos

### Azure Log Analytics Pricing (East US)

| Componente | Free Tier | Custo Adicional |
|-----------|-----------|-----------------|
| **Ingestão de dados** | 5 GB/mês | $2.30/GB |
| **Retenção (30 dias)** | Incluído | - |
| **Retenção adicional** | - | $0.10/GB/mês |
| **Queries/pesquisas** | Ilimitado | Gratuito |

### Estimativa TX02

**Cenário Conservador (Produção pequena):**
- Logs AKS: ~500 MB/dia
- Logs aplicação: ~200 MB/dia
- Métricas: ~100 MB/dia
- **Total:** ~24 GB/mês
- **Custo:** ~$44/mês (primeiros 5 GB gratuitos)

**Cenário Otimizado:**
- Filtrar logs não-essenciais
- Retenção 30 dias (padrão)
- Usar queries para análise (não exportação)
- **Custo estimado:** $20-40/mês

### Dicas de Redução de Custo

1. **Filtrar logs na origem:**
   - Configure exclusions no OMS agent para logs verbose
   - Evite logging excessivo na aplicação

2. **Retenção inteligente:**
   - 30 dias: Logs operacionais
   - 90 dias: Logs de auditoria
   - Archive (barato): Logs de compliance

3. **Usar queries ao invés de export:**
   - Queries KQL são gratuitas
   - Evite exportação contínua para outros sistemas

4. **Monitorar ingestão:**
   ```kql
   Usage
   | where TimeGenerated > ago(30d)
   | summarize DataGB = sum(Quantity) / 1024 by DataType
   | order by DataGB desc
   ```

---

## 📊 Integração com Grafana

### Adicionar Log Analytics como Data Source

1. **Grafana** → **Configuration** → **Data Sources** → **Add data source**
2. Selecione: **Azure Monitor**
3. Configure:
   - **Authentication:** Service Principal
   - **Directory (tenant) ID:** `<seu_tenant_id>`
   - **Application (client) ID:** `<seu_client_id>`
   - **Client secret:** `<seu_client_secret>`
   - **Default subscription:** `<sua_subscription>`

4. **Test & Save**

### Criar Dashboard de Logs

**Painel 1: Error Rate Over Time**
```kql
ContainerLog
| where Name contains "dx02"
| where TimeGenerated > ago(24h)
| extend IsError = iff(LogEntry has_any ("error", "Error", "ERROR"), 1, 0)
| summarize ErrorCount = sum(IsError) by bin(TimeGenerated, 5m)
| order by TimeGenerated asc
```

**Painel 2: Pod Status Distribution**
```kql
KubePodInventory
| summarize count() by PodStatus
```

**Painel 3: Recent Errors (Table)**
```kql
ContainerLog
| where Name contains "dx02"
| where LogEntry has_any ("error", "Error", "ERROR")
| where TimeGenerated > ago(1h)
| project TimeGenerated, LogEntry
| order by TimeGenerated desc
| take 20
```

### Dashboard Template

```json
{
  "title": "TX02 Application Logs",
  "panels": [
    {
      "type": "timeseries",
      "title": "Error Rate (5min intervals)",
      "targets": [
        {
          "azureLogAnalytics": {
            "query": "ContainerLog | where Name contains \"dx02\" | where TimeGenerated > ago(24h) | extend IsError = iff(LogEntry has_any (\"error\", \"Error\", \"ERROR\"), 1, 0) | summarize ErrorCount = sum(IsError) by bin(TimeGenerated, 5m)"
          }
        }
      ]
    },
    {
      "type": "piechart",
      "title": "Pod Status",
      "targets": [
        {
          "azureLogAnalytics": {
            "query": "KubePodInventory | summarize count() by PodStatus"
          }
        }
      ]
    },
    {
      "type": "table",
      "title": "Recent Errors",
      "targets": [
        {
          "azureLogAnalytics": {
            "query": "ContainerLog | where Name contains \"dx02\" | where LogEntry has_any (\"error\", \"Error\", \"ERROR\") | where TimeGenerated > ago(1h) | project TimeGenerated, LogEntry | order by TimeGenerated desc | take 20"
          }
        }
      ]
    }
  ]
}
```

---

## 🔧 Troubleshooting

### Logs não aparecem no workspace

**Problema:** Container Insights configurado mas sem logs

**Soluções:**
1. Verificar se OMS agent está rodando:
   ```bash
   kubectl get pods -n kube-system | grep omsagent
   ```

2. Verificar configuração do addon:
   ```bash
   az aks show -g tx02-prd-rg -n tx02-prd-aks \
     --query "addonProfiles.omsagent" -o json
   ```

3. Verificar workspace ID correto:
   ```bash
   kubectl get configmap -n kube-system container-azm-ms-agentconfig -o yaml
   ```

4. Aguardar até 15 minutos após primeira configuração

### Queries retornam vazio

**Problema:** Query não retorna dados

**Soluções:**
1. Verificar intervalo de tempo (TimeGenerated)
2. Verificar se nome do container está correto: `Name contains "dx02"`
3. Verificar se tabelas existem:
   ```kql
   search *
   | distinct $table
   | sort by $table asc
   ```

### Custo muito alto

**Problema:** Ingestão de dados acima do esperado

**Soluções:**
1. Identificar fonte de dados:
   ```kql
   Usage
   | where TimeGenerated > ago(7d)
   | summarize DataGB = sum(Quantity) / 1024 by DataType
   | order by DataGB desc
   ```

2. Filtrar logs verbose:
   ```bash
   kubectl edit configmap container-azm-ms-agentconfig -n kube-system
   # Adicionar exclusions
   ```

3. Reduzir retenção:
   ```bash
   az monitor log-analytics workspace update \
     -g tx02-prd-rg -n tx02-prd-logs --retention-time 30
   ```

### OMS Agent crashlooping

**Problema:** `omsagent` pods em CrashLoopBackOff

**Soluções:**
1. Verificar logs do pod:
   ```bash
   kubectl logs -n kube-system <omsagent-pod> --previous
   ```

2. Verificar recursos:
   ```bash
   kubectl describe pod -n kube-system <omsagent-pod>
   ```

3. Re-enable addon:
   ```bash
   az aks disable-addons -g tx02-prd-rg -n tx02-prd-aks --addons monitoring
   az aks enable-addons -g tx02-prd-rg -n tx02-prd-aks --addons monitoring \
     --workspace-resource-id /subscriptions/<sub>/resourceGroups/tx02-prd-rg/providers/Microsoft.OperationalInsights/workspaces/tx02-prd-logs
   ```

---

## 📚 Referências

### Documentação Oficial
- [Azure Monitor Logs Overview](https://docs.microsoft.com/azure/azure-monitor/logs/data-platform-logs)
- [Container Insights Overview](https://docs.microsoft.com/azure/azure-monitor/containers/container-insights-overview)
- [KQL Quick Reference](https://docs.microsoft.com/azure/data-explorer/kql-quick-reference)

### KQL Resources
- [KQL Tutorial](https://docs.microsoft.com/azure/data-explorer/kusto/query/tutorial)
- [KQL Best Practices](https://docs.microsoft.com/azure/data-explorer/kusto/query/best-practices)
- [Sample Queries](https://docs.microsoft.com/azure/azure-monitor/logs/example-queries)

### Integração
- [Azure Monitor Data Source for Grafana](https://grafana.com/grafana/plugins/grafana-azure-monitor-datasource/)
- [Container Insights Metrics](https://docs.microsoft.com/azure/azure-monitor/containers/container-insights-analyze)

---

## 🎯 Próximos Passos

1. ✅ **Executar workflow de configuração**
2. ⏳ **Aguardar propagação de logs** (15 minutos)
3. ⏳ **Testar queries básicas** no portal Azure
4. ⏳ **Criar alertas essenciais** (pod failures, errors)
5. ⏳ **Integrar com Grafana** (opcional)
6. ⏳ **Configurar log retention** de acordo com necessidade
7. ⏳ **Monitorar custos** e ajustar filtros se necessário

---

## 📊 Checklist de Implementação

- [ ] Executar workflow `configure-logging.yml`
- [ ] Verificar workspace criado no portal Azure
- [ ] Confirmar OMS agent rodando no AKS
- [ ] Testar query de logs da aplicação DX02
- [ ] Criar alerta de pod failures
- [ ] Criar alerta de high error rate
- [ ] Documentar queries customizadas do time
- [ ] Integrar com Grafana (opcional)
- [ ] Revisar custos após 1 semana
- [ ] Configurar backup de queries importantes

---

**Data de Criação:** 2025-12-22  
**Última Atualização:** 2025-12-22  
**Versão:** 1.0  
**Autor:** DevOps Team - TX02
