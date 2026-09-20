#!/usr/bin/env bash
set -Eeuo pipefail

RPC_URL="${XGR_RPC_URL:-https://rpc.xgr.network}"
DESTINATION="${XGR_ATTESTATION_DESTINATION:-base}"

curl -fsS "${RPC_URL}"   -H 'content-type: application/json'   --data "{"jsonrpc":"2.0","id":1,"method":"xgr_getInterchainAttestation","params":["${DESTINATION}"]}"   | jq .
