# ADR-0002 — RabbitMQ + MassTransit 8.x

**Contexto.** O desafio permite RabbitMQ ou Kafka. Os fluxos são comandos/eventos de negócio com
poucos consumidores, sem necessidade de replay histórico nem de streaming de alto volume.

**Decisão.** RabbitMQ 4.1 com MassTransit **8.5.10** (versão fixada).

**Por quê RabbitMQ e não Kafka.** Kafka brilha em log imutável, replay e throughput massivo; aqui
isso seria custo operacional sem benefício (partições, consumer groups, retenção). RabbitMQ entrega
roteamento por exchange, filas por consumidor, DLQ (`_error`) e retry de forma nativa e simples.

**Por quê MassTransit e não RabbitMQ.Client puro.** Topologia automática, serialização, retry,
outbox/inbox transacional, test harness em memória. Implementar o outbox à mão é onde a maioria dos
times introduz bugs de consistência.

**Por quê fixar a linha 8.x.** A partir da v9 o MassTransit é **comercial**. A v8 é Apache 2.0.

**Atenção ao material do curso.** `services.AddMassTransitHostedService()` (Aula 3) está **obsoleto**
desde a v8: o hosted service é registrado automaticamente por `AddMassTransit`.

**Consequências.**
- ➖ Dependência de uma biblioteca com mudança de licença: monitorar fim de suporte da v8.
- ➕ Trocar RabbitMQ por Azure Service Bus é, em grande parte, trocar `UsingRabbitMq` por `UsingAzureServiceBus`.
