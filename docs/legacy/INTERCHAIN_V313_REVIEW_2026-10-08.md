# XGR Interchain v3.1.3 — Contract and Relayer Review (2026-10-08)

Scope: `contracts/*.sol` and `runtime/native-relayer/iln.mjs` in `feature/interchain-v3.1.3`. This is a static code review and compatibility patch, **not** an independent formal security audit. Do not interpret passing Foundry tests as production readiness.

## Changes completed in this review

- ILN relayer consumes the actual four-field, route-indexed `ILNOperation` event.
- ILN relayer enforces configured nonzero `ROUTE_ID` when indexing Gateway operations and when validating node attestations.
- Uses the canonical `XGR_ILN_CHECKPOINT_V2` packed payload, including the route ID.
- Builds the full 20-field `XGRILNInterchainISMV2.verify()` metadata tuple rather than v3.1.2 metadata.
- Keeps legacy aggregation wrapping optional for installations that explicitly require it.
- Segregates v3.1.3 route state from v3.1.2 state; old persisted checkpoints are **not** automatically migrated.
- Updates runtime examples and supplies codec regression tests.

## Reviewed security boundaries

| Component | Review focus | Finding |
| --- | --- | --- |
| `XGRILNProtocol.sol` | canonical route/checkpoint/governance encoding, domain separation | V2 fields defined consistently with the current Go node; retain cross-language vectors as release gate |
| `XGRILNRegistry.sol` | local destination registry governance authority, route nonces, quorum | signer quorum verified via immutable local registry; `ROUTE_ADD` immediately enables a route; operational gate required |
| `XGRInterchainValidatorRegistryV2.sol` | bootstrap PoP, historical set commitments, quorum, removal reserves | maintains historical snapshots and uses checks-effects-interactions in claim path; destination-scoped PoP must match origin=1643, destination domain |
| `XGRILNInterchainISMV2.sol` | message sender/recipient, source/destination, Merkle proof, authorized message ID | binds message to signed V2 checkpoint and destination registry quorum |
| `XGRInterchainBLSVerifier.sol` | EIP-2537 precompiles, public key/signature sizes, aggregation | requires on-chain EIP-2537 precompile verification before Base deployment; unit-test mocks alone insufficient |
| `ILNGateway.sol` | canonical route, fee qualification, router calls and reentrancy | fee is escrowed, nonReentrant bridge guard present; **no validator-fee payout/claim implementation** |
| Historical `XGRNativeInterchainISM*.sol`, `XGRILNInterchainISM.sol`, `XGRInterchainValidatorRegistry.sol` | legacy authority boundaries | do not reuse in fresh v3.1.3 security path; preserve existing v3.1.1 operation until cutover |

## Must resolve before mainnet v3.1.3 route activation

1. **Validator fee settlement is not implemented.** `ILNGateway.totalValidatorFeesEscrowedWei` accumulates funds but exposes neither a claim mechanism nor a quorum-based distribution ledger. A standalone admin-withdraw would violate the intended validator-payment model. Specify and implement an independently verifiable route-scoped fee allocation and pull-claim contract before paid operation.
2. **Live destination verification is pending.** Prove Base's EIP-2537 verifier on Base mainnet, not only in Foundry's Prague EVM.
3. **Per-route integration test is pending.** Test both XGR→Base and Base→XGR with real historical source state, exact route-specific fee, true BLS quorum, real message Merkle proofs, and relay replacement/replay behavior.
4. **Legacy Router cutover remains a separate release gate.** Verify owner authority, immutable bindings and ISM linkage, then perform migration only at an explicitly coordinated time.
5. **Bootstrap funding gate.** 3 validators × 1 XGR requires **3 XGR plus gas** on XGR; the observed deployment wallet balance was 2.635389999993638382 XGR on 2026-10-08, insufficient.
6. **Route policies.** Generic direct external-chain A→B routing is supported at the protocol layer; the initial product must only advertise/enable routes through the XGR hub. Manifest and operator policy must enforce that narrower deployment scope; the security layer need not hard-code a hub.

## Reproducible local checks (isolated v3.1.3 worktree)

```bash
cd ~/repos/xgr-hyperlane-v313
git fetch origin refs/heads/feature/interchain-v3.1.3:refs/remotes/origin/feature/interchain-v3.1.3
git status --short
# Review new commits; do not alter the live v3.1.1 checkout.
forge build
forge test -vvv
cd runtime/native-relayer
npm install --no-audit --no-fund
npm test
node --check iln.mjs
```

All deployments and route activations remain manual, disabled by default, and subject to the unresolved gates above.
