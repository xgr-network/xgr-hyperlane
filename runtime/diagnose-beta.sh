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
