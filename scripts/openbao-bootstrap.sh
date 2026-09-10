#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
credentials_file=${OPENBAO_CREDENTIALS_FILE:-${HOME}/Documents/devops-lab/openbao-credentials.txt}
bao_container=${OPENBAO_CONTAINER:-openbao}
cluster_name=${CLUSTER_NAME:-devops-lab}
k3d_network=k3d-${cluster_name}

if [[ -z "${BAO_TOKEN:-}" ]]; then
  test -r "${credentials_file}" || {
    printf 'Set BAO_TOKEN or provide %s\n' "${credentials_file}" >&2
    exit 1
  }
  BAO_TOKEN=$(sed -nE 's/^Initial Root Token:[[:space:]]*//p' "${credentials_file}")
fi
test -n "${BAO_TOKEN}"

kubectl apply -f "${project_dir}/infra/openbao/openbao-token-reviewer.yaml" >/dev/null
app_resources="${project_dir}/infra/external-secrets/demo-java-app"
kubectl apply -f "${app_resources}/namespace.yaml" >/dev/null
kubectl apply -f "${app_resources}/service-account.yaml" >/dev/null

OPENBAO_HOST_GATEWAY=$(docker network inspect "${k3d_network}" \
  --format '{{(index .IPAM.Config 0).Gateway}}')
export OPENBAO_HOST_GATEWAY
mkdir -p "${project_dir}/.generated"
envsubst <"${app_resources}/openbao-endpoint-slice.yaml.tpl" \
  >"${project_dir}/.generated/openbao-endpoint-slice.yaml"
kubectl apply -f "${app_resources}/openbao-service.yaml" >/dev/null
kubectl apply -f "${project_dir}/.generated/openbao-endpoint-slice.yaml" >/dev/null

reviewer_token=$(kubectl create token openbao-token-reviewer -n kube-system --duration=24h)
ca_file=$(mktemp)
trap 'rm -f "${ca_file}"' EXIT
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d >"${ca_file}"

if ! docker exec -e BAO_TOKEN="${BAO_TOKEN}" "${bao_container}" \
  bao secrets list -format=json | jq -e 'has("secret/")' >/dev/null; then
  docker exec -e BAO_TOKEN="${BAO_TOKEN}" "${bao_container}" \
    bao secrets enable -path=secret -version=2 kv >/dev/null
fi
docker exec -i -e BAO_TOKEN="${BAO_TOKEN}" "${bao_container}" \
  bao policy write demo-java-app-read - <"${project_dir}/infra/openbao/demo-java-app-read.hcl" >/dev/null
if ! docker exec -e BAO_TOKEN="${BAO_TOKEN}" "${bao_container}" \
  bao auth list -format=json | jq -e 'has("kubernetes/")' >/dev/null; then
  docker exec -e BAO_TOKEN="${BAO_TOKEN}" "${bao_container}" bao auth enable kubernetes >/dev/null
fi

docker cp "${ca_file}" "${bao_container}:/tmp/kubernetes-ca.crt" >/dev/null
docker exec -u 0 "${bao_container}" chmod 0644 /tmp/kubernetes-ca.crt
if ! docker inspect "${bao_container}" \
  --format '{{json .NetworkSettings.Networks}}' | jq -e --arg network "${k3d_network}" 'has($network)' >/dev/null; then
  docker network connect "${k3d_network}" "${bao_container}"
fi
docker exec -e BAO_TOKEN="${BAO_TOKEN}" "${bao_container}" \
  bao write auth/kubernetes/config \
    kubernetes_host="https://k3d-${cluster_name}-serverlb:6443" \
    token_reviewer_jwt="${reviewer_token}" \
    kubernetes_ca_cert=@/tmp/kubernetes-ca.crt >/dev/null
docker exec -e BAO_TOKEN="${BAO_TOKEN}" "${bao_container}" \
  bao write auth/kubernetes/role/demo-java-app-dev \
    bound_service_account_names=demo-java-app-secrets \
    bound_service_account_namespaces=demo-dev \
    audience=vault alias_name_source=serviceaccount_name \
    policies=demo-java-app-read ttl=1h >/dev/null

printf 'OpenBao Kubernetes integration converged.\n'
