# Matriz de rastreabilidade — Tech Challenge Fase 2

Cada linha é um requisito do enunciado (*TC NETT – Fase 2*), onde ele está implementado e **como provar**
(o comando ou arquivo a mostrar no vídeo). Use esta tabela como checklist final antes de gravar.

Legenda: ✅ atendido · ➕ atendido e ampliado (decisão explicada na coluna Observação)

## 1. Arquitetura de microsserviços e repositórios

| # | Requisito | Implementação | Evidência | Status |
|---|---|---|---|---|
| 1.1 | Quatro microsserviços distintos | `fcg-users-api`, `fcg-catalog-api`, `fcg-payments-api`, `fcg-notifications-api` | Estrutura dos repositórios no GitHub | ✅ |
| 1.2 | Cada microsserviço em seu próprio repositório Git | 4 repositórios + `fcg-orchestration` (opcional, criado) | Links no relatório de entrega | ✅ |
| 1.3 | UsersAPI: cadastro, autenticação (JWT) e autorização | `POST /api/users`, `POST /api/auth/login` (RS256), políticas por papel (`Admin`) | `e2e-flow.sh` etapas A e D (403 × 201) | ➕ RS256 + JWKS em vez de segredo compartilhado (ADR-0005) |
| 1.4 | CatalogAPI: CRUD de jogos e início do fluxo de compra | `/api/games` (CRUD, escrita só Admin) e `POST /api/orders` | Scalar em `/scalar`; `e2e-flow.sh` etapa B | ✅ |
| 1.5 | PaymentsAPI: processar (simular) pagamento | `SimulatedPaymentGateway` (limite configurável) | Pedido Approved e Rejected no e2e | ✅ |
| 1.6 | NotificationsAPI: e-mails simulados no console | `ConsoleEmailSender` (log estruturado) | `docker compose logs notifications-api` / `kubectl logs` | ✅ |

## 2. Fluxos orientados a eventos (RabbitMQ)

| # | Requisito | Implementação | Evidência | Status |
|---|---|---|---|---|
| 2.1 | UsersAPI publica `UserCreatedEvent` ao criar usuário | `RegisterUserHandler` (Transactional Outbox) | Exchange `fcg.user-created` no RabbitMQ UI | ➕ outbox garante evento ⇔ usuário (ADR-0003) |
| 2.2 | NotificationsAPI consome e envia boas-vindas | `UserCreatedConsumer` | Log "E-MAIL ENVIADO" | ✅ |
| 2.3 | CatalogAPI publica `OrderPlacedEvent` com UserId, GameId, Price | `PlaceOrderHandler` | Contrato `Contracts/Events/OrderPlacedEvent.cs` | ➕ + `OrderId` (correlação/idempotência) |
| 2.4 | PaymentsAPI consome, processa e publica `PaymentProcessedEvent` (Approved/Rejected) | `OrderPlacedConsumer` → `ProcessOrderPaymentHandler` | `GET /api/payments/orders/{id}` | ➕ idempotência: nunca cobra duas vezes |
| 2.5 | CatalogAPI consome; se Approved, adiciona à biblioteca | `PaymentProcessedConsumer` → `ProcessPaymentResultHandler` | `GET /api/library` | ✅ |
| 2.6 | NotificationsAPI consome; se Approved, envia confirmação | `PaymentProcessedConsumer` (Notifications) | Log do e-mail; nenhum e-mail no Rejected | ✅ |

## 3. Orquestração local

| # | Requisito | Implementação | Evidência | Status |
|---|---|---|---|---|
| 3.1 | Cada repositório de serviço com seu Dockerfile | `Dockerfile` na raiz de cada um | Estrutura dos repositórios | ✅ |
| 3.2 | (Opcional) quinto repositório de orquestração | `fcg-orchestration` | — | ✅ |
| 3.3 | Dockerfiles otimizados, multi-stage | `build` → `test` (opcional) → `final` chiseled, não-root | `docker images fcg/*` (tamanho) | ➕ scan Trivy no CI |
| 3.4 | `docker-compose up` executa a aplicação completa | `fcg-orchestration/docker-compose.yml` (sem exigir `.env`) | `docker compose up -d --build` + `docker compose ps` | ✅ |

## 4. Kubernetes

| # | Requisito | Implementação | Evidência | Status |
|---|---|---|---|---|
| 4.1 | Manifestos em `/k8s` na raiz de cada repositório | `k8s/` em todos os 5 repositórios | Estrutura dos repositórios | ✅ |
| 4.2 | Uso obrigatório de **Deployments** (sem Pods isolados) | 9 Deployments: 4 APIs, 3 PostgreSQL, RabbitMQ, Jaeger | `kubectl -n fcg get deploy` | ✅ (ADR-0010) |
| 4.3 | **ConfigMaps** para configuração não sensível (filas, URLs) | `*-api-config` (filas `Messaging__Queues__*`, `Jwt__MetadataAddress=http://users-api:80/...`, `OTEL_EXPORTER_OTLP_ENDPOINT`) + `rabbitmq-config` (arquivo) | `kubectl -n fcg get cm` | ✅ |
| 4.4 | **Secrets** para dados sensíveis | `*-api-secrets` (connection string, credenciais, chave JWT), `*-db-credentials`, `rabbitmq-credentials` | `kubectl -n fcg get secret` | ✅ |
| 4.5 | Comunicação pelo nome do Service (ex.: `http://payments-api:80`) | `rabbitmq:5672`, `<svc>-db:5432`, `http://users-api:80`, `http://jaeger:4317` | ConfigMaps e Secrets | ✅ |
| 4.6 | Deploy testado em cluster local | Kind / Minikube / Docker Desktop (script detecta) | `kubectl get pods` | ✅ |

## 5. Entregáveis

| # | Requisito | Onde | Status |
|---|---|---|---|
| 5.1 | Vídeo ≤ 20 min cobrindo todos os itens | Roteiro minuto a minuto em `docs/roteiro-video.md` | a gravar |
| 5.2 | Mostrar manifestos (Deployment, Service, ConfigMap, Secret) **no repositório de orquestração** | `fcg-orchestration/k8s/` contém o ambiente completo (ADR-0013) | ✅ |
| 5.3 | `kubectl apply -f .` + `kubectl get pods` | `cd fcg-orchestration/k8s && kubectl apply -f .` | ✅ |
| 5.4 | README por serviço com finalidade e variáveis de ambiente | `README.md` de cada repositório (tabela de variáveis com origem ConfigMap/Secret) | ✅ |
| 5.5 | README principal com instruções de Docker e Kubernetes | `fcg-orchestration/README.md` | ✅ |
| 5.6 | Relatório de entrega (nome do grupo, participantes/Discord, links, vídeo) | `docs/relatorio-entrega.txt` (modelo) | a preencher |

## 6. Além do enunciado (justificativas)

| Item | Por quê | Referência |
|---|---|---|
| Transactional Outbox/Inbox | Sem ele, um crash entre "salvar" e "publicar" perde eventos; reentregas duplicariam efeito | ADR-0003 |
| JWT RS256 + JWKS | Quem valida não consegue emitir tokens (menor privilégio) | ADR-0005, Aula 07 |
| OpenTelemetry + Jaeger | Ver a compra atravessando 3 serviços num único trace | ADR-0011, Aula 06 |
| Retry exponencial, circuit breaker (kill switch e Polly) | Falhas transitórias não viram erro para o usuário nem mensagem perdida | ADR-0012, Aula 05 |
| HPA, probes, anotações, PVC | Conteúdo das aulas de Kubernetes aplicado | Aulas 3, 6, 7 e 8 |
| Rate limiting no login/cadastro | Mitiga força bruta | Aula 07 |
| Trivy no CI | Análise de vulnerabilidades das imagens | Docker — Segurança de Contêineres |
