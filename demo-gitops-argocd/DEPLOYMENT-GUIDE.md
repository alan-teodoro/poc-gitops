# Redis Demo - Deployment Guide

Este guia explica como fazer o deploy do Redis Enterprise em fases separadas.

---

## 📋 Arquivos de ArgoCD Applications

Existem 2 opções de deployment:

### Opção 1: Deploy Separado em Fases (RECOMENDADO)

**Vantagem**: Controle total sobre quando criar cada componente

1. **`argocd-app-cluster.yaml`** - Cria apenas o cluster
2. **`argocd-app-certificate.yaml`** - Cria apenas o certificado TLS (opcional)
3. **`argocd-app-databases.yaml`** - Cria apenas o database

### Opção 2: Deploy Completo

**Vantagem**: Tudo de uma vez

- **`argocd-application.yaml`** - Cria cluster + database juntos (sem certificado customizado)

---

## 🚀 Deploy em Fases (Opção 1 - Recomendado)

### Pré-requisito: Namespace

**IMPORTANTE**: O namespace `redis-demo` deve existir antes de aplicar os ArgoCD Applications.

```bash
# Verificar se o namespace existe
oc get namespace redis-demo

# Se não existir, criar manualmente:
oc create namespace redis-demo
oc label namespace redis-demo app=redis-demo demo=gitops-argocd
```

**Nota**: O namespace NÃO é gerenciado pelo ArgoCD para evitar deletar acidentalmente o operador Redis Enterprise que está instalado na workspace.

---

### Fase 1: Criar o Cluster

```bash
# Aplicar o ArgoCD Application do cluster
oc apply -f demo-gitops-argocd/argocd-app-cluster.yaml

# Aguardar o cluster ficar pronto
oc get rec -n redis-demo -w
```

**O que será criado:**
- ✅ Redis Enterprise Cluster `demo-cluster` (3 nodes, SEM TLS customizado)

**Aguarde até o cluster estar com status `Running`**

---

### Fase 2: Adicionar Certificado TLS (OPCIONAL)

```bash
# Gerar o certificado usando o script
cd demo-gitops-argocd/tls-setup
./generate-certs.sh

# Aplicar o ArgoCD Application do certificado
oc apply -f demo-gitops-argocd/argocd-app-certificate.yaml

# Verificar que o secret foi criado
oc get secret redis-cluster-tls -n redis-demo
```

**O que será criado:**
- ✅ Secret `redis-cluster-tls` com certificado TLS customizado

**Nota:** Após criar o certificado, você precisa atualizar o cluster para usá-lo (veja TLS-SETUP.md)

---

### Fase 3: Criar o Database

```bash
# Aplicar o ArgoCD Application do database
oc apply -f demo-gitops-argocd/argocd-app-databases.yaml

# Aguardar o database ficar pronto
oc get redb -n redis-demo -w
```

**O que será criado:**
- ✅ Database `customers` (100MB, replication, persistence)

---

## 🔄 Deploy Completo (Opção 2)

Se preferir criar tudo de uma vez:

```bash
# Verificar/criar namespace primeiro
oc get namespace redis-demo || oc create namespace redis-demo

# Aplicar o ArgoCD Application completo
oc apply -f demo-gitops-argocd/argocd-application.yaml

# Aguardar tudo ficar pronto
oc get rec,redb -n redis-demo -w
```

**O que será criado:**
- ✅ Redis Enterprise Cluster `demo-cluster`
- ✅ Database `customers`

---

## 🔐 Adicionar TLS Certificate (Opcional)

Após o cluster estar rodando, você pode adicionar um certificado TLS customizado.

Consulte o arquivo **`TLS-SETUP.md`** para instruções detalhadas.

---

## 🗑️ Limpeza

### Deletar apenas database:

```bash
oc delete application redis-demo-databases -n openshift-gitops
```

### Deletar apenas certificado:

```bash
oc delete application redis-demo-certificate -n openshift-gitops
```

### Deletar apenas cluster:

```bash
oc delete application redis-demo-cluster -n openshift-gitops
```

### Deletar tudo (se usou deploy separado):

```bash
oc delete application redis-demo-databases redis-demo-certificate redis-demo-cluster -n openshift-gitops
```

### Deletar tudo (se usou deploy completo):

```bash
oc delete application redis-demo -n openshift-gitops
```

---

## 📊 Verificação

```bash
# Ver ArgoCD Applications
oc get applications -n openshift-gitops | grep redis-demo

# Ver recursos criados
oc get all,rec,redb -n redis-demo

# Ver status do cluster
oc get rec demo-cluster -n redis-demo -o yaml

# Ver status do database
oc get redb -n redis-demo
```

---

## 🎯 Recomendação

**Use a Opção 1 (Deploy Separado em Fases)** para:
- ✅ Ter controle sobre quando criar cada componente
- ✅ Validar que o cluster está funcionando antes de criar o database
- ✅ Adicionar certificado TLS de forma incremental (opcional)
- ✅ Demonstrar GitOps de forma incremental
- ✅ Facilitar troubleshooting

## 📝 Ordem Recomendada de Deploy

1. **Namespace** → Criar manualmente (pré-requisito)
2. **Cluster** → Aguardar ficar `Running`
3. **Certificado** (opcional) → Atualizar cluster para usar o certificado
4. **Database** → Aguardar ficar `active`

## ⚠️ Importante sobre o Namespace

O namespace `redis-demo` **NÃO** é gerenciado pelo ArgoCD porque:
- ✅ Evita deletar acidentalmente o operador Redis Enterprise instalado na workspace
- ✅ Permite deletar cluster e database sem afetar o namespace
- ✅ Maior segurança: namespace persiste mesmo se deletar todos os ArgoCD Applications

