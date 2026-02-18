# 📊 Observability Stack - Revisão Completa

**Data**: 2026-02-18  
**Cluster**: demo-redis-cluster  
**Status**: ⚠️ **REQUER CORREÇÕES ANTES DE APLICAR**

---

## 🔍 Resumo Executivo

A stack de observability está **quase pronta**, mas há **1 problema crítico** que precisa ser corrigido antes de aplicar:

### ❌ **Problema Crítico**
- **Conflito de Namespace**: Todos os recursos Grafana estão configurados para `openshift-monitoring`, mas a Application ArgoCD está configurada para deployar no namespace `redis-enterprise`

---

## 📦 Componentes Revisados

### ✅ **1. Prometheus Metrics (OK)**
- **ServiceMonitor**: Configurado corretamente no Helm chart
- **Service**: Expõe porta 8070 (metrics endpoint)
- **Cluster Config**: Monitoring habilitado (`monitoring.enabled: true`)
- **Scrape Interval**: 30s
- **Scrape Timeout**: 10s
- **Endpoint**: `/v2` (Prometheus v2 metrics)
- **TLS**: `insecureSkipVerify: true` (certificado auto-assinado)

### ✅ **2. Prometheus Rules (OK)**
- **Arquivo**: `prometheus-rules-redis.yaml`
- **Namespace**: `openshift-monitoring` ✅
- **Total de Alertas**: 40+ production-grade alerts
- **Categorias**:
  - Latency (2 alerts)
  - Connections (2 alerts)
  - Throughput (2 alerts)
  - Capacity (2 alerts)
  - Utilization (2 alerts)
  - Synchronization (4 alerts)
  - Nodes (5 alerts)
  - Shards (5 alerts)
  - Certificates & License (6 alerts)
  - Cluster Health (3 alerts)

### ❌ **3. Grafana Instance (PROBLEMA)**
- **Arquivo**: `grafana-instance.yaml`
- **Namespace Configurado**: `openshift-monitoring` ❌
- **Namespace Esperado pela Application**: `redis-enterprise` ❌
- **Conflito**: Application vai tentar criar no namespace errado

### ❌ **4. Grafana DataSource (PROBLEMA)**
- **Arquivo**: `grafana-datasource-prometheus.yaml`
- **Namespace Configurado**: `openshift-monitoring` ❌
- **Namespace Esperado pela Application**: `redis-enterprise` ❌

### ❌ **5. Grafana Dashboards (PROBLEMA)**
- **Arquivo**: `grafana-dashboards.yaml`
- **Namespace Configurado**: `openshift-monitoring` ❌
- **Namespace Esperado pela Application**: `redis-enterprise` ❌
- **Total de Dashboards**: 4 oficiais
  - redis-cluster-dashboard
  - redis-database-dashboard
  - redis-node-dashboard
  - redis-shard-dashboard

### ❌ **6. Grafana ConfigMaps (PROBLEMA)**
- **Arquivo**: `grafana-dashboards-configmaps.yaml`
- **Namespace Configurado**: `openshift-monitoring` ❌
- **Namespace Esperado pela Application**: `redis-enterprise` ❌

### ❌ **7. Grafana ServiceAccount (PROBLEMA)**
- **Arquivo**: `grafana-prometheus-sa.yaml`
- **Namespace Configurado**: `openshift-monitoring` ❌
- **Namespace Esperado pela Application**: `redis-enterprise` ❌

### ❌ **8. Grafana Token Job (PROBLEMA)**
- **Arquivo**: `grafana-token-secret-job.yaml`
- **Namespace Configurado**: `openshift-monitoring` ❌
- **Namespace Esperado pela Application**: `redis-enterprise` ❌

### ❌ **9. Grafana Route (PROBLEMA)**
- **Arquivo**: `grafana-route.yaml`
- **Namespace Configurado**: `openshift-monitoring` ❌
- **Namespace Esperado pela Application**: `redis-enterprise` ❌

---

## 🎯 Decisão Necessária

Você precisa decidir qual namespace usar para o Grafana:

### **Opção 1: Usar `openshift-monitoring` (Recomendado)**
**Vantagens**:
- Namespace padrão do OpenShift para monitoring
- Prometheus já está neste namespace
- Separação de concerns (monitoring separado de aplicação)

**Mudanças Necessárias**:
- ✅ Manter todos os arquivos como estão
- ❌ Mudar a Application ArgoCD para deployar em `openshift-monitoring`

### **Opção 2: Usar `redis-enterprise`**
**Vantagens**:
- Tudo relacionado ao Redis no mesmo namespace
- Mais simples para gerenciar

**Mudanças Necessárias**:
- ❌ Mudar TODOS os 8 arquivos de `openshift-monitoring` para `redis-enterprise`
- ✅ Manter a Application ArgoCD como está

---

## 📋 Arquivos que Precisam de Correção

Se escolher **Opção 1** (openshift-monitoring):
1. `platform/argocd/apps/observability.yaml` - Mudar `destination.namespace` para `openshift-monitoring`

Se escolher **Opção 2** (redis-enterprise):
1. `platform/observability/grafana-instance.yaml`
2. `platform/observability/grafana-datasource-prometheus.yaml`
3. `platform/observability/grafana-dashboards.yaml`
4. `platform/observability/grafana-dashboards-configmaps.yaml`
5. `platform/observability/grafana-prometheus-sa.yaml`
6. `platform/observability/grafana-token-secret-job.yaml`
7. `platform/observability/grafana-route.yaml`
8. `platform/observability/prometheus-rules-redis.yaml` (já está correto em openshift-monitoring)

---

## ✅ Pré-requisitos Verificados

- ✅ **Grafana Operator**: v5.21.2 instalado e funcionando
- ✅ **Prometheus**: OpenShift built-in Prometheus disponível
- ✅ **Monitoring Habilitado**: Cluster configurado com `monitoring.enabled: true`
- ✅ **ServiceMonitor Template**: Presente no Helm chart
- ✅ **Service Metrics Template**: Presente no Helm chart

---

## 🚀 Próximos Passos

1. **DECIDIR**: Qual namespace usar (openshift-monitoring ou redis-enterprise)
2. **CORRIGIR**: Aplicar as mudanças necessárias
3. **APLICAR**: Deploy da observability stack via ArgoCD
4. **VERIFICAR**: Confirmar que todos os recursos foram criados corretamente

---

## 📝 Recomendação

**Recomendo a Opção 1** (openshift-monitoring) porque:
- É o padrão do OpenShift
- Prometheus já está lá
- Melhor separação de concerns
- Apenas 1 arquivo precisa ser alterado vs 7 arquivos

**Qual opção você prefere?**

