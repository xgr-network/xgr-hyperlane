# XGR Interchain v3.1.4 — implementation and release gates

Status: implementation in progress; NOT deployed or release-tested.
Baseline: immutable xgr-node tag/release v3.1.3 (2026-10-07).
Branches:
- xgr-node: feature/interchain-v3.1.4 (from XGR3.0 / v3.1.3)
- xgr-hyperlane: feature/interchain-v3.1.4 (from feature/interchain-v3.1.3)

## Normative architecture

A bridge operation is initiated exactly once on the source chain. Any client (including optional relayers) can request a fresh BLS authorization over public XGR RPC. The current destination validator set independently verifies canonical fee-paid source evidence and destination Mailbox.delivered(messageId)==false before signing. The current-set quorum is public, and any gas-paying executor can call destination Mailbox.process(metadata,message). Rotation never re-executes the source lock/burn and never grants validity to retired quorums.

Full normative requirements: docs/ILN.md Sections 11.1-11.6.

## Work packages

1. **P0 destination-state signing guard**: fail closed on unavailable or already delivered destination Mailbox state in scan and peer-vote verification. Code started in xgr-node feature branch. Add unit tests with deterministic RPC mocks and integration tests with live EVM contracts.
2. **P0 generic quorum RPC**: public request and get methods, canonical identity (source chain/domain, destination domain, routeId, messageId, destination setId), persisted bounded dedupe, independently verified admission, source event index, validator gossip quorum aggregation, readable replica result, and no relayer dependencies. Initial and post-rotation requests use SAME state machine. Delivered messages NEVER cause new signatures; no mass auto-refresh of prior sets.
3. **P0 historical fee qualification**: operation fee must be checked against canonical event and intra-block historical state. End-of-block `getRoute` state may differ from state at execution if a fee or route is changed later in the same block; independently verify trace/log sequencing or use protocol-committed, unambiguous fee/route snapshot. Do not weaken checks to 'fee > 0' alone.
4. **P0 gateway bypass**: direct Warp Router dispatch without ILNGateway can burn/lock principal but lacks ILNOperation; enforce a safe router-level entry restriction in deployable compatible routers or an authenticated, replay-protected delivery/refund mechanism. No UI-only restriction is sufficient. A user must not be able to lock/burn funds with no protocol recovery path.
5. **P0 validator fee settlement**: custody stays in SOURCE-chain native asset; use per-route, per-operation fee escrow with exactly-once settlement and signer allocation. A historical validator earns for signing the authoritative **original** source operation, not by requiring current membership at withdrawal. Withdraw with pull-claim after exit, removal or key rotation. Avoid distributing micro-payments per hop. A stale-set re-attestation must not claim a second source fee. Decide immutable original earners (initial final verified quorum) before implementing payout to prevent two competing valid aggregate signer bitmaps claiming the same escrow.
6. **P0 no-loss E2E**: pending lock/burn and destination rotation, complete via new RPC without XGR relayer; source/destination replay, supplied fees, historical signer claims and route governance tests.
7. **P1 route discovery**: chain and route registry enumeration and cache invalidation; no per-token/chain patch or insecure configuration fallback; node still needs local authorized source/destination RPC endpoint selection.
8. **P1 router adapter/quotes**: verify native + ERC20 Warp Router ABI behaviors including native principal and Mailbox IGP quote; maintain explicit adapter settings only for real ABI differences.
9. **P1 chain compatibility**: parameterized confirmations/finality, 2537 versus native BLS verifier; prove real target chain precompile compatibility and account for RPC archival limitations.
10. **P1 hub orchestration**: optional independent-hop user experience, not part of chain consensus or validity.

## Fee-crediting threat model

Gateway's `totalValidatorFeesEscrowedWei` alone is not an allocation ledger. A signature bitmap on the DESTINATION chain cannot itself be trusted to credit a SOURCE-chain escrow unless the source chain verifies appropriate evidence. Unsafe designs:
- owner/executor reports signer list without cryptographic verification;
- any valid alternate quorum can redeem the same fee twice;
- a user can cause repeated payouts by asking for another current-set quorum;
- withdrawing is gated on active membership (would confiscate former signers' rewards);
- using a claim-time current-set bitmap to split a historical transfer.

Safe design goal:
- `operationKey = keccak256(domainSeparated(sourceChainId,sourceGateway,routeId,messageId))`;
- authoritative fee payer/currency and amount recorded at original operation;
- source-chain verifier accepts exactly one settlement proof/commitment per operation (explicit canonical signer bitmap, original validator-set snapshot, and independently verifiable BLS quorum);
- credit mapping keyed by validator payout address, independent of current membership;
- re-attestation to settle an already initiated message only updates delivery authorization on destination; it NEVER re-allocates fee;
- withdrawals use checks-effects-interactions, `nonReentrant`, and no admin-only source custody withdrawal.

A separate audited distribution contract or trusted-minimized source-chain verification of historical BLS signer membership is required. DO NOT implement a naive owner-supplied bitmap or claim-time membership lookup.

## Release acceptance

- Forge, Go, Node tests with live destination-state mock failures and set rotation.
- Delivered-history request flood: zero additional signatures; bounded RPC and P2P processing.
- Fully external RPC request -> get -> independently constructed metadata -> Mailbox.process.
- A->B pending transfer after rotation, no second source asset operation.
- Historical validator signs, leaves registry, successfully claims original native fee.
- Fee claim exact once regardless of quorum retries, delivery replays, removed validators, signer bitmap variations.
- Direct router user trap blocked on deployed routers or cryptographically recoverable.
- All parameterized chain and token route tests.
- Freeze v3.1.3 tags/releases; release v3.1.4 only after passing gates.
