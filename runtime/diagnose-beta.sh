#!/usr/bin/env bash
set -Eeuo pipefail

sanitize() {
  sed -E \
    -e 's/0x[0-9A-Fa-f]{64}/0x[REDACTED_32B_HEX]/g' \
    -e 's/(^|[^0-9A-Fa-f])[0-9A-Fa-f]{64}([^0-9A-Fa-f]|$)/\\1[REDACTED_32B_HEX]\\2/g' \
    -e 's/(AWS_SECRET_ACCESS_KEY|SECRET_ACCESS_KEY|PRIVATE_KEY|SIGNER_KEY|VALIDATOR_KEY)([^=:\"]*[=:\"][[:space:]]*)[^, }\"]+/\\1\\2[REDACTED]/Ig'
}

for service in validator relayer; do
  echo "--- ${service} sanitized diagnostics ---"
  docker compose -f docker-compose.beta.yml logs --tail=120 "${service}" 2>&1 | sanitize
done


echo "--- available signing tools ---"
for cmd in node npm npx python3 pip3 go openssl curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%s=%s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf '%s=missing\n' "$cmd"
  fi
done
python3 - <<'PY' 2>/dev/null || true
mods = ["eth_account", "web3", "eth_keys", "rlp", "Crypto", "cryptography"]
for m in mods:
    try:
        __import__(m)
        print(f"python_{m}=present")
    except Exception:
        print(f"python_{m}=missing")
PY
