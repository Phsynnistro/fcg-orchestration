#!/usr/bin/env bash
# Gera um novo par RSA-2048 para assinatura de JWT (RS256).
#  - JWT_PRIVATE_KEY → PKCS#8 DER em Base64 (uma linha) — vai SÓ para o UsersAPI (.env / Secret)
#  - JWT_PUBLIC_KEY  → apenas informativo: os outros serviços obtêm a pública via JWKS automaticamente
set -euo pipefail
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -outform DER -out "$tmp" 2>/dev/null
echo "JWT_PRIVATE_KEY=$(base64 -w0 "$tmp" 2>/dev/null || base64 -i "$tmp" | tr -d '\n')"
echo "# JWT_PUBLIC_KEY (referência)=$(openssl pkey -inform DER -in "$tmp" -pubout -outform DER | base64 | tr -d '\n')"
echo
echo "# Atualize: .env (JWT_PRIVATE_KEY) e fcg-users-api/k8s/02-secrets.yaml (Jwt__PrivateKey)."
echo "# Tokens emitidos com a chave antiga deixam de ser aceitos (kid diferente)."
