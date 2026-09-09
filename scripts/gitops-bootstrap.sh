#!/usr/bin/env bash
set -euo pipefail

: "${GIT_REPO_URL:?Set GIT_REPO_URL to a repository reachable by Argo CD}"
GIT_TARGET_REVISION=${GIT_TARGET_REVISION:-main}
export GIT_REPO_URL GIT_TARGET_REVISION

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
generated_dir="${project_dir}/.generated"
generated_file="${generated_dir}/root-application.yaml"

git -C "${project_dir}" rev-parse --is-inside-work-tree >/dev/null
git -C "${project_dir}" ls-remote "${GIT_REPO_URL}" "${GIT_TARGET_REVISION}" >/dev/null

mkdir -p "${generated_dir}"
envsubst <"${project_dir}/gitops/root-application.yaml.tpl" >"${generated_file}"
kubectl apply --dry-run=server -f "${generated_file}" >/dev/null
kubectl apply -f "${generated_file}"

printf 'Root application submitted. Watch with: kubectl get applications -n argocd -w\n'
