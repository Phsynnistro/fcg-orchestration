# ADR-0003 — Transactional Outbox e Inbox

**Contexto.** Todo serviço que muda estado E publica evento sofre do *dual-write problem*: banco e broker
não participam da mesma transação. O RabbitMQ garante entrega *at-least-once*, então duplicatas acontecem.

**Decisão.** MassTransit Entity Framework Outbox:
- **Bus Outbox** nos endpoints HTTP (UsersAPI, CatalogAPI): `IPublishEndpoint.Publish` + `SaveChanges` gravam
  entidade e mensagem atomicamente.
- **Consumer Outbox + Inbox** nos consumers com banco (CatalogAPI, PaymentsAPI): o MassTransit abre a transação
  (`RepeatableRead`), registra o `MessageId` no inbox, executa o consumer, faz `SaveChanges` e commit.

Verificado no fonte do MassTransit 8.5.10 (`EntityFrameworkOutboxContextFactory`): a transação roda dentro de
`Database.CreateExecutionStrategy()`, por isso `EnableRetryOnFailure` do Npgsql é compatível.

**Consequências.**
- ➕ Nenhum evento perdido nem "evento fantasma"; reentregas não duplicam efeito.
- ➕ O cadastro e a compra continuam funcionando com o RabbitMQ fora do ar (o outbox acumula e entrega depois).
- ➖ Latência extra de entrega (`QueryDelay` = 1 s) e três tabelas a mais por banco.
- ➖ NotificationsAPI não tem banco ⇒ sem inbox ⇒ e-mail pode duplicar em reentrega (aceito; ver arquitetura §9).
