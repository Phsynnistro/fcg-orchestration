# ADR-0008 — StatefulSet para Postgres e RabbitMQ

> **Status: SUBSTITUÍDA pela [ADR-0010](0010-deployment-com-pvc-para-componentes-com-estado.md).**
> Mantida por histórico: a análise técnica continua válida para produção, mas a decisão mudou
> após a revisão contra o enunciado e o material do curso.

**Contexto.** O desafio torna obrigatório o uso de Deployments (e proíbe Pods isolados). Bancos e broker têm estado.

**Decisão.** Deployments para os quatro microsserviços (stateless). **StatefulSet** para PostgreSQL e RabbitMQ.

**Por quê.** Um StatefulSet garante:
- identidade estável (`rabbitmq-0`, `users-db-0`) — o RabbitMQ associa o diretório de dados ao nome do nó;
  com Deployment, cada pod novo teria hostname aleatório e "esqueceria" filas e mensagens persistidas;
- um PVC por pod via `volumeClaimTemplates`, que acompanha o pod em reinícios;
- criação e término ordenados.

O espírito do requisito ("não crie Pods soltos, use um controlador") é atendido: StatefulSet também é um
controlador que recria pods. Deployment + PVC para um banco funciona com 1 réplica e `strategy: Recreate`,
mas é o recurso errado para o problema.

**Consequências.**
- ➖ Possível questionamento na avaliação — esta ADR e o vídeo explicam a escolha.
- ➕ Em produção, nem um nem outro: banco gerenciado (Azure Database for PostgreSQL) e operator para o RabbitMQ.
