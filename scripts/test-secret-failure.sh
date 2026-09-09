#!/usr/bin/env bash
set -euo pipefail

name=payroll-invalid-source
namespace=payroll-dev
cleanup() {
  kubectl delete externalsecret "${name}" -n "${namespace}" --ignore-not-found --wait=false >/dev/null
}
trap cleanup EXIT

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: payroll-invalid-source
  namespace: payroll-dev
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: openbao
  target:
    name: payroll-invalid-source
  data:
    - secretKey: VALUE
      remoteRef:
        key: payroll/dev/does-not-exist
        property: value
YAML

for _ in $(seq 1 30); do
  ready=$(kubectl get externalsecret "${name}" -n "${namespace}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [[ "${ready}" = False ]] && break
  sleep 1
done
test "${ready}" = False
test "$(kubectl get externalsecret "${name}" -n "${namespace}" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}')" = SecretSyncedError
if kubectl get secret "${name}" -n "${namespace}" >/dev/null 2>&1; then
  printf 'Unexpected Secret created for invalid source.\n' >&2
  exit 1
fi

printf 'Invalid source reported SecretSyncedError without creating a Secret.\n'
