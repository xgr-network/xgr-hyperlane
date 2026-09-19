#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${ROOT}/runtime-state"
KEYS="${STATE}/keys"
XGRCHAIN_BIN="${XGRCHAIN_BIN:-/usr/local/bin/xgrchain}"
COMPOSE_FILE="${ROOT}/docker-compose.beta.yml"
COMPOSE_VERSION="v5.5.1"
MODE="${1:-prepare}"

if [[ ! -x "${XGRCHAIN_BIN}" ]]; then
  echo "xgrchain binary not found at ${XGRCHAIN_BIN}" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }

ensure_compose_plugin() {
  if docker compose version >/dev/null 2>&1; then
    return 0
  fi

  local machine asset tmpdir plugin_dir plugin
  machine="$(uname -m)"
  case "${machine}" in
    x86_64) asset="docker-compose-linux-x86_64" ;;
    aarch64|arm64) asset="docker-compose-linux-aarch64" ;;
    *)
      echo "unsupported architecture for Docker Compose bootstrap: ${machine}" >&2
      exit 1
      ;;
  esac

  command -v curl >/dev/null 2>&1 || {
    echo "curl is required to install the pinned Docker Compose user plugin" >&2
    exit 1
  }

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN
  curl --fail --location --silent --show-error \
    "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/${asset}" \
    --output "${tmpdir}/${asset}"
  curl --fail --location --silent --show-error \
    "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/${asset}.sha256" \
    --output "${tmpdir}/${asset}.sha256"

  (
    cd "${tmpdir}"
    sha256sum --check "${asset}.sha256"
  )

  plugin_dir="${HOME}/.docker/cli-plugins"
  plugin="${plugin_dir}/docker-compose"
  install -d -m 700 "${plugin_dir}"
  install -m 755 "${tmpdir}/${asset}" "${plugin}"

  docker compose version >/dev/null 2>&1 || {
    echo "Docker Compose plugin installation failed" >&2
    exit 1
  }
  echo "Installed Docker Compose ${COMPOSE_VERSION} as a user-scoped CLI plugin."
}

ensure_compose_plugin

COMPOSE_CMD=(docker compose)
if ! docker info >/dev/null 2>&1; then
  if sudo -n docker info >/dev/null 2>&1; then
    COMPOSE_PLUGIN="${HOME}/.docker/cli-plugins/docker-compose"
    if [[ ! -x "${COMPOSE_PLUGIN}" ]]; then
      echo "user-scoped Docker Compose plugin missing at ${COMPOSE_PLUGIN}" >&2
      exit 1
    fi
    COMPOSE_CMD=(sudo -n "${COMPOSE_PLUGIN}")
    echo "Docker socket requires elevated access; using passwordless sudo for Compose only."
  else
    echo "Docker daemon is not accessible to this user and passwordless sudo is unavailable." >&2
    exit 1
  fi
fi

mkdir -p "${STATE}" "${KEYS}"

if [[ "${MODE}" == "--rotate-keys" ]]; then
  echo "Stopping closed-beta runtime and discarding beta DB/checkpoint volumes before key rotation."
  "${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" down -v || true
  rm -rf "${KEYS}/validator" "${KEYS}/relayer"
  rm -f "${ROOT}/.env.validator.beta" "${ROOT}/.env.relayer.beta"
fi

mkdir -p "${KEYS}/validator" "${KEYS}/relayer"
chmod 700 "${STATE}" "${KEYS}" "${KEYS}/validator" "${KEYS}/relayer"

ensure_key() {
  local dir="$1"
  if [[ ! -f "${dir}/consensus/validator.key" ]]; then
    "${XGRCHAIN_BIN}" secrets init \
      --data-dir "${dir}" \
      --insecure \
      --ecdsa=true \
      --bls=false \
      --network=false >/dev/null
  fi
  chmod 440 "${dir}/consensus/validator.key"
}

ensure_key "${KEYS}/validator"
ensure_key "${KEYS}/relayer"

VALIDATOR_ADDRESS="$("${XGRCHAIN_BIN}" secrets output --data-dir "${KEYS}/validator" --validator | tr -d '\r\n')"
RELAYER_ADDRESS="$("${XGRCHAIN_BIN}" secrets output --data-dir "${KEYS}/relayer" --validator | tr -d '\r\n')"
VALIDATOR_KEY="$(tr -d '\r\n' < "${KEYS}/validator/consensus/validator.key")"
RELAYER_KEY="$(tr -d '\r\n' < "${KEYS}/relayer/consensus/validator.key")"

sed "s/REPLACE_WITH_SECRET_VALIDATOR_KEY/0x${VALIDATOR_KEY}/g" \
  "${ROOT}/.env.validator.beta.example" > "${ROOT}/.env.validator.beta"
sed "s/REPLACE_WITH_SECRET_RELAYER_KEY/0x${RELAYER_KEY}/g" \
  "${ROOT}/.env.relayer.beta.example" > "${ROOT}/.env.relayer.beta"
chmod 600 "${ROOT}/.env.validator.beta" "${ROOT}/.env.relayer.beta"

cat > "${STATE}/addresses.txt" <<EOF
validator=${VALIDATOR_ADDRESS}
relayer=${RELAYER_ADDRESS}
EOF
chmod 644 "${STATE}/addresses.txt"

"${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" config >/dev/null

echo "Hyperlane beta runtime prepared."
echo "Validator address: ${VALIDATOR_ADDRESS}"
echo "Relayer/Base deployer address: ${RELAYER_ADDRESS}"
echo "Private keys remain host-local."
echo "Base->XGR must remain paused."

if [[ "${MODE}" == "--start" ]]; then
  "${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" pull
  "${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" up -d
  "${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" ps
elif [[ "${MODE}" != "prepare" && "${MODE}" != "--rotate-keys" ]]; then
  echo "unsupported mode: ${MODE}" >&2
  exit 2
fi
