# Architecture Decision Records

Cada ADR registra **uma** decisão: contexto, decisão, alternativas descartadas e consequências (inclusive as
negativas). Decisões não são apagadas: quando mudam, um novo ADR **substitui** o anterior — como a 0010 fez com a 0008.

| # | Decisão | Status |
|---|---|---|
| [0001](0001-repositorio-por-servico-e-contratos-duplicados.md) | Repositório por serviço e contratos duplicados | Aceita |
| [0002](0002-rabbitmq-e-masstransit-8.md) | RabbitMQ + MassTransit 8.x | Aceita |
| [0003](0003-transactional-outbox-e-inbox.md) | Transactional Outbox e Inbox | Aceita |
| [0004](0004-database-per-service-postgresql.md) | Database per Service com PostgreSQL | Aceita |
| [0005](0005-jwt-rs256-com-jwks.md) | JWT RS256 com JWKS | Aceita |
| [0006](0006-event-carried-state-transfer-nas-notificacoes.md) | Event-carried state transfer para notificações | Aceita (revisitar) |
| [0007](0007-dotnet-10-lts.md) | .NET 10 LTS | Aceita |
| [0008](0008-statefulset-para-componentes-com-estado.md) | StatefulSet para Postgres e RabbitMQ | **Substituída** pela 0010 |
| [0009](0009-projeto-unico-com-camadas-por-pasta.md) | Projeto único por serviço com camadas por pasta | Aceita |
| [0010](0010-deployment-com-pvc-para-componentes-com-estado.md) | Deployment + PVC para PostgreSQL e RabbitMQ | Aceita |
| [0011](0011-observabilidade-com-opentelemetry-e-jaeger.md) | Observabilidade com OpenTelemetry e Jaeger | Aceita |
| [0012](0012-resiliencia.md) | Resiliência: retry, circuit breaker e timeouts | Aceita |
| [0013](0013-repositorio-de-ambiente.md) | Orquestrador como repositório de ambiente | Aceita |
