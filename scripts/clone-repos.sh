#!/usr/bin/env bash
# Clona os 4 repositórios de microsserviço AO LADO deste (o compose e os scripts dependem desse layout).
#   GITHUB_OWNER=meu-usuario ./scripts/clone-repos.sh
set -euo pipefail
OWNER="${GITHUB_OWNER:?Defina GITHUB_OWNER (usuário ou organização no GitHub)}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
for repo in fcg-users-api fcg-catalog-api fcg-payments-api fcg-notifications-api; do
  if [[ -d "$ROOT/$repo/.git" ]]; then
    echo "✔ $repo já existe — git pull"; git -C "$ROOT/$repo" pull --ff-only
  else
    git clone "https://github.com/$OWNER/$repo.git" "$ROOT/$repo"
  fi
done
