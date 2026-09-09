#!/usr/bin/env bash
set -euo pipefail

credentials_file=${OPENBAO_CREDENTIALS_FILE:-${HOME}/Documents/devops-lab/openbao-credentials.txt}
bao_container=${OPENBAO_CONTAINER:-openbao}

test -r "${credentials_file}" || {
  printf 'OpenBao credentials not readable: %s\n' "${credentials_file}" >&2
  exit 1
}

if [[ "$(docker exec "${bao_container}" bao status -format=json | jq -r '.sealed')" = false ]]; then
  printf 'OpenBao is already unsealed.\n'
  exit 0
fi

mapfile -t keys < <(sed -nE 's/^Unseal Key [1-3]:[[:space:]]*//p' "${credentials_file}")
test "${#keys[@]}" -eq 3

for key in "${keys[@]}"; do
  docker exec "${bao_container}" bao operator unseal "${key}" >/dev/null
done

docker exec "${bao_container}" bao status -format=json | jq -e '.sealed | not' >/dev/null
printf 'OpenBao unsealed.\n'
