# Redis Enterprise Internal Logs Collection - Status Report

**Data:** 2026-02-20  
**Última atualização:** 22:40 UTC

## 📋 Resumo Executivo

Implementação do sidecar Grafana Alloy para coletar logs internos do Redis Enterprise está **95% completa**. O sidecar está rodando e lendo os arquivos de log, mas está recebendo erro **403 Forbidden** ao tentar enviar para o Loki Gateway.

## ✅ O Que Está Funcionando

### 1. Infraestrutura Base
- ✅ Redis Enterprise Cluster recriado com 3 pods (3/3 Running)
- ✅ Sidecar Alloy rodando em todos os 3 pods
- ✅ ConfigMap do Alloy criado e montado corretamente
- ✅ Helm charts configurados para injetar sidecar
- ✅ Security Context ajustado para OpenShift (runAsNonRoot: true)

### 2. Sidecar Alloy
- ✅ Container iniciando sem erros de sintaxe
- ✅ Lendo arquivos de log do diretório `/var/opt/redislabs/log/`
- ✅ Descobrindo todos os arquivos `*.log` (17+ arquivos)
- ✅ Montando volume PVC compartilhado com Redis Enterprise
- ✅ Endpoint Loki correto: `https://logging-loki-gateway-http.openshift-logging.svc:8080/api/logs/v1/application/loki/api/v1/push`

### 3. Arquivos Criados/Modificados
```
helm-charts/redis-enterprise-cluster/templates/
├── alloy-sidecar-configmap.yaml          ✅ Criado
└── rec.yaml                               ✅ Modificado (sidecar spec)

clusters/redis-cluster-demo/
└── cluster.yaml                           ✅ Modificado (logging config)

platform/observability/logging/alloy/
├── grafana-dashboards-redis-internal-logs.yaml  ✅ Modificado
└── redis-loki-permissions.yaml            ✅ Criado (não funcionou)
```

## ❌ Problema Atual: 403 Forbidden

### Erro
```
level=error msg="final error sending batch, no retries left, dropping data" 
component_path=/ component_id=loki.write.loki_gateway 
component=endpoint host=logging-loki-gateway-http.openshift-logging.svc:8080 
status=403 tenant="" 
error="server returned HTTP status 403 Forbidden (403): 
{\"error\":\"You don't have permission to access this tenant\",
\"errorType\":\"observatorium-api\",\"status\":\"error\"}"
```

### Causa Raiz
O ServiceAccount `demo-redis-cluster` (usado pelos pods do Redis) **não tem permissões** para escrever no Loki Gateway do OpenShift Logging.

### O Que Tentamos
1. ❌ Criar ClusterRole `redis-loki-writer` com regras customizadas - não funcionou
2. ❌ Criar ClusterRoleBinding para `demo-redis-cluster` - não funcionou

### O Que Descobrimos
- O ClusterLogForwarder usa ServiceAccount `logcollector` 
- O `logcollector` tem ClusterRoleBinding `logcollector-loki-writer`
- Esse ClusterRole não existe como recurso standalone (provavelmente gerenciado pelo Operator)

## 🔧 Próximos Passos (Solução) - RUNBOOK COMPLETO

### ⚠️ IMPORTANTE: Verificar Token do ServiceAccount no Alloy Config

**PRIORIDADE #1:** O Alloy precisa enviar o bearer token do ServiceAccount. Verificar se o config tem:

```yaml
loki.write "loki_gateway" {
  endpoint {
    url = "https://logging-loki-gateway-http.openshift-logging.svc:8080/api/logs/v1/application/loki/api/v1/push"

    bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"

    tls_config {
      ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    }
  }
}
```

**Verificar dentro do pod:**
```bash
oc exec demo-redis-cluster-0 -n redis-enterprise -c alloy -- cat /etc/alloy/config.alloy
```

Se o `bearer_token_file` e `ca_file` não estiverem configurados, **adicionar primeiro** antes de mexer em RBAC.

---

### Passo 1: Descobrir o ClusterRole Correto

O `logcollector` do OpenShift Logging usa um ClusterRole específico. Precisamos descobrir qual é:

```bash
oc get clusterrolebinding logcollector-loki-writer -o yaml
```

**Procurar por:**
- `roleRef.name`: Este é o ClusterRole que precisamos usar
- `subjects`: Mostra o ServiceAccount e namespace

**Exemplo de output esperado:**
```yaml
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: <NOME_DO_CLUSTERROLE>  # ← Este é o que precisamos!
subjects:
- kind: ServiceAccount
  name: logcollector
  namespace: openshift-logging
```

---

### Passo 2: Criar ServiceAccount e ClusterRoleBinding

#### Opção 2A: Criar SA `logcollector` no namespace redis-enterprise (RECOMENDADO)

**Por que:** O SA `logcollector` do `openshift-logging` não pode ser usado por pods em outro namespace. Criamos um SA com o mesmo nome no nosso namespace.

```bash
# 1. Criar ServiceAccount
oc -n redis-enterprise create sa logcollector

# 2. Criar ClusterRoleBinding (substituir ROLE_REF_NAME_AQUI pelo valor do Passo 1)
cat <<'YAML' | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: redis-enterprise-loki-writer
  annotations:
    argocd.argoproj.io/sync-wave: "14"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ROLE_REF_NAME_AQUI  # ← Substituir pelo valor real
subjects:
- kind: ServiceAccount
  name: logcollector
  namespace: redis-enterprise
YAML
```

#### Opção 2B: Usar SA `demo-redis-cluster` existente (ALTERNATIVA)

**Por que:** Reduz blast-radius, não herda outras permissões de um SA de logging.

```bash
cat <<'YAML' | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: redis-enterprise-loki-writer
  annotations:
    argocd.argoproj.io/sync-wave: "14"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ROLE_REF_NAME_AQUI  # ← Substituir pelo valor real
subjects:
- kind: ServiceAccount
  name: demo-redis-cluster
  namespace: redis-enterprise
YAML
```

---

### Passo 3: Atualizar REC para Usar o ServiceAccount

**Se escolheu Opção 2A (criar SA logcollector):**

Modificar `helm-charts/redis-enterprise-cluster/templates/rec.yaml`:

```yaml
spec:
  serviceAccountName: logcollector  # ← Mudar de demo-redis-cluster
```

**Se escolheu Opção 2B (usar demo-redis-cluster):**

Não precisa mudar nada no REC, apenas aplicar o ClusterRoleBinding.

---

### Passo 4: Aplicar e Validar

```bash
# 1. Commit e push (se mudou o REC)
git add -A
git commit -m "fix: Configure ServiceAccount for Loki write permissions"
git push

# 2. Aguardar ArgoCD sync ou forçar
oc patch application redis-cluster-demo -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# 3. Deletar pod-0 para recriar (SE mudou o SA no REC)
oc delete pod demo-redis-cluster-0 -n redis-enterprise

# 4. Aguardar pod ficar ready
oc get pods -n redis-enterprise -l app=redis-enterprise -w

# 5. Validar que o SA está correto
oc get pod demo-redis-cluster-0 -n redis-enterprise -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

---

### Passo 5: Testar Autenticação ANTES do Alloy

Validar que o ServiceAccount tem permissão para acessar o Loki Gateway:

```bash
oc exec demo-redis-cluster-0 -n redis-enterprise -c alloy -- sh -c '
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Teste simples: bater no gateway (mesmo que dê 404, queremos ver que NÃO é 403)
curl -sS --cacert "$CA" -H "Authorization: Bearer $TOKEN" \
  https://logging-loki-gateway-http.openshift-logging.svc:8080/ || true
'
```

**Resultado esperado:**
- ✅ **200, 404, ou qualquer coisa EXCETO 403** = Permissões OK
- ❌ **403 Forbidden** = Ainda tem problema de RBAC

---

### Passo 6: Verificar Logs do Alloy

```bash
oc logs demo-redis-cluster-0 -n redis-enterprise -c alloy --tail=30
```

**Sucesso:**
- ✅ Sem mensagens de erro `status=403`
- ✅ Logs sendo enviados sem "dropping data"

**Ainda com problema:**
- ❌ `status=403 ... dropping data` = Voltar ao Passo 1 e verificar roleRef

## 📝 Comandos Úteis para Debugging

### Verificar Status dos Pods
```bash
oc get pods -n redis-enterprise -l app=redis-enterprise
```

### Verificar Logs do Alloy
```bash
oc logs demo-redis-cluster-0 -n redis-enterprise -c alloy --tail=30
```

### Verificar ConfigMap do Alloy
```bash
oc get configmap alloy-sidecar-config -n redis-enterprise -o yaml | grep "url ="
```

### Verificar Config Dentro do Pod
```bash
oc exec demo-redis-cluster-0 -n redis-enterprise -c alloy -- cat /etc/alloy/config.alloy
```

### Verificar Permissões do ServiceAccount
```bash
oc get clusterrolebinding -o json | jq -r '.items[] | select(.subjects[]?.name == "demo-redis-cluster") | .metadata.name'
```

## 📊 Arquivos de Log Descobertos

O Alloy está lendo os seguintes arquivos:
- `dmcproxy.log` ⭐ (logs do proxy, **APENAS em arquivo**, não vai para stdout)
- `dmcproxy_stderr.log`
- `dmcproxy_stdout.log`
- `supervisord.log`
- `stats_archiver.log`
- `cnm_http.log`
- `crdb_controller.log`
- `metrics_exporter.log`
- `resource_mgr_stderr.log`
- `ccs-redis.log`
- `prestop_exec_action.log`
- `statsd_exporter.log`
- `sentinel_service.log`
- `rladmin.log`
- `envoy_access.log`
- `rl_info_provider.log`
- `readiness_check.log`

## 🎯 Objetivo Final

Ter os logs internos do Redis Enterprise visíveis no Grafana com a query:
```logql
{job="redis-enterprise-internal"}
```

E poder filtrar por arquivo específico:
```logql
{job="redis-enterprise-internal", log_file="dmcproxy"}
```

## 📚 Documentação Pendente

Após resolver o problema de permissões, atualizar:
- `docs/ARGOCD_IMPLEMENTATION_GUIDE.md` - Step 19 (Logging Stack)
  - Adicionar seção sobre sidecar approach
  - Documentar configuração do Helm chart
  - Adicionar queries LogQL de exemplo
  - Troubleshooting de permissões

## 🔗 Referências

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Redis Enterprise Logs](https://redis.io/docs/latest/operate/kubernetes/logs/)
- [OpenShift Logging 6.0](https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html/logging/logging-6-0)
- [Loki HTTP API](https://grafana.com/docs/loki/latest/reference/loki-http-api/)

---

**Nota:** O usuário disse "acho q vamos parar por hoje" às 22:40 UTC. Próxima sessão deve começar testando a Opção 1 (usar ServiceAccount logcollector).

