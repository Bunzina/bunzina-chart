# bunzina-chart

Repositório do **`app-chart`** — um Helm chart **genérico e reutilizável** para
aplicações stateless com banco in-cluster **opcional**. Não tem nada hardcoded:
nomes, imagem, ingress, HPA e Postgres saem todos de `values`.

Cada aplicação (como o Bunzina) cria seu próprio **umbrella** — um chart só com
`Chart.yaml` + `values.yaml` — que declara o `app-chart` como dependência e
preenche os valores. É o padrão **subchart/umbrella** do Helm.

---

## Estrutura

```
charts/app-chart/
  Chart.yaml                 type: application, version 0.1.0
  values.yaml                defaults genéricos (app/database desligados)
  templates/
    _helpers.tpl             labels/selector parametrizados por nome
    namespace.yaml
    deployment.yaml          \
    service.yaml              | aplicação stateless (lê .Values.app)
    ingress.yaml             |   ingress/hpa só se habilitados
    hpa.yaml                 |
    configmap.yaml           |
    secret.yaml              /
    postgres-statefulset.yaml \
    postgres-service.yaml      | banco opcional (lê .Values.database)
    postgres-secret.yaml      /
```

## O que renderiza

| Bloco | Recursos | Condição |
| --- | --- | --- |
| `app` | Deployment, Service, ConfigMap, Secret | sempre |
| `app.ingress` | Ingress (ALB) | `app.ingress.enabled` |
| `app.autoscaling` | HorizontalPodAutoscaler | `app.autoscaling.enabled` |
| `database` | StatefulSet, Service headless, Secret (+ PVC) | `database.enabled` |
| — | Namespace | sempre |

---

## Como consumir (umbrella)

No repo da aplicação, crie um umbrella que dependa do `app-chart`:

```yaml
# <app>/charts/<app>-chart/Chart.yaml
apiVersion: v2
name: bunzina-chart
type: application
version: 0.1.0
dependencies:
  - name: app-chart
    version: "0.1.0"
    repository: "file://../../../bunzina-chart/charts/app-chart"   # repos lado a lado
    # nos guias 04+: repository: "oci://<conta>.dkr.ecr.us-east-1.amazonaws.com"
```

```yaml
# <app>/charts/<app>-chart/values.yaml — tudo aninhado sob "app-chart"
app-chart:
  namespace: bunzina
  app:
    name: bunzina
    image: { repository: <ecr>/bunzina, tag: "" }
    ingress: { enabled: true, className: alb, annotations: {...} }
    autoscaling: { enabled: true, minReplicas: 2, maxReplicas: 10, targetCPU: 70 }
    config: { APP_ENV: prod, PROD_DB_HOST: postgres, ... }
    secret: { JWT_SECRET: ..., PROD_DB_USER: ..., ... }
  database:
    enabled: true
    name: postgres
    persistence: { storage: 10Gi, storageClassName: gp3 }
    secret: { POSTGRES_USER: bun, POSTGRES_PASSWORD: change-me, POSTGRES_DB: bunzina }
```

```bash
helm dependency build charts/bunzina-chart      # resolve o app-chart
helm install bunzina charts/bunzina-chart \
  --namespace bunzina --create-namespace \
  --set app-chart.app.image.tag=<sha-da-imagem>
```

> Para um app **sem banco**, basta `database.enabled: false`. Para um app **sem
> ingress**, `app.ingress.enabled: false` (use `service.type: LoadBalancer`).

---

## Principais valores (`app-chart`)

| Chave | Padrão | Descrição |
| --- | --- | --- |
| `namespace` | `default` | Namespace dos recursos |
| `app.name` | `app` | Nome do Deployment/Service/Ingress/HPA |
| `app.image.repository` / `.tag` | `""` | Imagem (tag cai em `appVersion` se vazia) |
| `app.containerPort` | `3000` | Porta do container |
| `app.service.port` | `80` | Porta do Service |
| `app.ingress.enabled` | `false` | Cria o Ingress (ALB) |
| `app.autoscaling.enabled` | `false` | Liga o HPA |
| `app.config` / `app.secret` | `{}` | Mapas → ConfigMap / Secret |
| `database.enabled` | `false` | Sobe o Postgres in-cluster |
| `database.name` | `postgres` | Nome do StatefulSet/Service (= `PROD_DB_HOST`) |
| `database.persistence.storage` | `1Gi` | Tamanho do PVC |
| `database.persistence.storageClassName` | `""` | StorageClass do PVC |
| `database.secret` | `{}` | `POSTGRES_USER/PASSWORD/DB` |

---

## Pré-requisitos do cluster (para o Bunzina)

- `StorageClass` **`gp3`** + EBS CSI driver (PVC do Postgres).
- **AWS Load Balancer Controller** (para o Ingress virar ALB).
- **metrics-server** (para o HPA por CPU).

> Infra provisionada pelo Terraform em [Bunzina/bunzina](https://github.com/Bunzina/bunzina) (`infra/`).

---

## Publicação (OCI)

O `app-chart` é publicado no ECR como artefato OCI:

```bash
helm package charts/app-chart
helm push app-chart-0.1.0.tgz oci://<conta>.dkr.ecr.us-east-1.amazonaws.com
```

O `helm push` usa o **nome do chart** (`app-chart`) como repositório no registry.
Suba `version` no `Chart.yaml` a cada nova versão.
