# ADR-0004 — Database per Service com PostgreSQL

**Contexto.** Microsserviços que compartilham banco voltam a ser um monólito distribuído: um ALTER TABLE
de um time quebra o outro, e o banco vira o canal de integração.

**Decisão.** Uma instância PostgreSQL 17 por serviço com estado (users-db, catalog-db, payments-db).
Nenhum serviço conhece a connection string de outro. NotificationsAPI é stateless.

**Por quê PostgreSQL e não SQL Server.** Cada instância de SQL Server em container pede ~2 GB de RAM;
três instâncias num cluster local (Kind/Minikube) inviabilizam a máquina do desenvolvedor. Postgres sobe
com ~30 MB. Além disso, o **índice único parcial** (`WHERE "Status" = 'Pending'`) resolve com elegância a
regra "no máximo uma compra pendente por usuário/jogo" sob concorrência.

**Alternativa considerada.** Uma instância com um *database* por serviço (separação lógica): mais barata,
aceitável em dev, mas compartilha CPU/memória/backup — um serviço pode degradar os outros.

**Consequências.**
- ➕ Autonomia de schema e de escala; falha de um banco afeta um serviço só.
- ➖ Sem JOIN entre serviços: o Catalog guarda `UserId` sem FK, e a consistência entre serviços é **eventual**.
