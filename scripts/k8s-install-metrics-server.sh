#!/usr/bin/env bash
# Instala o metrics-server (necessário para o HPA medir CPU — Aula 8).
# Em clusters locais (Kind, Docker Desktop) o kubelet usa certificado autoassinado: por isso o
# "--kubelet-insecure-tls" — ACEITÁVEL SÓ EM AMBIENTE LOCAL.
set -euo pipefail
VERSION="${METRICS_SERVER_VERSION:-v0.8.0}"
if [[ "$(kubectl config current-context)" == "minikube" ]]; then
  minikube addons enable metrics-server
else
  kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/$VERSION/components.yaml"
  kubectl -n kube-system patch deployment metrics-server --type=json \
    -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
echo "✔ metrics-server pronto. Em ~1 min:  kubectl top pods -n fcg   e   kubectl get hpa -n fcg"
