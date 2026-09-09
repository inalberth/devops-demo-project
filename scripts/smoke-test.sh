#!/usr/bin/env bash
set -euo pipefail

kubectl wait --for=condition=Ready nodes --all --timeout=120s >/dev/null
helm status argocd -n argocd >/dev/null
helm status external-secrets -n external-secrets >/dev/null
docker exec openbao bao status -format=json | jq -e '.initialized and (.sealed | not)' >/dev/null
kubectl wait -n payroll-dev --for=condition=Ready secretstore/openbao --timeout=120s >/dev/null
kubectl wait -n payroll-dev --for=condition=Ready externalsecret/payroll-database --timeout=120s >/dev/null
kubectl get secret payroll-database -n payroll-dev >/dev/null
kubectl rollout status deployment/payroll -n payroll-dev --timeout=180s >/dev/null

if [[ "${REQUIRE_ARGO_APP:-true}" = true ]]; then
  kubectl get application payroll-dev -n argocd >/dev/null
  kubectl wait -n argocd --for=jsonpath='{.status.sync.status}'=Synced application/payroll-dev --timeout=180s >/dev/null
  kubectl wait -n argocd --for=jsonpath='{.status.health.status}'=Healthy application/payroll-dev --timeout=180s >/dev/null
fi

curl -fsS -o /dev/null http://payroll.localhost
printf 'Smoke test passed; no secret values were read.\n'
