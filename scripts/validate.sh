#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

docker compose -f "${project_dir}/openbao/docker-compose.yaml" config --quiet
helm lint "${project_dir}/charts/payroll" -f "${project_dir}/charts/payroll/values-dev.yaml"
helm template payroll "${project_dir}/charts/payroll" -f "${project_dir}/charts/payroll/values-dev.yaml" >/dev/null
helm lint "${project_dir}/gitops/bootstrap" --set repoUrl=https://example.invalid/devops-lab.git
helm template devops-lab "${project_dir}/gitops/bootstrap" --set repoUrl=https://example.invalid/devops-lab.git >/dev/null
kubectl kustomize "${project_dir}/infra/external-secrets/payroll" >/dev/null

for script in "${project_dir}"/scripts/*.sh; do
  bash -n "${script}"
done


if [[ -f "${project_dir}/.env" ]]; then
  printf 'Forbidden project-local credential file found: .env\n' >&2
  exit 1
fi

if rg -n -P --hidden --glob '!.git/**' --glob '!openbao/data/**' \
  '(?:hvs|s)\.(?=[A-Za-z0-9]{16,})(?=[A-Za-z0-9]*[0-9])[A-Za-z0-9]+' "${project_dir}"; then
  printf 'Potential OpenBao administrative credential found.\n' >&2
  exit 1
fi

printf 'Static validation passed.\n'
