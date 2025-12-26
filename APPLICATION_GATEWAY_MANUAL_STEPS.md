# Passos Manuais - Application Gateway + WAF

## Contexto
Após deployment inicial do Application Gateway via workflow, foram necessários ajustes manuais para configurar corretamente o backend, certificados SSL e roteamento HTTPS.

## 1. Configuração do Backend Pool

### Problema Inicial
- Backend pool estava vazio ou com IP público do Nginx (não funciona)
- Application Gateway não conseguia alcançar ClusterIP do Kubernetes

### Solução
Configurar backend pool com **IPs dos nodes do AKS**:

```bash
# Obter IPs dos nodes
kubectl get nodes -o wide

# Exemplo de saída:
# aks-default-37925013-vmss000000   10.0.1.33
# aks-default-37925013-vmss000001   10.0.1.4

# Atualizar backend pool
az network application-gateway address-pool update \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name appGatewayBackendPool \
  --servers 10.0.1.33 10.0.1.4
```

**Nota**: IPs dos nodes são dinâmicos no VMSS. Considerar:
- Usar backend pool com FQDN dos nodes
- Implementar script de atualização automática
- Ou usar AGIC (Application Gateway Ingress Controller) para gerenciamento automático

---

## 2. Configuração do HTTP Settings (HTTP)

### Problema
HTTP settings estava configurado para porta 80, mas Nginx Ingress expõe via NodePort

### Solução
```bash
# Obter NodePort do Nginx Ingress
kubectl get svc -n ingress-nginx ingress-nginx-controller
# PORT(S): 80:32371/TCP,443:31565/TCP

# Atualizar HTTP settings para NodePort HTTP (32371)
az network application-gateway http-settings update \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name appGatewayBackendHttpSettings \
  --port 32371 \
  --protocol Http \
  --timeout 30
```

---

## 3. Health Probe Customizado

### Problema
Health probe padrão retornava 404 porque não enviava header `Host: dx02.ddns.net`

### Solução
```bash
# Criar health probe HTTP com hostname
az network application-gateway probe create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name dx02-health-probe \
  --protocol Http \
  --host dx02.ddns.net \
  --path / \
  --interval 30 \
  --timeout 30 \
  --threshold 3

# Associar probe ao HTTP settings
az network application-gateway http-settings update \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name appGatewayBackendHttpSettings \
  --probe dx02-health-probe
```

**Resultado**: Backends ficaram `Healthy`

---

## 4. Exportar Certificado do Kubernetes

### Processo
```bash
# Exportar certificado TLS do secret
kubectl get secret dx02-tls -n dx02 -o jsonpath='{.data.tls\.crt}' | \
  base64 -d > tls.crt

kubectl get secret dx02-tls -n dx02 -o jsonpath='{.data.tls\.key}' | \
  base64 -d > tls.key
```

**PowerShell**:
```powershell
kubectl get secret dx02-tls -n dx02 -o jsonpath='{.data.tls\.crt}' | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) } | `
  Out-File -FilePath "tls.crt" -Encoding utf8

kubectl get secret dx02-tls -n dx02 -o jsonpath='{.data.tls\.key}' | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) } | `
  Out-File -FilePath "tls.key" -Encoding utf8
```

---

## 5. Converter Certificado para PFX

### Requisito
Application Gateway requer certificados em formato PKCS#12 (.pfx)

### Solução com OpenSSL
```bash
# OpenSSL disponível via Git Bash no Windows
openssl pkcs12 -export \
  -out dx02-tls.pfx \
  -inkey tls.key \
  -in tls.crt \
  -passout pass:AzureWAF2025!
```

**PowerShell (usando Git OpenSSL)**:
```powershell
& "C:\Program Files\Git\usr\bin\openssl.exe" pkcs12 -export `
  -out dx02-tls.pfx `
  -inkey tls.key `
  -in tls.crt `
  -passout pass:AzureWAF2025!
```

**Resultado**: Arquivo `dx02-tls.pfx` com ~4KB

---

## 6. Upload do Certificado SSL

```bash
az network application-gateway ssl-cert create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name dx02-ssl-cert \
  --cert-file dx02-tls.pfx \
  --cert-password "AzureWAF2025!"
```

**Nota**: Senha do certificado deve ser armazenada em GitHub Secret

---

## 7. Criar Frontend Port 443

```bash
az network application-gateway frontend-port create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name port443 \
  --port 443
```

---

## 8. Criar Listener HTTPS

```bash
az network application-gateway http-listener create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name httpsListener \
  --frontend-port port443 \
  --frontend-ip appGatewayFrontendIP \
  --ssl-cert dx02-ssl-cert \
  --host-name dx02.ddns.net
```

**Configurações**:
- `requireServerNameIndication: true`
- `protocol: Https`

---

## 9. HTTP Settings HTTPS

### Criar Health Probe HTTPS
```bash
az network application-gateway probe create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name dx02-https-probe \
  --protocol Https \
  --host dx02.ddns.net \
  --path / \
  --interval 30 \
  --timeout 30 \
  --threshold 3
```

### Criar HTTP Settings HTTPS
```bash
# NodePort HTTPS do Nginx: 31565
az network application-gateway http-settings create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name httpsBackendSettings \
  --port 31565 \
  --protocol Https \
  --timeout 30 \
  --probe dx02-https-probe
```

---

## 10. Regra de Roteamento HTTPS

```bash
az network application-gateway rule create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name httpsRule \
  --http-listener httpsListener \
  --address-pool appGatewayBackendPool \
  --http-settings httpsBackendSettings \
  --priority 200
```

**Configurações**:
- `ruleType: Basic`
- `priority: 200` (rule1 é 100)

---

## 11. Validação Final

### Verificar Backend Health
```bash
az network application-gateway show-backend-health \
  --resource-group tx02-prd-rg \
  --name tx02-prd-appgw \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[*].{address:address, health:health}' \
  -o table
```

### Testar HTTP (deve redirecionar para HTTPS)
```bash
curl -I http://dx02.ddns.net
# Esperado: 308 Permanent Redirect
```

### Testar HTTPS
```bash
curl -I https://dx02.ddns.net
# Esperado: 200 OK
```

**PowerShell**:
```powershell
Invoke-WebRequest -Uri "https://dx02.ddns.net" -Method Head -UseBasicParsing
```

---

## Arquitetura Final

```
Internet (HTTPS)
    ↓
Application Gateway (40.71.195.231)
    ↓ WAF_v2 (Detection Mode)
    ↓ SSL Termination (Let's Encrypt Certificate)
    ↓
Listener HTTPS (porta 443, hostname: dx02.ddns.net)
    ↓
Backend Pool (IPs dos nodes AKS)
    ├─ 10.0.1.33 (NodePort 31565/HTTPS)
    └─ 10.0.1.4  (NodePort 31565/HTTPS)
    ↓
Nginx Ingress Controller (Service Mesh sidecar)
    ↓ mTLS PERMISSIVE
    ↓
DX02 Application (pods)
```

---

## Próximos Passos para Workflow

### 1. Adicionar ao workflow `security-infrastructure.yml`:

#### Job: `configure-application-gateway-backend`
```yaml
configure-application-gateway-backend:
  needs: deploy-application-gateway
  runs-on: ubuntu-latest
  steps:
    - name: Get AKS Nodes IPs
      run: |
        NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' ',')
        echo "NODE_IPS=$NODE_IPS" >> $GITHUB_ENV
    
    - name: Update Backend Pool
      run: |
        az network application-gateway address-pool update \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --gateway-name ${{ env.APP_GATEWAY_NAME }} \
          --name appGatewayBackendPool \
          --servers ${NODE_IPS}
    
    - name: Get Nginx Ingress NodePorts
      run: |
        HTTP_NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
        HTTPS_NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
        echo "HTTP_NODEPORT=$HTTP_NODEPORT" >> $GITHUB_ENV
        echo "HTTPS_NODEPORT=$HTTPS_NODEPORT" >> $GITHUB_ENV
```

#### Job: `configure-ssl-certificate`
```yaml
configure-ssl-certificate:
  needs: [deploy-cert-manager, configure-application-gateway-backend]
  runs-on: ubuntu-latest
  steps:
    - name: Wait for Certificate
      run: |
        kubectl wait --for=condition=Ready certificate/${{ env.CERT_NAME }} -n ${{ env.NAMESPACE }} --timeout=300s
    
    - name: Export Certificate from Kubernetes
      run: |
        kubectl get secret ${{ env.CERT_SECRET }} -n ${{ env.NAMESPACE }} \
          -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
        kubectl get secret ${{ env.CERT_SECRET }} -n ${{ env.NAMESPACE }} \
          -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key
    
    - name: Convert to PFX
      run: |
        openssl pkcs12 -export \
          -out dx02-tls.pfx \
          -inkey tls.key \
          -in tls.crt \
          -passout pass:${{ secrets.CERT_PASSWORD }}
    
    - name: Upload Certificate to Application Gateway
      run: |
        az network application-gateway ssl-cert create \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --gateway-name ${{ env.APP_GATEWAY_NAME }} \
          --name ${{ env.CERT_NAME }}-ssl \
          --cert-file dx02-tls.pfx \
          --cert-password "${{ secrets.CERT_PASSWORD }}"
```

#### Job: `configure-https-listener`
```yaml
configure-https-listener:
  needs: configure-ssl-certificate
  runs-on: ubuntu-latest
  steps:
    - name: Create Frontend Port 443
      run: |
        az network application-gateway frontend-port create \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --gateway-name ${{ env.APP_GATEWAY_NAME }} \
          --name port443 \
          --port 443 \
          || echo "Port 443 already exists"
    
    - name: Create HTTPS Listener
      run: |
        az network application-gateway http-listener create \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --gateway-name ${{ env.APP_GATEWAY_NAME }} \
          --name httpsListener \
          --frontend-port port443 \
          --frontend-ip appGatewayFrontendIP \
          --ssl-cert ${{ env.CERT_NAME }}-ssl \
          --host-name ${{ env.DOMAIN_NAME }}
    
    - name: Create HTTPS Backend Settings
      run: |
        az network application-gateway http-settings create \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --gateway-name ${{ env.APP_GATEWAY_NAME }} \
          --name httpsBackendSettings \
          --port ${{ env.HTTPS_NODEPORT }} \
          --protocol Https \
          --timeout 30 \
          --probe dx02-https-probe
    
    - name: Create HTTPS Routing Rule
      run: |
        az network application-gateway rule create \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --gateway-name ${{ env.APP_GATEWAY_NAME }} \
          --name httpsRule \
          --http-listener httpsListener \
          --address-pool appGatewayBackendPool \
          --http-settings httpsBackendSettings \
          --priority 200
```

### 2. Adicionar GitHub Secrets:
- `CERT_PASSWORD`: Senha para o arquivo PFX (ex: `AzureWAF2025!`)

### 3. Considerações:
- **IPs dos Nodes**: São dinâmicos em VMSS. Considerar implementar lógica de atualização periódica ou usar AGIC
- **NodePorts**: Podem mudar se o serviço Nginx for recriado. Workflow deve detectar automaticamente
- **Certificado**: Renovação a cada 90 dias pelo cert-manager. Workflow deve atualizar Application Gateway após renovação

---

## Problemas Conhecidos

### 1. Backend Pool com IPs Dinâmicos
**Impacto**: IPs dos nodes podem mudar durante scale operations do VMSS

**Soluções**:
- Implementar webhook para atualizar backend pool quando nodes mudarem
- Usar AGIC para gerenciamento automático
- Configurar backend pool com FQDN dos nodes (se disponível)

### 2. Renovação de Certificado
**Impacto**: cert-manager renova certificado a cada 90 dias, mas Application Gateway não atualiza automaticamente

**Solução**:
- Criar workflow agendado (cron) para sincronizar certificado
- Ou implementar webhook que detecta renovação e atualiza App Gateway

### 3. NodePort vs LoadBalancer
**Impacto**: NodePort é menos ideal que LoadBalancer direto

**Solução Ideal**:
- Usar AGIC (Application Gateway Ingress Controller)
- Remover Nginx Ingress se usar AGIC
- Ou manter arquitetura híbrida para flexibilidade

---

## Custo Estimado

**Application Gateway WAF_v2**:
- Base: ~$246/mês (2 instâncias)
- Processamento: ~$0.008/GB
- Custo médio: **$250-350/mês**

**Comparação**:
- Nginx Ingress (LoadBalancer): ~$20-30/mês
- AGIC + App Gateway: ~$250-350/mês
- **Trade-off**: Custo vs WAF Protection
