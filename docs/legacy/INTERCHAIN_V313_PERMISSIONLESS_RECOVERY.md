# Permissionless XGR ILN v3.1.3 recovery

**Protocol rule:** Neither the XGR-operated relayer nor its local state, wallet, private APIs, or privileged credentials may be required to complete or recover a legitimate ILN operation. The destination Hyperlane Mailbox `process(bytes metadata, bytes message)` is permissionless; the submitting account pays its own destination-chain gas. Quorum signing remains an independent function of the XGR Interchain validators.

## Existing public data

- Source EVM RPC: canonical `ILNGateway.ILNOperation(routeId,messageId,destinationDomain,validatorFeeWei)` log, Mailbox `Dispatch` log containing the original message, MerkleTreeHook `InsertedIntoTree` logs and `tree()` historical snapshot, route registry `getRoute` at the signed source block.
- Destination EVM RPC: validator registry `setId()`, `verifierKeyFormat()`, Mailbox `delivered(messageId)` and permissionless `process()`.
- XGR RPC: `xgr_getILNInterchainAttestation(routeName,messageId)` returns completed `XGR_ILN_CHECKPOINT_V2` aggregate signer bitmap, signature, canonical checkpoint fields and root.

## Independent one-shot recovery client

`runtime/native-relayer/recover-iln.mjs` is an **unprivileged unsigned transaction builder**. It imports only public local JavaScript Merkle and ABI helpers. It does **not** read or write the continuous relayer's JSON state, hold a validator key or require `RELAYER_PRIVATE_KEY`.

Use an independently configured environment containing:

```text
ORIGIN_RPC_URL, ORIGIN_CHAIN_ID, ORIGIN_DOMAIN,
ORIGIN_MAILBOX, ORIGIN_MERKLE_TREE_HOOK, ORIGIN_ILN_REGISTRY,
ORIGIN_ILN_GATEWAY, ORIGIN_WARP_ROUTER, ORIGIN_CONFIRMATIONS,
ROUTE_ID, ATTESTATION_RPC_URL, ATTESTATION_ROUTE,
DESTINATION_RPC_URL, DESTINATION_CHAIN_ID, DESTINATION_DOMAIN,
DESTINATION_MAILBOX, DESTINATION_WARP_ROUTER,
DESTINATION_ILN_ISM
```

The optional `DESTINATION_AGGREGATION_*` fields are only needed if the destination router's security configuration requires the ILN ISM inside an aggregation ISM.

```bash
cd runtime/native-relayer
npm install --no-audit --no-fund
# Load the public route environment into the shell without exposing secrets:
node recover-iln.mjs 0x<64-hex-message-id>
```

The output is either:
- `ALREADY_DELIVERED`;
- `FRESH_QUORUM_REQUIRED` (after validator-set rotation, do NOT send the old attestation or repeat the asset transfer);
- `READY_UNSIGNED_CALL`, containing `to`, `value`, `data` for signing and sending with **any user's own wallet**, after successful destination `Mailbox.process.staticCall`;
- `RECOVERY_NOT_READY` for missing data or failed verification.

The client checks source transaction correspondence, operation fee, historical route binding, canonical checkpoint payload, Merkle inclusion, current destination set ID, and destination Mailbox simulation before outputting unsigned transaction calldata. A historical state RPC is efficient; reconstructing the Merkle tree from publicly indexed events remains an option if it is unavailable.

## Critical remaining gap — generic public quorum acquisition (same path for first transfer and recovery)

The existing XGR RPC is **read-only**; it does not request or generate signatures. The existing node refreshes persisted **local pending votes**, but a **completed, archived** attestation can remain stale after the destination's `setId` advances. There is currently no fully implemented permissionless RPC mechanism to **request** refreshed attestation for any arbitrary completed, undelivered fee-qualified message.

Consequently this feature is **not yet a complete recovery guarantee**. Implement **one idempotent, public, generic quorum request/get API** for first-time delivery **and** any undelivered message after validator rotation. There must be **no special privileged recovery RPC**. The normative interface, statuses and admission rules are in [ILN spec, Sections 11.1-11.6](ILN.md#111-v313-north-star-permissionless-rpc-first-quorum-lifecycle-normative). The generic XGR node process must:

1. Verify the original canonical Gateway event, source route and Merkle root at sufficiently confirmed source state.
2. Read the destination current validator-set ID **and** confirm `Mailbox.delivered(messageId) == false` before enqueue and again before signing. A destination RPC failure must fail closed; no signing on unknown delivery state.
3. Treat request as a **hint only**, never an authorization to sign. Validator nodes independently evaluate all eligibility conditions and only sign canonical data.
4. Gossip/rebroadcast and collect a fresh destination quorum using current eligible validator keys.
5. Publish the new current-set attestation by canonical route/message/set identity, preserving message ID, original source transaction/block, route ID and fee; retired attestation may remain as historical audit material. Never create another lock/burn, dispatch or validator fee.
6. Work after node restart and independently of the XGR-operated relayer process, including already finalized old-set attestations. No bulk regeneration on a set change; delivered historical operations must never be re-signed. Use persistent idempotency, cheap negative filtering, bounded log-index lookups, queues, limits and per-peer backoff to prevent RPC/P2P DoS.
7. Add tests for first-time and rotated-set requests via the **same API**, delivered-history mass spam, unknown destination status, random message IDs, duplicate/concurrent requests, set rotation during signing, source-chain reorg, restart persistence and independent destination Mailbox delivery.

A distinct XGR validator node or any participant should be able to serve the public RPC route; no centrally maintained watchlist must be mandatory.

## Release gate

Do **not** mark v3.1.3 as permissionlessly recoverable or deploy solely on the unsigned recovery CLI: **generic permissionless quorum-request lifecycle, delivered-aware anti-spam/idempotency and independent E2E must pass first**. Existing production v3.1.1 relayers are unaffected.
