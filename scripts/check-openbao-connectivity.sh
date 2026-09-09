#!/usr/bin/env bash
set -euo pipefail

kubectl delete pod openbao-connectivity-check -n payroll-dev --ignore-not-found >/dev/null
kubectl run openbao-connectivity-check \
  --namespace payroll-dev \
  --image=curlimages/curl:8.16.0 \
  --restart=Never \
  --command -- sh -c 'curl -fsS -o /dev/null http://openbao-external.payroll-dev.svc.cluster.local:8200/v1/sys/health'
kubectl wait --namespace payroll-dev --for=jsonpath='{.status.phase}'=Succeeded \
  pod/openbao-connectivity-check --timeout=90s >/dev/null
kubectl delete pod openbao-connectivity-check -n payroll-dev --wait=false >/dev/null
printf 'Pod-to-OpenBao connectivity verified.\n'
