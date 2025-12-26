# Checklist: Atualização do Workflow security-infrastructure.yml

## 📋 Resumo
Após testes manuais, identificamos que o workflow `security-infrastructure.yml` precisa de jobs adicionais para configurar completamente o Application Gateway com backend, certificados SSL e roteamento HTTPS.

**Referência completa**: [APPLICATION_GATEWAY_MANUAL_STEPS.md](APPLICATION_GATEWAY_MANUAL_STEPS.md)

---

## ✅ Jobs a Adicionar no Workflow

### 1. **Job: `configure-application-gateway-backend`**
**Dependências**: `deploy-application-gateway`

**Função**: Configurar backend pool com IPs dos nodes AKS e NodePorts do Nginx Ingress

**Passos**:
- [ ] Obter IPs internos dos nodes AKS (`kubectl get nodes`)
- [ ] Atualizar backend pool com IPs dos nodes
- [ ] Obter NodePorts do Nginx Ingress (HTTP: 32371, HTTPS: 31565)
- [ ] Atualizar HTTP settings para usar NodePort HTTP (32371)
- [ ] Criar health probe HTTP com hostname (`dx02.ddns.net`)
- [ ] Associar health probe ao HTTP settings
- [ ] Validar backend health (aguardar status `Healthy`)

**Variáveis de ambiente necessárias**:
```yaml
NODE_IPS: "10.0.1.33,10.0.1.4"  # Dinâmico via kubectl
HTTP_NODEPORT: "32371"           # Dinâmico via kubectl
HTTPS_NODEPORT: "31565"          # Dinâmico via kubectl
```

---

### 2. **Job: `configure-ssl-certificate`**
**Dependências**: `deploy-cert-manager`, `configure-application-gateway-backend`

**Função**: Exportar certificado Let's Encrypt do Kubernetes e fazer upload para Application Gateway

**Passos**:
- [ ] Aguardar certificado estar pronto (`kubectl wait --for=condition=Ready certificate/...`)
- [ ] Exportar certificado do Kubernetes secret (`tls.crt` e `tls.key`)
- [ ] Converter certificado para formato PFX usando OpenSSL
- [ ] Fazer upload do certificado PFX para Application Gateway
- [ ] Validar certificado instalado

**Comandos principais**:
```bash
# Exportar certificado
kubectl get secret dx02-tls -n dx02 -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret dx02-tls -n dx02 -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key

# Converter para PFX
openssl pkcs12 -export -out dx02-tls.pfx -inkey tls.key -in tls.crt -passout pass:${{ secrets.CERT_PASSWORD }}

# Upload
az network application-gateway ssl-cert create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GATEWAY_NAME \
  --name dx02-ssl-cert \
  --cert-file dx02-tls.pfx \
  --cert-password "${{ secrets.CERT_PASSWORD }}"
```

**Secrets necessários**:
- `CERT_PASSWORD`: Senha para arquivo PFX (ex: `AzureWAF2025!`)

---

### 3. **Job: `configure-https-listener`**
**Dependências**: `configure-ssl-certificate`

**Função**: Criar listener HTTPS, backend settings HTTPS e regra de roteamento

**Passos**:
- [ ] Criar frontend port 443 (se não existir)
- [ ] Criar listener HTTPS na porta 443 com certificado SSL
- [ ] Criar health probe HTTPS com hostname
- [ ] Criar HTTP settings HTTPS (NodePort 31565)
- [ ] Criar regra de roteamento HTTPS (priority 200)
- [ ] Validar configuração completa

**Comandos principais**:
```bash
# Frontend Port
az network application-gateway frontend-port create \
  --name port443 --port 443

# HTTPS Listener
az network application-gateway http-listener create \
  --name httpsListener \
  --frontend-port port443 \
  --ssl-cert dx02-ssl-cert \
  --host-name dx02.ddns.net

# Health Probe HTTPS
az network application-gateway probe create \
  --name dx02-https-probe \
  --protocol Https \
  --host dx02.ddns.net

# HTTP Settings HTTPS
az network application-gateway http-settings create \
  --name httpsBackendSettings \
  --port 31565 \
  --protocol Https \
  --probe dx02-https-probe

# Routing Rule
az network application-gateway rule create \
  --name httpsRule \
  --http-listener httpsListener \
  --address-pool appGatewayBackendPool \
  --http-settings httpsBackendSettings \
  --priority 200
```

---

### 4. **Job: `validate-deployment`**
**Dependências**: `configure-https-listener`

**Função**: Validar que HTTP e HTTPS estão funcionando corretamente

**Passos**:
- [ ] Verificar backend health (`az network application-gateway show-backend-health`)
- [ ] Testar HTTP (deve retornar 308 redirect)
- [ ] Testar HTTPS (deve retornar 200 OK)
- [ ] Verificar headers de segurança
- [ ] Validar certificado SSL
- [ ] Opcional: Notificar no Slack/Teams

**Validações esperadas**:
```bash
# Backend health
Backend Status: Healthy (para todos os nodes)

# HTTP test
curl -I http://dx02.ddns.net
# Esperado: HTTP/1.1 308 Permanent Redirect

# HTTPS test
curl -I https://dx02.ddns.net
# Esperado: HTTP/1.1 200 OK
# Deve conter: strict-transport-security, x-frame-options, etc.
```

---

## 🔧 Variáveis de Ambiente do Workflow

### Existentes (manter):
```yaml
RESOURCE_GROUP: "tx02-prd-rg"
APP_GATEWAY_NAME: "tx02-prd-appgw"
VNET_NAME: "tx02-prd-vnet"
SUBNET_NAME: "tx02-prd-subnet-appgw"
WAF_POLICY_NAME: "tx02-prd-appgw-waf-policy"
```

### Novas (adicionar):
```yaml
CERT_NAME: "dx02-tls"
CERT_SECRET: "dx02-tls"
NAMESPACE: "dx02"
DOMAIN_NAME: "dx02.ddns.net"
INGRESS_NAMESPACE: "ingress-nginx"
INGRESS_SERVICE: "ingress-nginx-controller"
```

---

## 📝 GitHub Secrets Necessários

### Existentes:
- ✅ `AZURE_CREDENTIALS` - Service Principal para Azure login
- ✅ `AZURE_SQL_PASSWORD` - Senha do Azure SQL Database

### Novos:
- [ ] `CERT_PASSWORD` - Senha para arquivo PFX (sugestão: `AzureWAF2025!`)

---

## ⚠️ Problemas Conhecidos e Soluções

### 1. **IPs dos Nodes são Dinâmicos**
**Problema**: IPs dos nodes AKS podem mudar durante scale operations do VMSS

**Soluções**:
- **Curto prazo**: Workflow atualiza backend pool a cada execução
- **Médio prazo**: Webhook para atualizar quando nodes mudarem
- **Longo prazo**: Migrar para AGIC (Application Gateway Ingress Controller)

### 2. **NodePorts Podem Mudar**
**Problema**: Se Nginx Ingress for recriado, NodePorts podem ser diferentes

**Solução**: Workflow detecta NodePorts dinamicamente via `kubectl`

### 3. **Renovação de Certificado Let's Encrypt**
**Problema**: Certificado renova a cada 90 dias, Application Gateway não atualiza automaticamente

**Soluções**:
- **Opção A**: Workflow agendado (cron) para sincronizar certificado mensalmente
- **Opção B**: Webhook que detecta renovação do cert-manager
- **Opção C**: Script externo rodando em CronJob no Kubernetes

### 4. **Custo do Application Gateway**
**Problema**: Application Gateway WAF_v2 custa ~$250-350/mês

**Soluções**:
- Usar parâmetro condicional no workflow (`deploy_app_gateway: true/false`)
- Destruir Application Gateway quando não estiver em uso
- Considerar downgrade para Standard_v2 (~$125/mês) sem WAF

---

## 🎯 Prioridades de Implementação

### **P0 - Crítico** (Workflow não funciona sem isso)
1. ✅ Configurar backend pool com IPs dos nodes
2. ✅ Atualizar HTTP settings com NodePort correto
3. ✅ Criar health probes com hostname
4. ✅ Exportar e converter certificado para PFX
5. ✅ Criar listener HTTPS com certificado
6. ✅ Criar regra de roteamento HTTPS

### **P1 - Alta** (Melhora robustez)
7. [ ] Validação automática de deployment
8. [ ] Tratamento de erros e retry logic
9. [ ] Logs detalhados para troubleshooting

### **P2 - Média** (Melhora manutenibilidade)
10. [ ] Workflow para renovação de certificado
11. [ ] Notificações de sucesso/falha
12. [ ] Métricas e dashboards do Application Gateway

### **P3 - Baixa** (Nice to have)
13. [ ] Migração para AGIC
14. [ ] Testes de carga automatizados
15. [ ] Blue/Green deployment via Application Gateway

---

## 📚 Referências

- [APPLICATION_GATEWAY_MANUAL_STEPS.md](APPLICATION_GATEWAY_MANUAL_STEPS.md) - Todos os comandos executados manualmente
- [SECURITY_INFRASTRUCTURE.md](SECURITY_INFRASTRUCTURE.md) - Documentação do cert-manager e WAF
- [Azure Application Gateway Documentation](https://learn.microsoft.com/en-us/azure/application-gateway/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt - Best Practices](https://letsencrypt.org/docs/)

---

## ✅ Próximos Passos

1. [ ] Criar branch `feature/appgw-automation` no repositório
2. [ ] Atualizar workflow `security-infrastructure.yml` com os 4 novos jobs
3. [ ] Adicionar secret `CERT_PASSWORD` no GitHub
4. [ ] Testar workflow em ambiente de staging
5. [ ] Validar todos os cenários (primeira execução, re-execução, falhas)
6. [ ] Merge para `main` após validação
7. [ ] Documentar no README.md
8. [ ] Criar issue para implementação de renovação automática de certificado (P2)
9. [ ] Criar issue para migração AGIC (P3)

---

## 💡 Dicas de Implementação

### Teste Incremental
Implemente um job por vez e teste:
1. Primeiro: `configure-application-gateway-backend`
2. Segundo: `configure-ssl-certificate`
3. Terceiro: `configure-https-listener`
4. Quarto: `validate-deployment`

### Idempotência
Todos os comandos devem ser idempotentes (podem ser executados múltiplas vezes sem erro):
```bash
# Exemplo: criar recurso com || true
az network application-gateway frontend-port create ... || echo "Port already exists"

# Ou verificar antes de criar
if ! az network application-gateway frontend-port show ...; then
  az network application-gateway frontend-port create ...
fi
```

### Timeouts
Adicionar timeouts apropriados:
- Backend pool update: ~2 minutos
- Certificate upload: ~1 minuto
- Listener creation: ~2 minutos
- Backend health check: ~5 minutos (aguardar probes)

### Logging
Use outputs estruturados para facilitar troubleshooting:
```bash
echo "::group::Configurando backend pool"
echo "Node IPs: $NODE_IPS"
az network application-gateway address-pool update ...
echo "::endgroup::"
```

---

**Última atualização**: 26/12/2025
**Status**: 📝 Documentação completa - Pronto para implementação
