# 🛡️ WAF Deployment Guide - January 8, 2026

## ✅ Status: Workflow Running

**Workflow ID:** 20819528249  
**Started:** Less than a minute ago  
**Configuration:**
- Environment: `prd`
- App Gateway SKU: `WAF_v2`
- WAF Mode: `Detection`
- Domain: `dx02.ddns.net`

---

## 📊 Phase 1: Automated Workflow (IN PROGRESS)

The workflow will automatically create:
- ✅ Azure Application Gateway (WAF_v2 SKU)
- ✅ WAF Policy with OWASP rules
- ✅ Public IP for the gateway
- ✅ Application Gateway subnet (10.0.5.0/24)
- ✅ Basic HTTP listener and routing

**Estimated time:** 15-20 minutes

### Monitor Progress

```bash
# Watch the workflow
gh run watch --repo maringelix/tx02 20819528249

# Or view in browser
https://github.com/maringelix/tx02/actions/runs/20819528249
```

---

## 🔧 Phase 2: Manual Configuration (AFTER WORKFLOW COMPLETES)

### Prerequisites Collected

| Item | Value |
|------|-------|
| **AKS Node IPs** | `10.0.1.4`, `10.0.1.33` |
| **HTTP NodePort** | `31805` |
| **HTTPS NodePort** | `31953` |
| **Current Ingress IP** | `48.217.134.141` |
| **Domain** | `dx02.ddns.net` |

---

### Step 1: Configure Backend Pool with AKS Nodes

```bash
# Update backend pool with AKS node IPs
az network application-gateway address-pool update \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name appGatewayBackendPool \
  --servers 10.0.1.4 10.0.1.33
```

**Expected output:** Backend pool updated with 2 addresses

---

### Step 2: Update HTTP Settings for NodePort

```bash
# Update HTTP settings to use NGINX Ingress HTTP NodePort
az network application-gateway http-settings update \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name appGatewayBackendHttpSettings \
  --port 31805 \
  --protocol Http \
  --timeout 30
```

**Why NodePort?**
- Application Gateway needs to reach the NGINX Ingress inside AKS
- NGINX Ingress exposes NodePort 31805 (HTTP) and 31953 (HTTPS)

---

### Step 3: Create Custom Health Probe

```bash
# Create health probe with correct hostname
az network application-gateway probe create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name dx02-http-probe \
  --protocol Http \
  --host dx02.ddns.net \
  --path / \
  --interval 30 \
  --timeout 30 \
  --threshold 3

# Associate probe with HTTP settings
az network application-gateway http-settings update \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name appGatewayBackendHttpSettings \
  --probe dx02-http-probe
```

**Expected:** Backend health should show "Healthy" after 30-60 seconds

---

### Step 4: Verify Backend Health

```bash
# Check backend health status
az network application-gateway show-backend-health \
  --resource-group tx02-prd-rg \
  --name tx02-prd-appgw \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[*].{address:address, health:health}' \
  -o table
```

**Expected output:**
```
Address     Health
----------  --------
10.0.1.4    Healthy
10.0.1.33   Healthy
```

⚠️ If "Unhealthy", wait 2-3 minutes for health probes to run

---

### Step 5: Get Application Gateway Public IP

```bash
# Get the new Application Gateway public IP
az network public-ip show \
  --resource-group tx02-prd-rg \
  --name tx02-prd-appgw-pip \
  --query ipAddress -o tsv
```

**Action Required:** Update your DNS `dx02.ddns.net` to point to this new IP

---

### Step 6: Configure HTTPS (Optional but Recommended)

Since cert-manager is already installed and has issued certificates, we can export and use them:

```bash
# Export the Let's Encrypt certificate from Kubernetes
kubectl get secret dx02-tls-secret -n dx02 -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret dx02-tls-secret -n dx02 -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key

# Convert to PFX format (required by Application Gateway)
openssl pkcs12 -export -out certificate.pfx -inkey tls.key -in tls.crt -passout pass:YourCertPassword123!

# Upload certificate to Application Gateway
az network application-gateway ssl-cert create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name dx02-ssl-cert \
  --cert-file certificate.pfx \
  --cert-password YourCertPassword123!

# Create HTTPS frontend port
az network application-gateway frontend-port create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name httpsPort \
  --port 443

# Create HTTPS listener
az network application-gateway http-listener create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name httpsListener \
  --frontend-port httpsPort \
  --ssl-cert dx02-ssl-cert \
  --host-name dx02.ddns.net

# Create HTTPS backend settings
az network application-gateway http-settings create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name httpsBackendSettings \
  --port 31953 \
  --protocol Https \
  --timeout 30 \
  --probe dx02-http-probe

# Create HTTPS routing rule
az network application-gateway rule create \
  --resource-group tx02-prd-rg \
  --gateway-name tx02-prd-appgw \
  --name httpsRule \
  --http-listener httpsListener \
  --address-pool appGatewayBackendPool \
  --http-settings httpsBackendSettings \
  --priority 200
```

---

## 🧪 Phase 3: Testing

### Test HTTP Access

```bash
# Test HTTP (should work after Step 4)
curl -H "Host: dx02.ddns.net" http://<APPGW_PUBLIC_IP>/

# Or from browser
http://dx02.ddns.net
```

### Test HTTPS Access (if configured)

```bash
# Test HTTPS
curl -H "Host: dx02.ddns.net" https://<APPGW_PUBLIC_IP>/

# Or from browser
https://dx02.ddns.net
```

### Verify WAF is Active

```bash
# Check WAF policy status
az network application-gateway waf-policy show \
  --resource-group tx02-prd-rg \
  --name tx02-prd-appgw-waf-policy \
  --query '{Name:name, State:policySettings.state, Mode:policySettings.mode}' \
  -o table
```

**Expected:**
```
Name                          State    Mode
----------------------------  -------  ----------
tx02-prd-appgw-waf-policy    Enabled  Detection
```

### Test WAF Protection

```bash
# Test SQL injection (should be blocked in Prevention mode, logged in Detection mode)
curl "http://dx02.ddns.net/?id=1' OR '1'='1"

# Check WAF logs in Azure Portal:
# Application Gateway → Web application firewall → Firewall logs
```

---

## 📊 Phase 4: Verification Checklist

- [ ] Workflow completed successfully
- [ ] Application Gateway created
- [ ] WAF Policy attached
- [ ] Backend pool configured with node IPs
- [ ] HTTP settings updated to NodePort 31805
- [ ] Health probe created and associated
- [ ] Backend health shows "Healthy"
- [ ] Public IP obtained
- [ ] DNS updated to new IP
- [ ] HTTP access working
- [ ] HTTPS configured (optional)
- [ ] HTTPS access working (optional)
- [ ] WAF in Detection mode
- [ ] WAF logs visible in Azure Portal

---

## 🎯 Architecture After Deployment

```
Internet
   ↓
[Application Gateway WAF v2]  ← Public IP (new)
   ↓ (Port 80/443)
[Backend Pool: 10.0.1.4, 10.0.1.33]
   ↓ (NodePort 31805/31953)
[NGINX Ingress Controller]
   ↓ (ClusterIP)
[DX02 Service]
   ↓
[DX02 Pods]
   ↓
[Azure SQL Database]
```

---

## 🚨 Troubleshooting

### Backend Shows "Unhealthy"

1. **Check NSG rules** - Ensure Application Gateway subnet can reach AKS nodes
2. **Verify NodePort** - Run `kubectl get svc -n ingress-nginx`
3. **Check health probe** - Verify hostname is set to `dx02.ddns.net`
4. **Wait longer** - Health probes run every 30 seconds

### DNS Not Resolving

1. **Check DNS propagation** - Can take 5-10 minutes
2. **Verify IP** - Ensure DNS points to Application Gateway public IP, not NGINX IP
3. **Test with /etc/hosts** - Add entry to test before DNS propagates

### HTTPS Not Working

1. **Certificate not trusted** - Let's Encrypt staging certificates are not trusted
2. **Wrong NodePort** - Verify using 31953 (HTTPS), not 31805 (HTTP)
3. **Backend protocol mismatch** - Ensure backend settings use HTTPS protocol

### WAF Blocking Legitimate Traffic

1. **Check mode** - Ensure in Detection mode for testing
2. **Review logs** - Check which rule is triggering
3. **Create exceptions** - Add exclusions for specific rules if needed

---

## 📚 Reference Documentation

- [APPLICATION_GATEWAY_MANUAL_STEPS.md](APPLICATION_GATEWAY_MANUAL_STEPS.md) - Detailed manual steps
- [WORKFLOW_UPDATE_CHECKLIST.md](WORKFLOW_UPDATE_CHECKLIST.md) - Workflow improvement suggestions
- [SECURITY_INFRASTRUCTURE.md](SECURITY_INFRASTRUCTURE.md) - Complete security guide

---

## ✅ Success Criteria

Your WAF deployment is successful when:

1. ✅ Application Gateway shows "Running" state
2. ✅ WAF Policy is "Enabled" in Detection mode
3. ✅ Backend health shows all nodes "Healthy"
4. ✅ Can access https://dx02.ddns.net via Application Gateway
5. ✅ WAF logs are visible in Azure Monitor
6. ✅ Response headers show `X-Azure-Ref` (indicates going through App Gateway)

---

**Created:** January 8, 2026  
**Workflow Run:** https://github.com/maringelix/tx02/actions/runs/20819528249  
**Next Step:** Wait for workflow to complete, then follow Phase 2 manual steps
