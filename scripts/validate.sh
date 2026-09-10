#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

docker compose -f "${project_dir}/openbao/docker-compose.yaml" config --quiet
helm lint "${project_dir}/helm/app" -f "${project_dir}/helm/app/values-dev.yaml"
rendered=$(mktemp)
trap 'rm -f "${rendered}"' EXIT
helm template demo-java-app "${project_dir}/helm/app" \
  --namespace demo-dev -f "${project_dir}/helm/app/values-dev.yaml" >"${rendered}"
rg -q 'kind: (Deployment|Service|Ingress)' "${rendered}"
if helm template demo-java-app "${project_dir}/helm/app" \
  --namespace demo-dev -f "${project_dir}/helm/app/values-dev.yaml" \
  --set image.repository= >/dev/null 2>&1; then
  printf 'Invalid chart fixture unexpectedly rendered.\n' >&2
  exit 1
fi
if rg -q 'secret/data|Initial Root Token|Unseal Key' "${rendered}"; then
  printf 'Sensitive OpenBao material found in rendered chart.\n' >&2
  exit 1
fi
helm lint "${project_dir}/gitops/bootstrap" --set repoUrl=https://example.invalid/devops-lab.git
helm template devops-lab "${project_dir}/gitops/bootstrap" --set repoUrl=https://example.invalid/devops-lab.git >/dev/null
kubectl kustomize "${project_dir}/infra/external-secrets/demo-java-app" >/dev/null

if command -v mvn >/dev/null && java -version 2>&1 | rg -q 'version "21'; then
  mkdir -p "${project_dir}/.generated/m2"
  mvn -q -s "${project_dir}/demo-java-app/.mvn/settings.xml" \
    -Dmaven.repo.local="${project_dir}/.generated/m2" \
    -f "${project_dir}/demo-java-app/pom.xml" test
else
  printf 'Skipping host Maven test; make app-build runs tests with the pinned Java 21 builder.\n'
fi

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
