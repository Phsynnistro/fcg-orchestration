# Roteiro do vídeo (≤ 20 min)

Cada bloco cobre um item obrigatório do enunciado (coluna "Requisito"). Ensaie com cronômetro — o limite de
20 minutos é eliminatório. **Antes de gravar:** suba tudo uma vez (`docker compose up -d --build` e o deploy no
cluster) para que nenhuma imagem seja baixada durante a gravação. A matriz [`matriz-requisitos.md`](matriz-requisitos.md)
é o seu checklist.

| Tempo | Bloco | Requisito do enunciado | O que mostrar |
|---|---|---|---|
| 0:00–1:30 | Problema e arquitetura | contexto | `docs/arquitetura.md` §1: por que sair do monólito; 4 serviços, 3 eventos, 1 banco por serviço |
| 1:30–3:00 | Repositórios | "Apresentar a estrutura dos diferentes repositórios" | Os 5 repositórios. Em um serviço: `src/` (Domain/Application/Infrastructure/Presentation), `tests/`, `Dockerfile`, `k8s/` (00 a 06), `README.md`. No orquestrador: `docker-compose.yml`, `k8s/`, `scripts/`, `docs/` |
| 3:00–4:30 | Código-chave | mensageria e boas práticas | `PlaceOrderHandler` (UserId do token, preço do banco, outbox, 202); `ProcessOrderPaymentHandler` (nunca cobra 2×); contrato duplicado + `ContractTests` |
| 4:30–5:30 | Dockerfile | "multi-stage builds" | Estágios build/test/final; imagem chiseled não-root; `docker images "fcg/*"` com o tamanho |
| 5:30–7:00 | docker compose | "executar com docker-compose a partir do repositório de orquestração" | `docker compose up -d --build` (sem `.env`!) → `docker compose ps` |
| 7:00–10:30 | Fluxos completos | "Executar o fluxo de cadastro e o fluxo de compra completos" | `./scripts/e2e-flow.sh`. Em paralelo: `docker compose logs -f notifications-api` (e-mails); RabbitMQ UI (exchanges `fcg.*`, uma fila por serviço); **Jaeger**: o trace da compra atravessando os 3 serviços |
| 10:30–12:30 | Manifestos | "Mostrar os arquivos de manifesto no repositório de orquestração (Deployment, Service, ConfigMap, Secret)" | `fcg-orchestration/k8s/`: `13-rabbitmq-deployment.yaml` (Recreate + hostname), `30-catalog-api-01-configmap.yaml` (filas, `http://users-api:80`), `30-catalog-api-02-secrets.yaml` (Secret ≠ criptografia), `30-catalog-api-04-deployment.yaml` (probes, anotações, sem `replicas`), `30-catalog-api-05-service.yaml`, `30-catalog-api-06-hpa.yaml` |
| 12:30–15:00 | Deploy no cluster | "kubectl apply -f ." e "kubectl get pods" | `cd k8s && kubectl apply -f .` → `kubectl -n fcg get pods` (todos `Running`, `READY 1/1`) → `kubectl -n fcg get deploy,svc,cm,secret,pvc,hpa` |
| 15:00–17:00 | Fluxo no cluster | comunicação por nome de Service | `./scripts/k8s-port-forward.sh` + `./scripts/e2e-flow.sh`; `kubectl -n fcg logs -l app.kubernetes.io/name=notifications-api --tail=40` |
| 17:00–19:30 | Resiliência (diferencial) | "serviços resilientes e escaláveis" | 1) `kubectl -n fcg delete pod <payments-api-...>` → o Deployment recria; 2) `kubectl -n fcg rollout history deploy/catalog-api` (change-cause); 3) **outbox ao vivo**: `kubectl -n fcg scale deploy/rabbitmq --replicas=0` → faça uma compra (202, fica Pending) → `--replicas=1` → o pedido vira Approved sozinho |
| 19:30–20:00 | Encerramento | — | Trade-offs conscientes (ADRs) e próximos passos (`docs/arquitetura.md` §9) |

> Dica para o bloco de resiliência: com o RabbitMQ em 0 réplicas, a compra continua respondendo 202 porque o
> evento fica na tabela `OutboxMessage` do Catalog. Ao voltar o broker, o entregador do outbox publica e o fluxo
> se completa. É a prova visual do porquê do outbox — mais convincente que qualquer slide.

## Perguntas que você deve saber responder (sem consultar)

1. Por que 202 e não 201 na compra? → consistência eventual (arquitetura §3).
2. O que acontece se o RabbitMQ cair durante um cadastro? → o outbox guarda o evento e entrega depois (ADR-0003).
3. E se a mesma mensagem chegar duas vezes ao Payments? → inbox + pagamento existente é republicado, nunca recobrado.
4. Por que o banco usa `strategy: Recreate`? → volume `ReadWriteOnce`: nunca dois Postgres no mesmo diretório (ADR-0010).
5. Por que a liveness não verifica o banco? → evitar restart em cascata quando o banco cai (comentário no `04-deployment.yaml`).
6. Por que o Deployment não tem `replicas`? → quem decide é o HPA; o campo faria cada `apply` desfazer a escala.
7. Secret do Kubernetes é seguro? → não: Base64 ≠ criptografia; produção usa Key Vault/External Secrets.
8. Como o trace atravessa o RabbitMQ? → o MassTransit propaga o `traceparent` (W3C) nos headers da mensagem.
9. Por que os manifestos estão em dois lugares? → fonte da verdade no serviço, ambiente agregado no orquestrador, CI checa a sincronia (ADR-0013).
