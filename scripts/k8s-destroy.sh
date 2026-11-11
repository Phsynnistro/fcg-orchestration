#!/usr/bin/env bash
# Remove TUDO da FCG no cluster (inclusive os PVCs = dados dos bancos e do RabbitMQ).
set -euo pipefail
read -r -p "Apagar o namespace 'fcg' e todos os dados? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }
kubectl delete namespace fcg --wait=true
