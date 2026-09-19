#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="ghcr.io/hyperlane-xyz/hyperlane-agent:2.3.0"
DUMMY_KEY="0000000000000000000000000000000000000000000000000000000000000001"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

DOCKER_CMD=(docker)
if ! docker info >/dev/null 2>&1; then
  if sudo -n docker info >/dev/null 2>&1; then
    DOCKER_CMD=(sudo -n docker)
  else
    echo "Docker daemon unavailable" >&2
    exit 1
  fi
fi

sed "s/REPLACE_WITH_SECRET_VALIDATOR_KEY/0x${DUMMY_KEY}/g" \
  "${ROOT}/.env.validator.beta.example" > "${TMP}/validator.env"
sed "s/REPLACE_WITH_SECRET_RELAYER_KEY/0x${DUMMY_KEY}/g" \
  "${ROOT}/.env.relayer.beta.example" > "${TMP}/relayer.env"

mkdir -p "${TMP}/validator-db" "${TMP}/relayer-db" "${TMP}/checkpoints"
chmod 777 "${TMP}/validator-db" "${TMP}/relayer-db" "${TMP}/checkpoints"

sanitize() {
  sed -E \
    -e 's/0x[0-9A-Fa-f]{64}/0x[REDACTED_32B_HEX]/g' \
    -e 's/(^|[^0-9A-Fa-f])[0-9A-Fa-f]{64}([^0-9A-Fa-f]|$)/\\1[REDACTED_32B_HEX]\\2/g'
}

run_agent() {
  local agent="$1"
  local env_file="$2"
  local db_mount="$3"
  local name="xgr-hyperlane-${agent}-preflight"
  local log="${TMP}/${agent}.log"

  "${DOCKER_CMD[@]}" rm -f "${name}" >/dev/null 2>&1 || true

  set +e
  timeout 12s "${DOCKER_CMD[@]}" run --rm --name "${name}" \
    --env-file "${env_file}" \
    -v "${ROOT}/xgrchain.json:/config/xgrchain.json:ro" \
    -v "${db_mount}:/data/${agent}" \
    -v "${TMP}/checkpoints:/checkpoints" \
    "${IMAGE}" "./${agent}" >"${log}" 2>&1
  local rc=$?
  set -e

  "${DOCKER_CMD[@]}" rm -f "${name}" >/dev/null 2>&1 || true

  if [[ "${rc}" -eq 124 ]]; then
    echo "${agent} preflight passed: configuration parsed and process remained alive."
    return 0
  fi

  echo "${agent} preflight failed with exit code ${rc}." >&2
  sanitize < "${log}" >&2
  return 1
}

"${DOCKER_CMD[@]}" pull "${IMAGE}" >/dev/null
run_agent validator "${TMP}/validator.env" "${TMP}/validator-db"
run_agent relayer "${TMP}/relayer.env" "${TMP}/relayer-db"

echo "Hyperlane 2.3.0 beta configuration preflight passed with dummy keys."
