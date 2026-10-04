#!/usr/bin/env bash
set -Eeuo pipefail

RPC_URL="${XGR_RPC_URL:-https://rpc.xgr.network}"
ROUTE="${1:-${XGR_ATTESTATION_ROUTE:-base}}"

payload="$(jq -cn --arg route "$ROUTE" '{jsonrpc:"2.0",id:1,method:"xgr_getInterchainAttestation",params:[$route]}')"

curl -fsS "$RPC_URL" \
  -H 'content-type: application/json' \
  --data "$payload" \
  | jq .
