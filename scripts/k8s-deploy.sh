#!/usr/bin/env bash
# =============================================================================
#  Build das imagens + carga no cluster LOCAL + deploy do ambiente completo.
#  Detecta o cluster pelo contexto atual do kubectl: kind | minikube | docker-desktop.
#    ./scripts/k8s-deploy.sh                 # build + load + apply
#    SKIP_BUILD=1 ./scripts/k8s-deploy.sh    # só apply (imagens já carregadas)
#
#  O apply em si é exatamente o comando pedido no desafio:  cd k8s && kubectl apply -f .
# =============================================================================
set -euo pipefail

TAG="${TAG:-1.0.0}"
NS="fcg"
ORCH="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$ORCH/.." && pwd)"
SERVICES=(users-api catalog-api payments-api notifications-api)

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null || fail "kubectl não encontrado."
CONTEXT="$(kubectl config current-context)"
case "$CONTEXT" in
  kind-*)         CLUSTER=kind; KIND_NAME="${CONTEXT#kind-}" ;;
  minikube)       CLUSTER=minikube ;;
  docker-desktop) CLUSTER=docker-desktop ;;
  *)              CLUSTER=other ;;
esac
step "Contexto: $CONTEXT ($CLUSTER)"

if [[ -z "${SKIP_BUILD:-}" ]]; then
  command -v docker >/dev/null || fail "docker não encontrado."
  for svc in "${SERVICES[@]}"; do
    [[ -d "$ROOT/fcg-$svc" ]] || fail "Repositório $ROOT/fcg-$svc não encontrado (scripts/clone-repos.sh)."
    step "Build da imagem fcg/$svc:$TAG"
    docker build -t "fcg/$svc:$TAG" "$ROOT/fcg-$svc"
    case "$CLUSTER" in
      kind)           kind load docker-image "fcg/$svc:$TAG" --name "$KIND_NAME" ;;
      minikube)       minikube image load "fcg/$svc:$TAG" ;;
      docker-desktop) : ;; # mesmo daemon Docker: a imagem já está disponível para o cluster
      *)              echo "⚠ Cluster não reconhecido: garanta que fcg/$svc:$TAG esteja acessível aos nós." ;;
    esac
  done
fi

step "kubectl apply -f .   (em $ORCH/k8s)"
( cd "$ORCH/k8s" && kubectl apply -f . )

step "Aguardando os rollouts"
for dep in rabbitmq jaeger users-db catalog-db payments-db users-api catalog-api payments-api notifications-api; do
  kubectl -n "$NS" rollout status "deployment/$dep" --timeout=300s
done

step "Estado do namespace $NS"
kubectl -n "$NS" get deploy,pods,svc,hpa
cat <<MSG

✅ Deploy concluído.
   ./scripts/k8s-port-forward.sh   → Users 5001 | Catalog 5002 | Payments 5003 | Notifications 5004 | RabbitMQ 15672 | Jaeger 16686
   ./scripts/e2e-flow.sh           → executa os fluxos de ponta a ponta
   HPA com métricas reais: ./scripts/k8s-install-metrics-server.sh
MSG
