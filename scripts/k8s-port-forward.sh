#!/usr/bin/env bash
# Expõe os Services ClusterIP em localhost (mesmas portas do docker compose). Ctrl+C encerra todos.
set -euo pipefail
NS=fcg; pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
forward() { kubectl -n "$NS" port-forward "svc/$1" "$2" >/dev/null 2>&1 & pids+=($!); echo "  http://localhost:${2%%:*}  →  svc/$1"; }
echo "Port-forward ativo:"
forward users-api 5001:80
forward catalog-api 5002:80
forward payments-api 5003:80
forward notifications-api 5004:80
forward rabbitmq 15672:15672
forward jaeger 16686:16686
echo "(Ctrl+C para encerrar)"
wait
