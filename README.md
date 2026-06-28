# bunzina-chart

Helm chart que empacota a **API Bunzina** (Bun + Elysia) e seu **PostgreSQL** para rodar em Kubernetes (AWS EKS). É a forma versionada e parametrizável de fazer deploy — substitui os manifests `kubectl apply -f k8s/...` por uma única release com `values.yaml`, `helm upgrade` e `rollback`.

O chart é publicado como **artefato OCI** no Amazon ECR.

---

## O que o chart instala

| Componente | Recursos |
| --- | --- |
| **API** | `Deployment` + `Service` (ClusterIP) + `Ingress` (ALB) + `HPA` |
| **Banco** | `StatefulSet` Postgres + `Service` headless + `PVC` (EBS `gp3`) |
| **Config** | `ConfigMap` (não-sensível) + `Secret` (credenciais) |
| **Namespace** | criado pelo próprio chart |

```
            Internet
               │
        ┌──────▼──────┐
        │ Ingress/ALB │
        └──────┬──────┘
        ┌──────▼──────┐      ┌──────────────────┐
        │   Service   │      │ HPA (CPU 70%)    │
        └──────┬──────┘      │ 2 → 10 réplicas  │
        ┌──────▼───────────────────┴──┐
        │ Deployment: bunzina (:3000)  │
        │ readiness/liveness /health   │
        └──────┬───────────────────────┘
               │ PROD_DB_HOST=postgres
        ┌──────▼──────────────┐
        │ StatefulSet: postgres│ + PVC (gp3, 10Gi)
        └──────────────────────┘
```

---

## Pré-requisitos

- Cluster Kubernetes (EKS) com a `StorageClass` **`gp3`** e o **EBS CSI driver** (PVC do Postgres).
- **AWS Load Balancer Controller** instalado, para o `Ingress` provisionar o ALB.
- Helm ≥ 3.12.

> A infraestrutura é provisionada pelo Terraform no repositório [Bunzina/bunzina](https://github.com/Bunzina/bunzina) (`infra/`).

---

## Instalação

### A partir do código (local)

```bash
helm install bunzina charts/bunzina \
  --namespace bunzina --create-namespace \
  --set image.repository=<conta>.dkr.ecr.us-east-1.amazonaws.com/bunzina \
  --set image.tag=<sha-da-imagem>
```

### A partir do ECR (OCI)

```bash
# Autentica o Helm no registry OCI do ECR
aws ecr get-login-password --region us-east-1 \
  | helm registry login --username AWS --password-stdin <conta>.dkr.ecr.us-east-1.amazonaws.com

# Instala/atualiza puxando o chart publicado
helm upgrade --install bunzina \
  oci://<conta>.dkr.ecr.us-east-1.amazonaws.com/bunzina-chart \
  --version 0.1.0 \
  --namespace bunzina --create-namespace \
  --set image.tag=<sha-da-imagem>
```

### Verificar e desinstalar

```bash
helm status bunzina -n bunzina
kubectl get pods -n bunzina

helm uninstall bunzina -n bunzina
```

---

## Principais valores (`values.yaml`)

| Chave | Padrão | Descrição |
| --- | --- | --- |
| `namespace` | `bunzina` | Namespace onde tudo é criado |
| `image.repository` | ECR `.../bunzina` | Imagem da API |
| `image.tag` | `""` | Tag da imagem (cai em `appVersion` se vazio) |
| `replicaCount` | `2` | Réplicas (ignorado quando o HPA está ligado) |
| `resources` | requests/limits | CPU/memória da API |
| `config` | mapa | Variáveis não-sensíveis → `ConfigMap` |
| `secret` | mapa | Credenciais (JWT, DB, SMTP) → `Secret` |
| `service.port` | `80` | Porta do `Service` |
| `ingress.enabled` | `true` | Cria o `Ingress` (ALB) |
| `ingress.className` | `alb` | IngressClass do AWS LB Controller |
| `autoscaling.enabled` | `true` | Liga o `HPA` (2 → 10, CPU 70%) |
| `postgres.enabled` | `true` | Sobe o Postgres in-cluster |
| `postgres.storage` | `10Gi` | Tamanho do volume EBS |
| `postgres.storageClassName` | `gp3` | StorageClass do PVC |

> Sobrescreva com `--set chave=valor` ou um arquivo próprio via `-f meus-values.yaml`.

> ⚠️ Os valores de `secret` e `postgres.password` no `values.yaml` são apenas placeholders (`change-me`). Em produção, passe-os via `--set`/`-f` fora do versionamento.

---

## Publicação

O chart é empacotado e enviado ao ECR como OCI:

```bash
helm package charts/bunzina
helm push bunzina-chart-0.1.0.tgz oci://<conta>.dkr.ecr.us-east-1.amazonaws.com
```

O `helm push` usa o **nome do chart** (`Chart.yaml`: `bunzina-chart`) como nome do repositório no registry. Para publicar uma nova versão, suba o campo `version` no `Chart.yaml`.
