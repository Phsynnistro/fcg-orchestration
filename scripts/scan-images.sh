#!/usr/bin/env bash
# Análise de vulnerabilidades das imagens com Trivy (disciplina Docker — Segurança de Contêineres).
# Usa o trivy instalado; se não houver, roda o Trivy em container (precisa do socket do Docker).
#   ./scripts/scan-images.sh            (TAG=1.0.0 por padrão)
set -euo pipefail
TAG="${TAG:-1.0.0}"
SEVERITY="${SEVERITY:-CRITICAL,HIGH}"
for svc in users-api catalog-api payments-api notifications-api; do
  image="fcg/$svc:$TAG"
  printf '\n\033[1;36m▶ %s\033[0m\n' "$image"
  if command -v trivy >/dev/null; then
    trivy image --severity "$SEVERITY" --ignore-unfixed "$image"
  else
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.74.0 \
      image --severity "$SEVERITY" --ignore-unfixed "$image"
  fi
done
