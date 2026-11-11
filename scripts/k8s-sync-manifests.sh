#!/usr/bin/env bash
# =============================================================================
#  Sincroniza os manifestos dos 4 microsserviços para fcg-orchestration/k8s/.
#
#  Fonte da verdade: a pasta /k8s de CADA repositório de serviço (requisito do desafio).
#  Este repositório é o "repositório de ambiente" (padrão GitOps): reúne tudo o que roda no
#  cluster para que "kubectl apply -f ." em k8s/ suba o ambiente completo.
#
#    ./scripts/k8s-sync-manifests.sh           # copia
#    ./scripts/k8s-sync-manifests.sh --check   # só verifica divergência (exit 1 se houver) — use no CI
# =============================================================================
set -euo pipefail
ORCH="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$ORCH/.." && pwd)"
CHECK="${1:-}"
declare -A PREFIX=([users-api]=20 [catalog-api]=30 [payments-api]=40 [notifications-api]=50)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

for svc in users-api catalog-api payments-api notifications-api; do
  src="$ROOT/fcg-$svc/k8s"
  [[ -d "$src" ]] || { echo "✖ $src não encontrado (clone os repositórios lado a lado)"; exit 1; }
  for f in "$src"/*.yaml; do
    name="$(basename "$f")"
    [[ "$name" == "00-namespace.yaml" ]] && continue   # o namespace do ambiente já existe aqui (00-namespace.yaml)
    cp "$f" "$tmp/${PREFIX[$svc]}-$svc-$name"
  done
done

if [[ "$CHECK" == "--check" ]]; then
  status=0
  for f in "$tmp"/*.yaml; do cmp -s "$f" "$ORCH/k8s/$(basename "$f")" || { echo "✖ divergente: k8s/$(basename "$f")"; status=1; }; done
  for f in "$ORCH"/k8s/[2-5]0-*-api-*.yaml; do [[ -e "$tmp/$(basename "$f")" ]] || { echo "✖ órfão: k8s/$(basename "$f")"; status=1; }; done
  [[ $status -eq 0 ]] && echo "✔ manifestos sincronizados"
  exit $status
fi

rm -f "$ORCH"/k8s/[2-5]0-*-api-*.yaml
cp "$tmp"/*.yaml "$ORCH/k8s/"
echo "✔ $(ls "$tmp" | wc -l) manifestos copiados para k8s/"
