# ADR-0010 — Deployment + PVC para PostgreSQL e RabbitMQ

> Substitui a [ADR-0008](0008-statefulset-para-componentes-com-estado.md).

**Contexto.** A primeira versão usava StatefulSet para bancos e broker. A revisão contra o enunciado e o
material mostrou dois pontos: (1) o desafio declara *"É obrigatório o uso de Deployments para gerenciar os
Pods"*; (2) a trilha de Kubernetes do curso cobre Pods, Rótulos/Anotações, Services, ConfigMaps,
ReplicaSets, **Deployments, Volumes (PV/PVC/StorageClass)**, Probes e HPA — StatefulSet não faz parte do material.
Insistir num recurso fora do escopo, contra um requisito literal, era um risco de avaliação sem ganho real
num ambiente local de nó único.

**Decisão.** Todos os workloads são Deployments. Os componentes com estado usam:
- `PersistentVolumeClaim` (`ReadWriteOnce`, StorageClass padrão do cluster) — conteúdo da Aula 6;
- `replicas: 1` e `strategy: Recreate` — o pod antigo libera o volume **antes** do novo montar, então nunca
  existem dois Postgres escrevendo no mesmo diretório (com `RollingUpdate` isso poderia acontecer);
- no RabbitMQ, `spec.template.spec.hostname: rabbitmq` — o broker guarda os dados em `mnesia/rabbit@<hostname>`;
  com o hostname aleatório do pod, cada recriação "esqueceria" filas e mensagens persistidas.

**Alternativas.**
- *StatefulSet*: correto para produção com múltiplas réplicas (identidade e volume por pod). Fica como evolução.
- *Banco gerenciado* (Azure Database for PostgreSQL) e *RabbitMQ Cluster Operator*: o que se usaria de fato em produção.

**Consequências.**
- ➕ Requisito atendido literalmente e alinhado ao material; o vídeo mostra `kubectl get deploy` com tudo.
- ➖ Durante o `Recreate` há alguns segundos de indisponibilidade do banco/broker. Aceitável: as APIs têm retry,
  o outbox segura os eventos e os consumers voltam a consumir sozinhos.
- ➖ Não escala horizontalmente — e não deveria: banco relacional não escala aumentando `replicas`.
