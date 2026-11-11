# ADR-0013 — Repositório de orquestração como repositório de ambiente

**Contexto.** O enunciado pede duas coisas que parecem conflitar:
1. *"Os manifestos devem estar em uma pasta /k8s na raiz do projeto de cada repositório"*;
2. no vídeo, *"mostrar os arquivos de manifesto no repositório de orquestração (Deployment, Service, ConfigMap,
   Secret)"* e *"demonstrar o deploy (kubectl apply -f .)"*.

**Decisão.** Padrão GitOps de **repositório de ambiente**:
- a fonte da verdade de cada serviço é o `/k8s` do **seu** repositório (o time do serviço é dono dos seus manifestos);
- `fcg-orchestration/k8s/` reúne o ambiente completo: namespace, RabbitMQ, Jaeger e uma cópia dos manifestos
  de cada serviço, com prefixo numérico (`20-users-api-*`, `30-catalog-api-*`...) que define a ordem de aplicação;
- a cópia é feita por `scripts/k8s-sync-manifests.sh`, e o CI do orquestrador (`--check`) falha se houver divergência.

Resultado: `cd fcg-orchestration/k8s && kubectl apply -f .` sobe tudo, e cada repositório de serviço continua
aplicável isoladamente (`kubectl apply -f .` no seu `/k8s`, que inclui o namespace).

**Alternativas.**
- *Kustomize com bases remotas*: elegante, mas exige `kubectl apply -k` (não `-f .`) e um `kustomization.yaml`
  dentro de cada `/k8s`, que quebraria o `kubectl apply -f .` nos repositórios dos serviços.
- *Só no orquestrador*: viola o requisito 1.

**Consequências.**
- ➖ Duplicação controlada: editar sempre no repositório do serviço e rodar o sync. O CI pega esquecimentos.
- ➕ Em produção, é exatamente o desenho usado com Argo CD/Flux: o CI do serviço atualiza a tag no repositório de ambiente.
