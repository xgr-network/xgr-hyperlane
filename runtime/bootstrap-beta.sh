#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${ROOT}/runtime-state"
KEYS="${STATE}/keys"
XGRCHAIN_BIN="${XGRCHAIN_BIN:-/usr/local/bin/xgrchain}"
COMPOSE_FILE="${ROOT}/docker-compose.beta.yml"

if [[ ! -x "${XGRCHAIN_BIN}" ]]; then
  echo "xgrchain binary not found at ${XGRCHAIN_BIN}" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose plugin is required" >&2; exit 1; }

mkdir -p "${KEYS}/validator" "${KEYS}/relayer"
chmod 700 "${STATE}" "${KEYS}" "${KEYS}/validator" "${KEYS}/relayer"

ensure_key() {
  local dir="$1"
  if [[ ! -f "${dir}/consensus/validator.key" ]]; then
    "${XGRCHAIN_BIN}" secrets init       --data-dir "${dir}"       --insecure       --ecdsa=true       --bls=false       --network=false >/dev/null
  fi
  chmod 440 "${dir}/consensus/validator.key"
}

ensure_key "${KEYS}/validator"
ensure_key "${KEYS}/relayer"

VALIDATOR_ADDRESS="$("${XGRCHAIN_BIN}" secrets output --data-dir "${KEYS}/validator" --validator | tr -d '\r\n')"
RELAYER_ADDRESS="$("${XGRCHAIN_BIN}" secrets output --data-dir "${KEYS}/relayer" --validator | tr -d '\r\n')"
VALIDATOR_KEY="$(tr -d '\r\n' < "${KEYS}/validator/consensus/validator.key")"
RELAYER_KEY="$(tr -d '\r\n' < "${KEYS}/relayer/consensus/validator.key")"

sed "s/REPLACE_WITH_SECRET_VALIDATOR_KEY/0x${VALIDATOR_KEY}/g"   "${ROOT}/.env.validator.beta.example" > "${ROOT}/.env.validator.beta"
sed "s/REPLACE_WITH_SECRET_RELAYER_KEY/0x${RELAYER_KEY}/g"   "${ROOT}/.env.relayer.beta.example" > "${ROOT}/.env.relayer.beta"
chmod 600 "${ROOT}/.env.validator.beta" "${ROOT}/.env.relayer.beta"

cat > "${STATE}/addresses.txt" <<EOF
validator=${VALIDATOR_ADDRESS}
relayer=${RELAYER_ADDRESS}
EOF
chmod 644 "${STATE}/addresses.txt"

docker compose -f "${COMPOSE_FILE}" config >/dev/null

echo "Hyperlane beta runtime prepared."
echo "Validator address: ${VALIDATOR_ADDRESS}"
echo "Relayer/Base deployer address: ${RELAYER_ADDRESS}"
echo "No private keys were printed."
echo "Base->XGR must remain paused."

if [[ "${1:-}" == "--start" ]]; then
  docker compose -f "${COMPOSE_FILE}" pull
  docker compose -f "${COMPOSE_FILE}" up -d
  docker compose -f "${COMPOSE_FILE}" ps
fi
