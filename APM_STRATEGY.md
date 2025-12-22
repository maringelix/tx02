# 📈 Application Performance Monitoring (APM) Strategy

## Visão Geral

Este documento descreve a implementação de **Azure Application Insights** para monitoramento de performance da aplicação DX02. Application Insights fornece telemetria detalhada, distributed tracing, detecção de anomalias, e insights sobre o comportamento da aplicação em produção.

---

## 📋 Índice

1. [Arquitetura](#arquitetura)
2. [Componentes](#componentes)
3. [Configuração](#configuração)
4. [Integração com Aplicação](#integração-com-aplicação)
5. [Dashboards e Métricas](#dashboards-e-métricas)
6. [Alertas](#alertas)
7. [Custos](#custos)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)
10. [Referências](#referências)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    DX02 Application                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   React      │         │   Node.js    │                  │
│  │  Frontend    │────────▶│   Backend    │                  │
│  │              │         │              │                  │
│  │ AppInsights  │         │ AppInsights  │                  │
│  │    SDK       │         │    SDK       │                  │
│  └───────┬──────┘         └───────┬──────┘                  │
│          │                        │                          │
│          │   Telemetry            │                          │
│          └────────┬───────────────┘                          │
│                   │                                          │
└───────────────────┼──────────────────────────────────────────┘
                    │
                    ▼
    ┌───────────────────────────────┐
    │   Application Insights        │
    │   tx02-prd-appinsights       │
    ├───────────────────────────────┤
    │ - Request telemetry           │
    │ - Dependency tracking         │
    │ - Exception logging           │
    │ - Custom events               │
    │ - Performance counters        │
    │ - User analytics              │
    └────────┬──────────────────────┘
             │
             ▼
    ┌───────────────────────────────┐
    │   Log Analytics Workspace     │
    │      tx02-prd-logs           │
    ├───────────────────────────────┤
    │ - Unified telemetry           │
    │ - Cross-component correlation │
    │ - Advanced queries (KQL)      │
    └────────┬──────────────────────┘
             │
    ┌────────▼─────┐   ┌──────────────┐   ┌─────────────┐
    │ Application  │   │  Live        │   │  Grafana    │
    │ Map          │   │  Metrics     │   │  (optional) │
    └──────────────┘   └──────────────┘   └─────────────┘
```

---

## 🧩 Componentes

### 1. **Application Insights Resource**
- **Nome:** `tx02-prd-appinsights`
- **Tipo:** Web application
- **Região:** East US
- **Retenção:** 90 dias

### 2. **SDK Components**

#### Backend (Node.js)
- Package: `applicationinsights`
- Features: Automatic request tracking, dependency tracking, exception logging

#### Frontend (React)
- Package: `@microsoft/applicationinsights-web`
- Features: Page views, AJAX calls, user sessions, custom events

### 3. **Telemetry Types**

| Tipo | Descrição | Uso |
|------|-----------|-----|
| **Requests** | HTTP requests (API calls) | Performance, response times |
| **Dependencies** | External calls (DB, APIs) | Latency, failures |
| **Exceptions** | Unhandled errors | Error tracking, debugging |
| **Traces** | Custom log messages | Application flow |
| **Events** | Custom business events | User actions, features |
| **Metrics** | Performance counters | CPU, memory, custom KPIs |
| **Page Views** | Frontend navigation | User experience |

---

## ⚙️ Configuração

### Pré-requisitos

1. **Log Analytics Workspace:** `tx02-prd-logs` (já criado)
2. **AKS Cluster:** `tx02-prd-aks` (já implantado)
3. **Aplicação DX02:** Rodando no AKS

### Executar Configuração

1. Acesse **GitHub Actions** no repositório TX02
2. Execute workflow: **"📈 Configure Application Performance Monitoring"**
3. Parâmetros:
   - **Environment:** `prd`
   - **Sampling percentage:** `50` (recomendado para começar)

### Tempo de Execução
- **Criação:** ~2-3 minutos
- **Propagação de telemetria:** 5-10 minutos após integração da app

---

## 🔌 Integração com Aplicação

### Backend (Node.js/Express)

#### 1. Instalar SDK
```bash
npm install applicationinsights --save
```

#### 2. Inicializar no código (início do app)
```javascript
// server/index.js (PRIMEIRO import)
const appInsights = require('applicationinsights');

// Initialize with connection string from environment
appInsights.setup(process.env.APPINSIGHTS_CONNECTION_STRING)
  .setAutoDependencyCorrelation(true)
  .setAutoCollectRequests(true)
  .setAutoCollectPerformance(true, true)
  .setAutoCollectExceptions(true)
  .setAutoCollectDependencies(true)
  .setAutoCollectConsole(true, true)
  .setUseDiskRetryCaching(true)
  .setSendLiveMetrics(true)
  .setDistributedTracingMode(appInsights.DistributedTracingModes.AI_AND_W3C);

// Set sampling percentage (reduce cost)
appInsights.defaultClient.config.samplingPercentage = 50; // 50% sampling

appInsights.start();

console.log('✅ Application Insights initialized');

// Your Express app setup continues...
const express = require('express');
const app = express();
```

#### 3. Configurar environment variable no Kubernetes
```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dx02-backend
spec:
  template:
    spec:
      containers:
      - name: backend
        image: tx02prdacr.azurecr.io/dx02-backend:latest
        env:
        - name: APPINSIGHTS_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: appinsights-config
              key: connection-string
        - name: NODE_ENV
          value: "production"
```

#### 4. Custom tracking (opcional)
```javascript
const appInsights = require('applicationinsights');
const client = appInsights.defaultClient;

// Track custom event
client.trackEvent({
  name: 'UserLogin',
  properties: {
    userId: user.id,
    method: 'oauth'
  }
});

// Track custom metric
client.trackMetric({
  name: 'OrdersProcessed',
  value: ordersCount
});

// Track custom trace
client.trackTrace({
  message: 'Processing large dataset',
  severity: appInsights.Contracts.SeverityLevel.Information,
  properties: { recordCount: 5000 }
});

// Track exception with context
try {
  // risky operation
} catch (error) {
  client.trackException({
    exception: error,
    properties: { userId: req.user.id }
  });
}
```

### Frontend (React)

#### 1. Instalar SDK
```bash
npm install @microsoft/applicationinsights-web --save
```

#### 2. Criar serviço de telemetria
```javascript
// client/src/services/telemetry.js
import { ApplicationInsights } from '@microsoft/applicationinsights-web';
import { ReactPlugin } from '@microsoft/applicationinsights-react-js';

const reactPlugin = new ReactPlugin();

const appInsights = new ApplicationInsights({
  config: {
    connectionString: process.env.REACT_APP_APPINSIGHTS_CONNECTION_STRING,
    enableAutoRouteTracking: true, // Track route changes
    enableCorsCorrelation: true, // Correlate with backend
    enableRequestHeaderTracking: true,
    enableResponseHeaderTracking: true,
    samplingPercentage: 50, // 50% sampling
    extensions: [reactPlugin]
  }
});

appInsights.loadAppInsights();

// Set authenticated user context (after login)
export const setAuthenticatedUser = (userId, accountId) => {
  appInsights.setAuthenticatedUserContext(userId, accountId, true);
};

// Track custom page view
export const trackPageView = (name, properties) => {
  appInsights.trackPageView({ name, properties });
};

// Track custom event
export const trackEvent = (name, properties) => {
  appInsights.trackEvent({ name }, properties);
};

// Track exception
export const trackException = (error, severityLevel = 3) => {
  appInsights.trackException({ 
    exception: error,
    severityLevel 
  });
};

export { appInsights, reactPlugin };
```

#### 3. Inicializar na aplicação
```javascript
// client/src/index.js
import React from 'react';
import ReactDOM from 'react-dom';
import { AppInsightsContext } from '@microsoft/applicationinsights-react-js';
import { reactPlugin } from './services/telemetry';
import App from './App';

ReactDOM.render(
  <React.StrictMode>
    <AppInsightsContext.Provider value={reactPlugin}>
      <App />
    </AppInsightsContext.Provider>
  </React.StrictMode>,
  document.getElementById('root')
);
```

#### 4. Usar em componentes
```javascript
// client/src/components/Dashboard.jsx
import React, { useEffect } from 'react';
import { useAppInsightsContext } from '@microsoft/applicationinsights-react-js';
import { trackEvent, trackException } from '../services/telemetry';

function Dashboard() {
  const appInsights = useAppInsightsContext();
  
  useEffect(() => {
    // Track page view
    trackEvent('DashboardViewed', { userId: currentUser.id });
  }, []);
  
  const handleButtonClick = () => {
    try {
      // business logic
      trackEvent('FeatureUsed', { feature: 'ExportData' });
    } catch (error) {
      trackException(error);
    }
  };
  
  return <div>Dashboard content</div>;
}
```

#### 5. Configurar variável de ambiente
```bash
# client/.env.production
REACT_APP_APPINSIGHTS_CONNECTION_STRING=<connection-string-from-workflow>
```

### Deploy Atualizado

Após integração do SDK:
```bash
# Rebuild images
docker build -t tx02prdacr.azurecr.io/dx02-backend:latest ./server
docker build -t tx02prdacr.azurecr.io/dx02-frontend:latest ./client

# Push to ACR
docker push tx02prdacr.azurecr.io/dx02-backend:latest
docker push tx02prdacr.azurecr.io/dx02-frontend:latest

# Restart deployment
kubectl rollout restart deployment dx02-backend -n dx02
kubectl rollout restart deployment dx02-frontend -n dx02
```

---

## 📊 Dashboards e Métricas

### Acessar Portal Azure

1. **Portal Azure** → **Application Insights** → `tx02-prd-appinsights`
2. Principais seções:

#### Live Metrics
- **Real-time performance** (latência, requests/sec, failures)
- **Incoming requests** por segundo
- **Outgoing dependencies** (DB, APIs)
- **Overall health** do sistema

#### Application Map
- **Visualização de dependências** entre componentes
- **Health status** de cada componente
- **Performance** de cada conexão
- **Failure rates** entre serviços

#### Performance
- **Response times** por endpoint
- **Slowest operations** (p95, p99)
- **Server response time** trends
- **Dependency duration** analysis

#### Failures
- **Exception rate** over time
- **Failed requests** by type
- **Dependency failures** (DB timeouts, API errors)
- **Exception details** com stack traces

#### Transaction Search
- **End-to-end transactions** com correlação
- **Request timeline** (backend + frontend + dependencies)
- **Custom properties** para filtrar
- **Logs and traces** associados

#### Availability
- **Uptime percentage** (se configurado)
- **Health check results** por região
- **Response time** por location
- **Alert triggers**

#### Usage
- **Users, sessions, page views**
- **User retention** (daily/weekly/monthly)
- **Funnels** (conversion tracking)
- **Impact analysis** (performance vs retention)

### KQL Queries Úteis

#### 1. **Request performance por endpoint**
```kql
requests
| where timestamp > ago(24h)
| summarize 
    RequestCount = count(),
    AvgDuration = avg(duration),
    P50 = percentile(duration, 50),
    P95 = percentile(duration, 95),
    P99 = percentile(duration, 99)
    by name
| order by AvgDuration desc
```

#### 2. **Top 10 slowest dependencies**
```kql
dependencies
| where timestamp > ago(24h)
| summarize 
    CallCount = count(),
    AvgDuration = avg(duration),
    P95 = percentile(duration, 95)
    by name, type
| order by P95 desc
| take 10
```

#### 3. **Exception rate over time**
```kql
exceptions
| where timestamp > ago(24h)
| summarize ExceptionCount = count() by bin(timestamp, 5m)
| render timechart
```

#### 4. **Failed requests with details**
```kql
requests
| where success == false
| where timestamp > ago(1h)
| project timestamp, name, resultCode, duration, customDimensions
| order by timestamp desc
```

#### 5. **User journey (page view funnel)**
```kql
pageViews
| where timestamp > ago(24h)
| project timestamp, name, user_Id, session_Id
| order by timestamp asc
```

#### 6. **Database query performance**
```kql
dependencies
| where type == "SQL"
| where timestamp > ago(24h)
| summarize 
    Count = count(),
    AvgMs = avg(duration),
    P95Ms = percentile(duration, 95)
    by name
| where P95Ms > 100  // Queries slower than 100ms
| order by P95Ms desc
```

#### 7. **Error correlation (end-to-end)**
```kql
union requests, dependencies, exceptions
| where timestamp > ago(1h)
| where operation_Id == "<operation-id-from-failed-request>"
| project timestamp, itemType, name, success, duration
| order by timestamp asc
```

#### 8. **Custom event analysis**
```kql
customEvents
| where timestamp > ago(7d)
| where name == "UserLogin"
| summarize LoginCount = count() by tostring(customDimensions.method)
| render piechart
```

---

## 🚨 Alertas

### Alertas Recomendados

#### Alerta 1: High Response Time
```kql
requests
| where timestamp > ago(5m)
| summarize AvgDuration = avg(duration)
| where AvgDuration > 2000  // 2 seconds
```
- **Threshold:** Avg response time > 2s
- **Frequency:** Every 5 minutes
- **Action:** Email + Slack notification

#### Alerta 2: High Error Rate
```kql
requests
| where timestamp > ago(5m)
| summarize 
    TotalRequests = count(),
    FailedRequests = countif(success == false)
| extend ErrorRate = (FailedRequests * 100.0) / TotalRequests
| where ErrorRate > 5  // 5% error rate
```
- **Threshold:** Error rate > 5%
- **Frequency:** Every 5 minutes
- **Action:** Email + Slack + PagerDuty

#### Alerta 3: Dependency Failure
```kql
dependencies
| where timestamp > ago(5m)
| where success == false
| where type == "SQL"  // Database failures
| summarize FailureCount = count()
| where FailureCount > 3
```
- **Threshold:** > 3 DB failures in 5 min
- **Frequency:** Every 5 minutes
- **Action:** Immediate notification

#### Alerta 4: Exception Spike
```kql
exceptions
| where timestamp > ago(5m)
| summarize ExceptionCount = count()
| where ExceptionCount > 10
```
- **Threshold:** > 10 exceptions in 5 min
- **Frequency:** Every 5 minutes
- **Action:** Slack notification

### Configurar Alertas no Portal

1. **Application Insights** → `tx02-prd-appinsights`
2. **Alerts** → **New alert rule**
3. **Condition:** Custom log search (use KQL queries above)
4. **Action group:** Email, Slack webhook, etc.
5. **Alert details:** Name, description, severity

---

## 💰 Custos

### Azure Application Insights Pricing

| Componente | Free Tier | Custo Adicional |
|-----------|-----------|-----------------|
| **Ingestão de dados** | 5 GB/mês | $2.30/GB |
| **Retenção (90 dias)** | Incluído | - |
| **Live Metrics Stream** | Gratuito | - |
| **Availability tests** | 1 teste grátis | $1.20/teste/mês |
| **Multi-step web tests** | - | $4.80/teste/mês |

### Estimativa TX02

**Cenário com Sampling 50%:**
- Backend requests: ~1 GB/mês
- Frontend page views: ~500 MB/mês
- Dependencies: ~500 MB/mês
- Exceptions/traces: ~200 MB/mês
- **Total:** ~2.2 GB/mês
- **Custo:** $0/mês (dentro do free tier)

**Cenário Sampling 100% (sem sampling):**
- Total: ~4.4 GB/mês
- **Custo:** $0/mês (ainda dentro do free tier)

**Se exceder 5 GB:**
- 10 GB/mês = $11.50/mês
- 15 GB/mês = $23/mês

### Estratégias de Redução de Custo

1. **Adaptive Sampling** (recomendado)
   ```javascript
   appInsights.defaultClient.config.samplingPercentage = 50;
   ```

2. **Telemetry Processors** (filtrar dados não-essenciais)
   ```javascript
   appInsights.defaultClient.addTelemetryProcessor((envelope) => {
     // Skip health check requests
     if (envelope.data.baseType === 'RequestData') {
       if (envelope.data.baseData.name.includes('/health')) {
         return false; // Don't send
       }
     }
     return true;
   });
   ```

3. **Smart Sampling** (AI-driven)
   - Mantém traces completos de transações com erros
   - Reduz traces de transações bem-sucedidas
   - Configurado automaticamente

4. **Reduzir Retenção**
   ```bash
   az monitor app-insights component update \
     --app tx02-prd-appinsights \
     -g tx02-prd-rg \
     --retention-time 30  # 30 dias ao invés de 90
   ```

---

## 🎯 Best Practices

### 1. **Correlation IDs**
```javascript
// Backend: propagate correlation ID
app.use((req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] || uuidv4();
  res.setHeader('x-correlation-id', req.correlationId);
  next();
});
```

### 2. **Custom Properties**
```javascript
// Add context to all telemetry
appInsights.defaultClient.commonProperties = {
  environment: 'production',
  version: process.env.APP_VERSION,
  region: 'eastus'
};
```

### 3. **User Identification**
```javascript
// Frontend: track authenticated users
appInsights.setAuthenticatedUserContext(userId, accountId, true);
```

### 4. **Performance Counters**
```javascript
// Backend: track custom metrics
client.trackMetric({
  name: 'QueueDepth',
  value: queue.length
});
```

### 5. **Error Handling**
```javascript
// Global error handler
app.use((err, req, res, next) => {
  appInsights.defaultClient.trackException({
    exception: err,
    properties: {
      url: req.url,
      method: req.method,
      userId: req.user?.id
    }
  });
  res.status(500).send('Internal Server Error');
});
```

### 6. **Sampling Strategy**
- **Development:** 100% (debug tudo)
- **Staging:** 50-100% (validação completa)
- **Production:** 25-50% (custo controlado)
- **High traffic:** 10-25% (otimização máxima)

---

## 🔧 Troubleshooting

### Telemetria não aparece

**Problema:** Nenhum dado no Application Insights após 10 minutos

**Soluções:**
1. Verificar connection string:
   ```bash
   kubectl get secret appinsights-config -n dx02 -o jsonpath='{.data.connection-string}' | base64 -d
   ```

2. Verificar logs da aplicação:
   ```bash
   kubectl logs -n dx02 <pod-name> | grep -i "application insights"
   ```

3. Verificar SDK inicializado:
   ```javascript
   console.log('AppInsights enabled:', appInsights.defaultClient !== undefined);
   ```

### Dados incompletos

**Problema:** Apenas alguns tipos de telemetria aparecem

**Soluções:**
1. Verificar auto-collection habilitado:
   ```javascript
   appInsights.setup(connectionString)
     .setAutoCollectRequests(true)
     .setAutoCollectDependencies(true)
     .setAutoCollectExceptions(true);
   ```

2. Verificar sampling:
   ```javascript
   // Não deve ser 0
   console.log('Sampling:', appInsights.defaultClient.config.samplingPercentage);
   ```

### High latency em telemetria

**Problema:** App fica lento após adicionar SDK

**Soluções:**
1. Usar batching:
   ```javascript
   appInsights.defaultClient.config.maxBatchSize = 100;
   appInsights.defaultClient.config.maxBatchIntervalMs = 10000;
   ```

2. Desabilitar console tracking:
   ```javascript
   appInsights.setup(connectionString)
     .setAutoCollectConsole(false); // Remove overhead
   ```

3. Aumentar sampling:
   ```javascript
   appInsights.defaultClient.config.samplingPercentage = 25; // Reduz para 25%
   ```

### Correlation não funciona

**Problema:** Não consegue correlacionar frontend → backend → DB

**Soluções:**
1. Habilitar CORS correlation no frontend:
   ```javascript
   config: {
     enableCorsCorrelation: true,
     correlationHeaderExcludedDomains: ['*.queue.core.windows.net']
   }
   ```

2. Propagar headers no backend:
   ```javascript
   app.use((req, res, next) => {
     res.setHeader('Access-Control-Expose-Headers', 'Request-Id,Request-Context');
     next();
   });
   ```

---

## 📚 Referências

### Documentação Oficial
- [Application Insights Overview](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Node.js Application Insights](https://docs.microsoft.com/azure/azure-monitor/app/nodejs)
- [JavaScript SDK](https://docs.microsoft.com/azure/azure-monitor/app/javascript)

### SDK Documentation
- [applicationinsights (npm)](https://www.npmjs.com/package/applicationinsights)
- [@microsoft/applicationinsights-web](https://www.npmjs.com/package/@microsoft/applicationinsights-web)
- [React Plugin](https://www.npmjs.com/package/@microsoft/applicationinsights-react-js)

### Advanced Topics
- [Distributed Tracing](https://docs.microsoft.com/azure/azure-monitor/app/distributed-tracing)
- [Sampling](https://docs.microsoft.com/azure/azure-monitor/app/sampling)
- [Telemetry Processors](https://docs.microsoft.com/azure/azure-monitor/app/api-filtering-sampling)

---

## 🎯 Próximos Passos

1. ✅ **Executar workflow de configuração**
2. ⏳ **Integrar SDK no backend** (Node.js)
3. ⏳ **Integrar SDK no frontend** (React)
4. ⏳ **Deploy aplicação atualizada**
5. ⏳ **Aguardar telemetria** (5-10 minutos)
6. ⏳ **Validar Live Metrics** funcionando
7. ⏳ **Explorar Application Map** e dependencies
8. ⏳ **Criar alertas essenciais** (error rate, latency)
9. ⏳ **Configurar availability tests** (health checks)
10. ⏳ **Monitorar custos** e ajustar sampling

---

## 📊 Checklist de Implementação

- [ ] Executar workflow `configure-apm.yml`
- [ ] Verificar Application Insights criado no Portal Azure
- [ ] Copiar connection string do output do workflow
- [ ] Adicionar SDK no backend (package.json)
- [ ] Inicializar SDK no backend (server/index.js)
- [ ] Configurar env var APPINSIGHTS_CONNECTION_STRING no K8s
- [ ] Adicionar SDK no frontend (package.json)
- [ ] Criar serviço de telemetria no React (services/telemetry.js)
- [ ] Rebuild e push das imagens Docker
- [ ] Deploy atualizado no AKS
- [ ] Validar telemetria aparecendo no Portal (Live Metrics)
- [ ] Testar Application Map com transação end-to-end
- [ ] Criar alerta de high error rate
- [ ] Criar alerta de high latency
- [ ] Documentar custom events específicos da DX02
- [ ] Revisar custos após 1 semana

---

**Data de Criação:** 2025-12-22  
**Última Atualização:** 2025-12-22  
**Versão:** 1.0  
**Autor:** DevOps Team - TX02
