# Mapa do curso → projeto

Onde cada conceito das disciplinas da Fase 2 aparece no código. Serve para estudar (abra o arquivo e veja o
conceito aplicado) e para responder perguntas na apresentação.

## Docker

| Conceito (aula) | Onde no projeto | O que observar |
|---|---|---|
| Dockerfile, camadas e cache | `Dockerfile` de cada serviço | `COPY` dos `.csproj` antes do código: o `restore` só roda de novo se as dependências mudarem |
| Multi-stage build | idem | Estágios `build` (SDK) → `test` → `final` (runtime chiseled, ~110 MB) |
| Redes e volumes | `docker-compose.yml` | Rede `fcg-network` (DNS por nome do serviço) e volumes nomeados por banco |
| Docker Compose | idem | `depends_on` com `condition: service_healthy` e healthchecks de Postgres/RabbitMQ |
| Segurança de contêineres (Trivy) | `scripts/scan-images.sh`, CI de cada serviço | Imagem não-root (UID 1654), sem shell; scan bloqueia CRITICAL/HIGH corrigível |

## Kubernetes

| Conceito (aula) | Onde no projeto | O que observar |
|---|---|---|
| Pods, rótulos e anotações (Aula 3) | `04-deployment.yaml` | Labels `app.kubernetes.io/*` usados em seletores; annotations `kubernetes.io/change-cause` e `fcg.dev/*` só descrevem |
| Services e ConfigMap (Aula 4) | `05-service.yaml`, `01-configmap.yaml`, `10-rabbitmq-configmap.yaml` | ClusterIP na porta 80 → `targetPort: http` (8080); ConfigMap como **variável** (`envFrom`) e como **arquivo** (RabbitMQ) |
| ReplicaSets e Deployments (Aula 5) | `04-deployment.yaml` | `RollingUpdate` com `maxUnavailable: 0`; `kubectl rollout history` mostra o change-cause |
| Volumes (Aula 6) | `03-database.yaml`, `12-rabbitmq-pvc.yaml`, `emptyDir` em `/tmp` | PVC `ReadWriteOnce` + `strategy: Recreate` para nunca haver dois Postgres no mesmo volume |
| Probes (Aula 7) | `04-deployment.yaml` + `Presentation/HealthEndpoints.cs` | startup × liveness (não checa banco) × readiness (checa banco; no Notifications, o broker) |
| HPA (Aula 8) | `06-hpa.yaml`, `scripts/k8s-install-metrics-server.sh` | 2–5 réplicas por CPU; o Deployment **não** fixa `replicas` |
| Secrets | `02-secrets.yaml` | Base64 ≠ criptografia; produção com Key Vault/External Secrets |

## Orquestração com AKS (CI/CD)

| Conceito | Onde no projeto | O que observar |
|---|---|---|
| Pipeline de CI | `.github/workflows/ci.yml` (serviços) e `validate.yml` (orquestrador) | restore → build → test → imagem → Trivy; o orquestrador valida o compose e a sincronia dos manifestos |
| Próximo passo para AKS | `docs/arquitetura.md` §9 | Push no ACR + `kubectl apply` no AKS: muda o registry/tag, os manifestos são os mesmos |

## Microsserviços

| Conceito (aula) | Onde no projeto | O que observar |
|---|---|---|
| Decomposição por capacidade de negócio (01/02) | 4 serviços | Cada um com dados, deploy e ciclo de vida próprios |
| Banco de dados por serviço, Saga (03) | `03-database.yaml`; fluxo de compra | 3 PostgreSQL isolados; saga **coreografada** (sem orquestrador), estado local em `Order` |
| Comunicação síncrona × assíncrona; API Gateway (04) | Eventos via RabbitMQ; única chamada HTTP é o JWKS | API Gateway **não** implementado (decisão: §9 da arquitetura) |
| Resiliência: retry com backoff, circuit breaker (05) | `JwtValidationExtensions.cs` (Polly v8), `InfrastructureServiceCollectionExtensions.cs` (MassTransit) | Retry exponencial + kill switch nos consumers; pipeline padrão de resiliência no HttpClient do JWKS |
| Observabilidade: logs, métricas, tracing (06) | `Infrastructure/Observability/ObservabilityExtensions.cs`, Jaeger | Trace único atravessando HTTP → banco → RabbitMQ → outros serviços; `TraceId` nos logs |
| Segurança: JWT, OIDC, RBAC, menor privilégio, segredos (07) | UsersAPI (`/.well-known/*`), políticas `Admin`, `RateLimitingExtensions.cs` | Só o UsersAPI assina; demais validam via JWKS; 429 no excesso de login |

## Mensageria

| Conceito (aula) | Onde no projeto | O que observar |
|---|---|---|
| Producer/Consumer, eventos (1/2) | `Contracts/Events/*`, `Presentation/Consumers/*` | Eventos no passado (`OrderPlaced`, `PaymentProcessed`) |
| Exchanges, filas, bindings (2) | Painel do RabbitMQ (15672) | Exchange `fcg.payment-processed` → filas `catalog.*` e `notifications.*` (fan-out) |
| MassTransit: contratos e consumers (3) | Contratos como `record` | O material usa interfaces; `record` é a forma recomendada atual (imutável, comparável por valor) |
| Idempotência, DLQ, correlação (1/4) | Inbox do MassTransit; filas `_error`; `OrderId` em todos os eventos | Reentrega não duplica efeito; falha definitiva vai para `<fila>_error` |
| Event Sourcing (4) | — | **Não** usado: o estado atual basta; outbox não é event sourcing (só garante a publicação) |
| Kafka (5/6) | — | Descartado para este caso (ADR-0002): sem necessidade de replay/streaming |
