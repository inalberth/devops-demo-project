#!/usr/bin/env bash
set -euo pipefail

kubectl wait --for=condition=Ready nodes --all --timeout=120s >/dev/null
helm status argocd -n argocd >/dev/null
helm status external-secrets -n external-secrets >/dev/null
docker exec openbao bao status -format=json | jq -e '.initialized and (.sealed | not)' >/dev/null
kubectl wait -n demo-dev --for=condition=Ready secretstore/openbao --timeout=120s >/dev/null
kubectl wait -n demo-dev --for=condition=Ready externalsecret/demo-java-app-database --timeout=120s >/dev/null
kubectl get secret demo-java-app-database -n demo-dev >/dev/null
kubectl rollout status deployment/demo-java-app -n demo-dev --timeout=180s >/dev/null

if [[ "${REQUIRE_ARGO_APP:-true}" = true ]]; then
  kubectl get application demo-java-app-dev -n argocd >/dev/null
  kubectl wait -n argocd --for=jsonpath='{.status.sync.status}'=Synced application/demo-java-app-dev --timeout=180s >/dev/null
  kubectl wait -n argocd --for=jsonpath='{.status.health.status}'=Healthy application/demo-java-app-dev --timeout=180s >/dev/null
fi

curl -fsS -o /dev/null http://demo-java-app.localhost
printf 'Smoke test passed; no secret values were read.\n'
