# 🗄️ TX02 Backup & Disaster Recovery Strategy

## 📋 Overview

This document describes the comprehensive backup and disaster recovery (DR) strategy for TX02 infrastructure on Azure. The strategy ensures business continuity and data protection across all critical components.

### Services Used

- **Azure SQL Database**: Built-in automated backups with PITR and LTR
- **Azure Disk Snapshots**: Manual snapshots for AKS persistent volumes
- **Azure Storage**: Versioning for Terraform state
- **Git**: Version control for Kubernetes manifests and infrastructure code

### Automation

- **Configure Backup**: `.github/workflows/configure-backup.yml`
- **Restore**: `.github/workflows/restore-backup.yml`
- **Execution**: GitHub Actions manual dispatch

## 🎯 Objectives

### Recovery Time Objective (RTO)

| Resource | RTO Target | Notes |
|----------|-----------|-------|
| Azure SQL Database | 15-30 minutes | PITR or LTR restore |
| AKS Persistent Volumes | 20-30 minutes | Disk creation from snapshot |
| Terraform State | < 5 minutes | Storage Account versioning |
| K8s Manifests | < 5 minutes | Git restore |

### Recovery Point Objective (RPO)

| Resource | RPO Target | Notes |
|----------|-----------|-------|
| Azure SQL Database (PITR) | 1 hour | Continuous backup, point-in-time |
| Azure SQL Database (LTR) | 1 week / 1 month | Based on retention policy |
| AKS Persistent Volumes | 1 day | Based on snapshot schedule |
| Terraform State | 0 (no loss) | Immediate versioning |
| K8s Manifests | 0 (no loss) | Git commits |

## 🏗️ Architecture

### Cross-Region Setup

TX02 already implements cross-region deployment for disaster recovery:

```
Primary Region: eastus
├── AKS Cluster (tx02-prd-aks)
├── Kubernetes Workloads
├── Persistent Volumes
└── Observability Stack

Backup Region: westus2
├── SQL Server (tx02-prd-sql)
├── SQL Database (tx02-prd-db)
└── Automated Backups
```

**Benefit**: SQL Database in separate region provides built-in geographic redundancy.

### Backup Components

```
Azure SQL Database
├── Short-term (PITR): 7-30 days
│   └── Point-in-time restore capability
└── Long-term (LTR): Weekly/Monthly
    ├── Weekly: 4-52 weeks
    └── Monthly: 3-12 months

AKS Persistent Volumes
├── Prometheus Data
├── Grafana Dashboards
└── Application PVCs (if any)
    └── Snapshots: Manual via workflow

Terraform State
└── Azure Storage Account: tfstatetx02
    └── Versioning: Enabled

Kubernetes Manifests
├── TX02 Repository (infrastructure)
└── DX02 Repository (application)
    └── Git: Version controlled
```

## 📦 Resources Protected

### 1. Azure SQL Database

**Location**: westus2  
**Server**: tx02-prd-sql.database.windows.net  
**Database**: tx02-prd-db

**Backup Configuration**:
- **Automatic**: Azure SQL automatically creates backups
- **Short-term Retention (PITR)**: Configurable 7-30 days
  - Full backup: Weekly
  - Differential backup: Every 12-24 hours
  - Transaction log backup: Every 5-10 minutes
- **Long-term Retention (LTR)**: Configurable
  - Weekly backups: 4-52 weeks
  - Monthly backups: 3-12 months
  - Yearly backups: 1-10 years (optional)

**Restore Methods**:
1. **Point-in-Time Restore (PITR)**:
   - Restore to any second within retention period
   - Command: `az sql db restore`
   - Use case: Accidental data deletion, corruption

2. **Long-Term Restore (LTR)**:
   - Restore from weekly/monthly backup
   - Command: `az sql db ltr-backup restore`
   - Use case: Compliance, long-term recovery

**Cost**: Included with database SKU (Basic: ~$5/month)

### 2. AKS Persistent Volumes

**Location**: eastus  
**Cluster**: tx02-prd-aks  
**Storage**: Azure Managed Disks (Premium SSD)

**Volumes to Backup**:
- Prometheus metrics storage (monitoring namespace)
- Grafana dashboards (monitoring namespace)
- Application data volumes (dx02 namespace, if any)

**Backup Configuration**:
- **Method**: Azure Disk Snapshots
- **Frequency**: Manual via workflow (can be scheduled)
- **Retention**: Configurable (default 7 days)
- **Incremental**: Yes (only changed blocks)

**Restore Process**:
1. Create new disk from snapshot
2. Create Kubernetes PV/PVC
3. Update pod to use restored volume
4. Verify data integrity

**Cost**: ~$0.05/GB/month for snapshots

### 3. Terraform State

**Location**: eastus  
**Storage Account**: tfstatetx02  
**Container**: terraform-state  
**File**: tx02.tfstate

**Backup Configuration**:
- **Versioning**: Enabled by default
- **Retention**: All versions kept
- **Protection**: Blob soft delete (30 days)

**Restore Process**:
```bash
# List versions
az storage blob list \
  --account-name tfstatetx02 \
  --container-name terraform-state \
  --include snapshots

# Restore specific version
az storage blob copy start \
  --destination-blob tx02.tfstate \
  --destination-container terraform-state \
  --source-blob tx02.tfstate \
  --source-version-id <version-id>
```

**Cost**: Minimal (storage only)

### 4. Kubernetes Manifests

**Location**: GitHub repositories  
**TX02 Repo**: Infrastructure manifests (k8s/*)  
**DX02 Repo**: Application manifests (k8s/*)

**Backup Configuration**:
- **Method**: Git version control
- **Branches**: main (production), feature branches
- **Protection**: Branch protection rules

**Restore Process**:
```bash
# Revert to previous version
git revert <commit-hash>

# Or restore from specific commit
git checkout <commit-hash> -- k8s/
```

**Cost**: Free (GitHub)

## 🔧 Configuration Steps

### Initial Setup

Run the **Configure Backup Automation** workflow:

```yaml
Inputs:
  environment: prd
  backup_retention_days: 7        # PITR retention
  ltr_weekly_retention: P4W       # 4 weeks
  ltr_monthly_retention: P12M     # 12 months
  enable_monitoring: true
```

**What it does**:
1. Configures Azure SQL short-term retention (PITR)
2. Configures Azure SQL long-term retention (LTR)
3. Tags AKS disks for backup
4. Creates initial disk snapshots
5. Verifies backup configuration

### Ongoing Maintenance

**Daily**:
- Automatic SQL backups (Azure-managed)
- Monitor backup success in Azure Portal

**Weekly**:
- Review LTR backup creation
- Verify disk snapshots (if scheduled)

**Monthly**:
- Test restore procedure (staging)
- Review retention policies
- Update documentation

**Quarterly** (Production):
- Full disaster recovery test
- RTO/RPO validation
- Update runbooks

## ♻️ Restore Procedures

### Scenario 1: SQL Database Failure

**Symptoms**: Database corruption, accidental deletion, ransomware

**Restore Steps**:

1. **List available backups**:
   ```yaml
   Workflow: Restore from Backup
   Inputs:
     environment: prd
     resource_type: list-backups
   ```

2. **Choose restore method**:

   **Option A: Point-in-Time (last 7-30 days)**
   ```yaml
   Workflow: Restore from Backup
   Inputs:
     environment: prd
     resource_type: sql-pitr
     pitr_restore_time: "2025-01-15T10:30:00Z"
     restore_to_new_resource: true
   ```

   **Option B: Long-Term (weekly/monthly)**
   ```yaml
   Workflow: Restore from Backup
   Inputs:
     environment: prd
     resource_type: sql-ltr
     ltr_backup_id: "<full-backup-resource-id>"
     restore_to_new_resource: true
   ```

3. **Verify restored database**:
   - Connect to new database
   - Check row counts, key tables
   - Run application smoke tests

4. **Switch application**:
   - Update Kubernetes secret: `dx02-secrets`
   - Update `DB_HOST` to new database name
   - Restart DX02 pods: `kubectl rollout restart deployment/dx02 -n dx02`

5. **Cleanup**:
   - Delete old database (once verified)
   - Or keep for forensics

**Estimated Time**: 30-45 minutes

### Scenario 2: AKS Persistent Volume Loss

**Symptoms**: Disk failure, data corruption, accidental deletion

**Restore Steps**:

1. **List available snapshots**:
   ```yaml
   Workflow: Restore from Backup
   Inputs:
     environment: prd
     resource_type: list-backups
   ```

2. **Restore disk from snapshot**:
   ```yaml
   Workflow: Restore from Backup
   Inputs:
     environment: prd
     resource_type: disk
     snapshot_name: "<snapshot-name>"
     restore_to_new_resource: true
   ```

3. **Create Kubernetes PV/PVC**:
   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: prometheus-data-restored
   spec:
     capacity:
       storage: 50Gi
     accessModes:
       - ReadWriteOnce
     azureDisk:
       diskName: <restored-disk-name>
       diskURI: <disk-resource-id>
     ---
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: prometheus-data
     namespace: monitoring
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 50Gi
     volumeName: prometheus-data-restored
   ```

4. **Update pod to use restored volume**:
   - Scale down Prometheus: `kubectl scale statefulset prometheus --replicas=0 -n monitoring`
   - Apply PV/PVC with restored disk
   - Scale up: `kubectl scale statefulset prometheus --replicas=1 -n monitoring`
   - Verify data: Check Prometheus UI for historical metrics

**Estimated Time**: 20-30 minutes

### Scenario 3: Full Disaster Recovery

**Symptoms**: Complete region failure, catastrophic loss

**Restore Steps**:

1. **Verify secondary region availability** (westus2)
   - SQL Database: Already in westus2 ✅
   - AKS: Need to provision new cluster in westus2

2. **Deploy infrastructure**:
   ```bash
   # Update terraform variables
   location = "westus2"
   
   # Run terraform apply
   terraform apply
   ```

3. **Restore SQL Database** (if needed):
   - Use LTR backup or geo-restore
   - SQL Database has geo-redundant backup

4. **Deploy application**:
   - Run DX02 deployment workflow
   - Update ingress DNS to new region

5. **Restore monitoring data** (optional):
   - Prometheus/Grafana can start fresh
   - Or restore from snapshots if critical

**Estimated Time**: 2-4 hours (full region failover)

## 📊 Testing & Validation

### Monthly Testing (Staging)

**Test Cases**:
1. ✅ SQL PITR restore
2. ✅ SQL LTR restore
3. ✅ Disk snapshot restore
4. ✅ Application connectivity to restored DB
5. ✅ Data integrity verification

**Checklist**:
- [ ] Backup workflow runs successfully
- [ ] All resources tagged correctly
- [ ] Backups visible in Azure Portal
- [ ] Restore workflow completes without errors
- [ ] Restored resources functional
- [ ] Application connects to restored resources
- [ ] Data integrity verified (checksums, row counts)
- [ ] RTO/RPO targets met
- [ ] Documentation updated

### Quarterly Testing (Production)

**Full DR Test** (during maintenance window):
1. Create test backup
2. Restore to separate resource
3. Point test application to restored resource
4. Validate functionality
5. Measure actual RTO
6. Document findings
7. Cleanup test resources

## 💰 Cost Analysis

### Monthly Costs (Estimated)

| Component | Cost | Notes |
|-----------|------|-------|
| SQL Database Backup | Included | Part of Basic SKU (~$5/mo) |
| SQL LTR Storage | ~$0.50 | ~20GB at $0.02/GB/mo |
| Disk Snapshots | ~$2.50 | 50GB at $0.05/GB/mo |
| Terraform State | ~$0.10 | Minimal storage |
| **Total** | **~$3-4/mo** | Very cost-effective |

**Cost Optimization**:
- Delete old snapshots after retention period
- Use Basic SQL tier (sufficient for small DB)
- Leverage included backup storage

## 🔒 Security & Compliance

### Encryption

**At Rest**:
- ✅ Azure SQL: Transparent Data Encryption (TDE)
- ✅ Disks: Azure Storage Service Encryption (SSE)
- ✅ Snapshots: Encrypted by default
- ✅ Terraform State: Storage Account encryption

**In Transit**:
- ✅ SQL: TLS 1.2 enforced
- ✅ Azure CLI: HTTPS only
- ✅ Git: SSH/HTTPS

### Access Control

**Azure Resources**:
- Service Principal: tx02-github-actions
- Permissions: Contributor on tx02-prd-rg
- MFA: Required for manual Azure Portal access

**GitHub Secrets**:
- `AZURE_CREDENTIALS`: Encrypted, access logged
- Rotation: Every 90 days

**Backup Access**:
- SQL backups: Database owner only
- Snapshots: Resource group contributors
- Terraform state: Storage Account key

### Compliance

**Retention Policies**:
- Development: 7 days
- Production: 30 days (PITR) + 12 months (LTR)
- Audit logs: 90 days

**Audit Trail**:
- All backup operations logged in GitHub Actions
- Azure Activity Log: 90 days
- SQL audit logs: Enabled

## 📈 Monitoring & Alerts

### Backup Health Monitoring

**Azure Monitor**:
```kusto
// SQL Database backup failures
AzureDiagnostics
| where ResourceType == "SERVERS/DATABASES"
| where Category == "AutomaticBackup"
| where status_s == "Failed"
| project TimeGenerated, ResourceId, status_s, errorMessage_s
```

**Metrics to Monitor**:
- SQL backup success rate (target: 100%)
- Backup duration (alert if > 1 hour)
- Backup storage usage
- Snapshot creation success

### Alert Configuration

**Critical Alerts** (Slack #dx02-critical):
- SQL backup failure
- Restore operation failure
- Backup retention policy change

**Warning Alerts** (Slack #dx02-alerts):
- Backup duration exceeded threshold
- Snapshot creation took longer than expected
- Low backup storage space

## 🛠️ Troubleshooting

### Common Issues

#### SQL Database Backup Not Found

**Symptoms**: No PITR backups available

**Resolution**:
```bash
# Check backup policy
az sql db str-policy show \
  --resource-group tx02-prd-rg \
  --server tx02-prd-sql \
  --name tx02-prd-db

# Verify database is online
az sql db show \
  --resource-group tx02-prd-rg \
  --server tx02-prd-sql \
  --name tx02-prd-db \
  --query status
```

**Cause**: Database was recently created (< 24 hours)  
**Solution**: Wait for first full backup (weekly)

#### Snapshot Creation Failed

**Symptoms**: Workflow error creating disk snapshot

**Resolution**:
```bash
# Check disk state
az disk show \
  --resource-group <aks-node-rg> \
  --name <disk-name> \
  --query provisioningState

# Verify disk is not attached to running VM
kubectl get pv -o wide
```

**Cause**: Disk in use or detaching  
**Solution**: Retry after disk is fully attached/detached

#### Restore Takes Too Long

**Symptoms**: Restore exceeds RTO target

**Resolution**:
- Check Azure service health
- Monitor restore operation in Portal
- Consider smaller restore window (PITR)
- Use read replicas for large restores

**Prevention**:
- Test restores regularly
- Keep database size optimized
- Use appropriate SQL tier for backup speed

## 📚 References

### Azure Documentation

- [Azure SQL Backup Overview](https://docs.microsoft.com/en-us/azure/azure-sql/database/automated-backups-overview)
- [Azure Disk Snapshots](https://docs.microsoft.com/en-us/azure/virtual-machines/disks-incremental-snapshots)
- [Azure Backup Best Practices](https://docs.microsoft.com/en-us/azure/backup/backup-azure-best-practices)

### Workflow Files

- `.github/workflows/configure-backup.yml`: Backup configuration
- `.github/workflows/restore-backup.yml`: Restore operations

### Related Documents

- `README.md`: Project overview
- `DEPLOYMENT_GUIDE.md`: Infrastructure deployment
- `TROUBLESHOOTING.md`: General troubleshooting

## 📝 Changelog

| Date | Change | Author |
|------|--------|--------|
| 2025-01-15 | Initial backup strategy document | GitHub Copilot |
| 2025-01-15 | Added configure-backup.yml workflow | GitHub Copilot |
| 2025-01-15 | Added restore-backup.yml workflow | GitHub Copilot |

## ✅ Implementation Checklist

- [ ] Review backup strategy with team
- [ ] Run configure-backup workflow
- [ ] Verify SQL backup policy in Azure Portal
- [ ] Verify disk snapshots created
- [ ] Test SQL PITR restore
- [ ] Test SQL LTR restore (after first LTR backup)
- [ ] Test disk restore
- [ ] Configure Azure Monitor alerts
- [ ] Schedule monthly restore testing
- [ ] Document restore procedures in runbook
- [ ] Train team on restore workflows
- [ ] Add backup metrics to Grafana dashboard

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-15  
**Owner**: DevOps Team  
**Review Schedule**: Quarterly
