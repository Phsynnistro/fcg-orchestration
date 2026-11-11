#!/usr/bin/env bash
# =============================================================================
#  Executa os fluxos do desafio de ponta a ponta (serve como roteiro do vídeo):
#    A) cadastro → UserCreatedEvent → e-mail de boas-vindas
#    B) compra aprovada → OrderPlaced → PaymentProcessed(Approved) → biblioteca + e-mail
#    C) compra recusada  → PaymentProcessed(Rejected) → pedido Rejected, sem e-mail
#    D) regras: compra duplicada (409), autorização por papel (403 vs 201)
#  Funciona igual para docker compose e Kubernetes (com k8s-port-forward.sh ativo).
#  Requer: curl e jq.
# =============================================================================
set -euo pipefail

USERS="${USERS_URL:-http://localhost:5001}"
CATALOG="${CATALOG_URL:-http://localhost:5002}"
PAYMENTS="${PAYMENTS_URL:-http://localhost:5003}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@fcg.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin@12345}"
EMAIL="jogador.$(date +%s)@fcg.local"
PASSWORD='Senha@123'

command -v jq >/dev/null || { echo "jq é necessário (https://jqlang.github.io/jq/)"; exit 1; }

title() { printf '\n\033[1;35m━━━ %s ━━━\033[0m\n' "$*"; }
step()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

# http MÉTODO URL [CORPO] [TOKEN]  → define $STATUS e $BODY
http() {
  local args=(-sS -X "$1" -w $'\n%{http_code}' -H 'Content-Type: application/json')
  [[ -n "${4:-}" ]] && args+=(-H "Authorization: Bearer $4")
  [[ -n "${3:-}" ]] && args+=(-d "$3")
  local response; response="$(curl "${args[@]}" "$2")"
  STATUS="${response##*$'\n'}"; BODY="${response%$'\n'*}"
}
expect() { [[ "$STATUS" == "$1" ]] || { echo "$BODY" | jq . 2>/dev/null || echo "$BODY"; fail "HTTP $STATUS (esperado $1)"; }; ok "HTTP $STATUS"; }
show()   { echo "$BODY" | jq "${1:-.}"; }

wait_order() { # aguarda o pedido sair de Pending (consistência eventual)
  local id=$1 status=Pending
  for _ in $(seq 1 30); do
    http GET "$CATALOG/api/orders/$id" "" "$TOKEN"
    status="$(echo "$BODY" | jq -r .status)"
    [[ "$status" != "Pending" ]] && break
    printf '  ... pedido %s ainda Pending\n' "$id" >&2; sleep 1
  done
  echo "$status"
}

title "A) FLUXO DE CADASTRO"
step "POST $USERS/api/users  (UsersAPI grava usuário + UserCreatedEvent no outbox)"
http POST "$USERS/api/users" "{\"name\":\"Jogador Demo\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
expect 201; show

step "Senha fraca é rejeitada com Problem Details (400)"
http POST "$USERS/api/users" '{"name":"X","email":"x@fcg.local","password":"123"}'
expect 400; show '.errors'

step "POST $USERS/api/auth/login"
http POST "$USERS/api/auth/login" "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
expect 200
TOKEN="$(echo "$BODY" | jq -r .accessToken)"
echo "  token: ${TOKEN:0:40}...  (RS256, expira em $(echo "$BODY" | jq -r .expiresIn)s)"

step "GET $USERS/api/users/me"
http GET "$USERS/api/users/me" "" "$TOKEN"; expect 200; show

title "B) COMPRA APROVADA"
step "GET $CATALOG/api/games  (anônimo)"
http GET "$CATALOG/api/games?pageSize=50"; expect 200
echo "$BODY" | jq -r '.items[] | "  \(.price | tostring | .[0:8])\t\(.title)"'
CHEAP_ID="$(echo "$BODY" | jq -r '[.items[] | select(.price <= 300)] | sort_by(.price) | .[0].id')"
EXPENSIVE_ID="$(echo "$BODY" | jq -r '[.items[] | select(.price > 300)] | .[0].id // empty')"
[[ "$CHEAP_ID" != "null" ]] || fail "Nenhum jogo até R\$ 300 no catálogo."

step "POST $CATALOG/api/orders  (CatalogAPI grava Order Pending + OrderPlacedEvent)"
http POST "$CATALOG/api/orders" "{\"gameId\":\"$CHEAP_ID\"}" "$TOKEN"
expect 202; show
ORDER_ID="$(echo "$BODY" | jq -r .id)"

step "Aguardando PaymentsAPI processar e CatalogAPI consumir PaymentProcessedEvent"
FINAL="$(wait_order "$ORDER_ID" | tail -1)"
[[ "$FINAL" == "Approved" ]] || fail "Pedido terminou como $FINAL"
ok "Pedido $ORDER_ID → Approved"

step "GET $CATALOG/api/library"
http GET "$CATALOG/api/library" "" "$TOKEN"; expect 200; show

step "GET $PAYMENTS/api/payments/orders/$ORDER_ID"
http GET "$PAYMENTS/api/payments/orders/$ORDER_ID" "" "$TOKEN"; expect 200; show

title "C) COMPRA RECUSADA (preço acima do limite simulado de R\$ 300)"
http GET "$CATALOG/api/games?pageSize=50"; expect 200
EXP_ID="$(echo "$BODY" | jq -r '[.items[] | select(.price > 300)][0].id // empty')"
EXP_TITLE="$(echo "$BODY" | jq -r '[.items[] | select(.price > 300)][0].title // empty')"

if [[ -z "$EXP_ID" ]]; then
  step "Nenhum jogo acima de R\$ 300 no catálogo: o Admin cadastra um para forçar a recusa"
  http POST "$USERS/api/auth/login" "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}"; expect 200
  ADMIN_TOKEN="$(echo "$BODY" | jq -r .accessToken)"
  EXP_TITLE="Jogo Premium $(date +%s)"
  http POST "$CATALOG/api/games" \
    "{\"title\":\"$EXP_TITLE\",\"description\":\"Criado no e2e para o fluxo Rejected\",\"genre\":\"RPG\",\"price\":349.90}" \
    "$ADMIN_TOKEN"
  expect 201
  EXP_ID="$(echo "$BODY" | jq -r .id)"
fi

step "POST $CATALOG/api/orders  (jogo: $EXP_TITLE)"
http POST "$CATALOG/api/orders" "{\"gameId\":\"$EXP_ID\"}" "$TOKEN"; expect 202
REJECTED_ID="$(echo "$BODY" | jq -r .id)"

step "Aguardando PaymentsAPI recusar e CatalogAPI consumir PaymentProcessedEvent(Rejected)"
FINAL="$(wait_order "$REJECTED_ID" | tail -1)"
[[ "$FINAL" == "Rejected" ]] || fail "Pedido terminou como $FINAL (esperado Rejected)"
http GET "$CATALOG/api/orders/$REJECTED_ID" "" "$TOKEN"; expect 200; show '{status, rejectionReason}'

step "GET $CATALOG/api/library  (o jogo recusado NÃO pode estar nela)"
http GET "$CATALOG/api/library" "" "$TOKEN"; expect 200
echo "$BODY" | jq -e --arg t "$EXP_TITLE" '[.. | objects | select(.title? == $t)] | length == 0' > /dev/null \
  || fail "O jogo recusado apareceu na biblioteca"
ok "Pedido $REJECTED_ID → Rejected; jogo ausente da biblioteca"
printf '  → Confira no log do NotificationsAPI: nenhum e-mail de confirmação para o pedido %s\n' "$REJECTED_ID"

title "D) REGRAS DE NEGÓCIO E AUTORIZAÇÃO"
step "Comprar de novo um jogo que já está na biblioteca → 409"
http POST "$CATALOG/api/orders" "{\"gameId\":\"$CHEAP_ID\"}" "$TOKEN"; expect 409; show '.detail'

GAME="{\"title\":\"Jogo Demo $(date +%s)\",\"description\":\"Criado no e2e\",\"genre\":\"Indie\",\"price\":29.90}"
step "Usuário comum tenta cadastrar jogo → 403"
http POST "$CATALOG/api/games" "$GAME" "$TOKEN"; expect 403

step "Administrador cadastra jogo → 201"
http POST "$USERS/api/auth/login" "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}"; expect 200
ADMIN_TOKEN="$(echo "$BODY" | jq -r .accessToken)"
http POST "$CATALOG/api/games" "$GAME" "$ADMIN_TOKEN"; expect 201; show '{id, title, price}'

title "CONCLUÍDO"
cat <<MSG
Veja os e-mails simulados no log do NotificationsAPI:
  docker compose logs notifications-api            (compose)
  kubectl -n fcg logs -l app.kubernetes.io/name=notifications-api --tail=80   (Kubernetes)
Filas e exchanges: http://localhost:15672  (fcg / fcg_dev_pwd)
Trace distribuído da compra: http://localhost:16686  → Service "catalog-api" → Operation "POST /api/orders"
MSG
