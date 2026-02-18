# 🔐 RBAC Complete Review

**Data**: 2026-02-18  
**Status**: ⚠️ **REQUER LIMPEZA E REORGANIZAÇÃO**

---

## 📋 Resumo Executivo

### ✅ **O que está funcionando:**
1. **ArgoCD Platform Manager** - ClusterRole principal (aplicado manualmente)
2. **Redis RBAC** - Multi-namespace support (gerenciado via ArgoCD)

### ❌ **Problemas identificados:**
1. **RBAC duplicado**: `argocd-monitoring-rbac.yaml` tem permissões duplicadas
2. **RBAC não usado**: `argocd-rbac-cm.yaml` referencia projeto `team-orders` que não existe mais
3. **RBAC não gerenciado pelo ArgoCD**: Permissões principais aplicadas manualmente
4. **Arquivo órfão**: `openshift-monitoring-permissions.yaml` foi criado mas não é necessário

---

## 📁 Inventário de Arquivos RBAC

### **1. Platform RBACs (Manuais - NÃO gerenciados pelo ArgoCD)**

#### `platform/argocd/rbac/gatekeeper-permissions.yaml` ✅ **EM USO**
- **Tipo**: ClusterRole + ClusterRoleBinding
- **Nome**: `argocd-platform-manager`
- **Aplicado**: ✅ Manualmente (`oc apply`)
- **Status**: ✅ Funcionando
- **Permissões**:
  - Gatekeeper (operator.gatekeeper.sh, templates, constraints)
  - ResourceQuotas, LimitRanges
  - Services, ServiceAccounts
  - Jobs (batch)
  - Redis Enterprise (app.redislabs.com)
  - ServiceMonitors, PrometheusRules (monitoring.coreos.com)
  - Grafana (grafana.integreatly.org)
  - Routes (route.openshift.io)

**Problema**: Nome do arquivo está errado (`gatekeeper-permissions.yaml` deveria ser `platform-permissions.yaml`)

---

#### `platform/argocd/rbac/argocd-monitoring-rbac.yaml` ❌ **DUPLICADO**
- **Tipo**: ClusterRole + ClusterRoleBinding
- **Nome**: `argocd-servicemonitor-manager`
- **Aplicado**: ❓ Não sabemos se foi aplicado
- **Status**: ❌ **DUPLICADO** (permissões já estão em `gatekeeper-permissions.yaml`)
- **Permissões**:
  - ServiceMonitors (monitoring.coreos.com)
  - PrometheusRules (monitoring.coreos.com)

**Ação**: ❌ **DELETAR** (duplicado)

---

#### `platform/argocd/rbac/argocd-rbac-cm.yaml` ⚠️ **DESATUALIZADO**
- **Tipo**: ConfigMap
- **Nome**: `argocd-rbac-cm`
- **Namespace**: `openshift-gitops`
- **Aplicado**: ❓ Não sabemos se foi aplicado
- **Status**: ⚠️ **DESATUALIZADO**
- **Problema**: Referencia projeto `team-orders` que não existe mais
- **Conteúdo**:
  - Maps OpenShift groups to ArgoCD AppProject roles
  - `orders-team-admins` → `proj:team-orders:admin`
  - `orders-team-developers` → `proj:team-orders:developer`
  - `orders-team-viewers` → `proj:team-orders:readonly`

**Ação**: ⚠️ **ATUALIZAR** ou **DELETAR** (se não estiver sendo usado)

---

#### `platform/argocd/rbac/openshift-monitoring-permissions.yaml` ❌ **NÃO NECESSÁRIO**
- **Tipo**: Role + RoleBinding
- **Namespace**: `openshift-monitoring`
- **Aplicado**: ❌ NÃO (criado mas não aplicado)
- **Status**: ❌ **NÃO NECESSÁRIO** (ClusterRole já funciona)

**Ação**: ❌ **DELETAR**

---

### **2. Redis RBACs (Gerenciados pelo ArgoCD)** ✅

#### `clusters/redis-cluster-demo/argocd-rbac.yaml` ✅ **EM USO**
- **Tipo**: ArgoCD Application
- **Nome**: `redis-rbac-demo`
- **Status**: ✅ Synced & Healthy
- **Gerencia**: Helm chart `redis-multi-namespace-rbac`
- **Values**: `clusters/redis-cluster-demo/rbac.yaml`

#### `clusters/redis-cluster-demo/rbac.yaml` ✅ **EM USO**
- **Tipo**: Helm values
- **Conteúdo**:
  - Cluster name: `demo`
  - Database namespaces: team1-dev, team1-prod, team2-dev, team2-prod
  - Namespace label: `redis-db-namespace: enabled`

#### `helm-charts/redis-multi-namespace-rbac/` ✅ **EM USO**
- **Templates**:
  - `cluster-role.yaml` - ClusterRole for operator
  - `cluster-rolebinding.yaml` - ClusterRoleBinding
  - `role.yaml` - Role in each database namespace
  - `rolebinding.yaml` - RoleBinding in each database namespace

---

## 🎯 Recomendações

### **Opção 1: Manter Status Quo (Mais Simples)** ⭐ **RECOMENDADO**

**Ações**:
1. ❌ **DELETAR** `platform/argocd/rbac/argocd-monitoring-rbac.yaml` (duplicado)
2. ❌ **DELETAR** `platform/argocd/rbac/openshift-monitoring-permissions.yaml` (não necessário)
3. ⚠️ **ATUALIZAR** `platform/argocd/rbac/argocd-rbac-cm.yaml` (ou deletar se não usado)
4. ✏️ **RENOMEAR** `gatekeeper-permissions.yaml` → `platform-permissions.yaml`
5. ✅ **MANTER** `redis-rbac-demo` Application (já gerenciado pelo ArgoCD)

**Vantagens**:
- ✅ Menos mudanças
- ✅ Evita chicken-and-egg problem
- ✅ Funciona perfeitamente

**Desvantagens**:
- ❌ RBAC principal não é GitOps (aplicado manualmente)

---

### **Opção 2: Full GitOps (Mais Complexo)**

**Ações**:
1. Criar Application `platform-rbac` (Wave 0)
2. Mover `platform-permissions.yaml` para ser gerenciado pelo ArgoCD
3. Bootstrap inicial manual (uma vez)
4. Depois ArgoCD gerencia automaticamente

**Vantagens**:
- ✅ 100% GitOps
- ✅ Rastreabilidade completa

**Desvantagens**:
- ❌ Mais complexo
- ❌ Chicken-and-egg problem no bootstrap

---

## 📊 Status Atual no Cluster

```bash
# ClusterRoles ArgoCD
argocd-platform-manager  ✅ (aplicado manualmente)

# ClusterRoleBindings ArgoCD
argocd-platform-manager  ✅ (aplicado manualmente)

# Applications ArgoCD
redis-rbac-demo  ✅ Synced & Healthy
```

---

## 🚀 Próximos Passos

**Qual opção você prefere?**
- **Opção 1**: Limpar duplicados e manter RBAC principal manual
- **Opção 2**: Migrar tudo para GitOps (mais trabalho)


