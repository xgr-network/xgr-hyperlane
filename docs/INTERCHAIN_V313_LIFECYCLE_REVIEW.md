# XGR Interchain v3.1.3 — lifecycle / north-star review

Date: 2026-10-08. Scope: current `xgr-node` XGR3.0 and `xgr-hyperlane` feature/interchain-v3.1.3. Method: source/ABI/state-machine review; **not** a completed mainnet E2E execution or independent audit.

## Requirements and scenarios

| Scenario | Intended behavior | Source review / current status |
| --- | --- | --- |
| 1. Chain onboarding | Deploy chain-shared verifier, destination ValidatorRegistryV2, source ILNRegistry, destination generic ISM once | Supported by Foundry deployment scripts. Base precompiles and real genesis PoPs require verification. |
| 2. Existing validator joins Base | CLI set-active --chain base --active true; candidate signs with PoS BLS key; current Base membership quorum authorizes ADD; executor funds native Base reserve | Implemented in Go membership worker and RegistryV2. Joining Base grants Base-bound checkpoint signing, not Base-origin signing to XGR. Needs actual on-chain lifecycle test. |
| 3. Same validator joins XGR | Separate destination-specific registry entry / reserve / quorum on XGR | Supported, already independent registry; no automatic membership propagation. |
| 4. Validator leaves Base but stays XGR | Removes Base-bound signing authority only; remains eligible for Base->XGR via XGR destination registry | Correct destination-scoped behavior. Removal uses current registry quorum; remaining reserve credited through claim(). |
| 5. Forced removal / PoS exit | Remaining current destination validators sign forced removal; registry set advances; no single unilateral removal | Implemented. **Availability limitation:** cannot complete with fewer than current set's threshold active/cooperative signers. Last-validator removal is prohibited. |
| 6. Validator rotation during unfinished transfer | Node refreshes pending checkpoint against new destination set; historical set remains valid for already completed attestations | Code paths exist. End-to-end delayed-delivery and set-rotation tests missing. Distinguish membership revocation from completed old attestations. |
| 7. Route onboarding | Deploy source gateway and asset router; governance with source-chain registry current quorum executes ROUTE_ADD | Implemented. ROUTE_ADD immediately enables route, so operational preflight is required before submission. |
| 8. Update fee / disable and re-enable | One independent nonce per (destinationDomain, routeId); current **source** membership quorum authorizes change | Supported. **Fixed 2026-10-08:** source ILNRegistry now requires current governanceRegistry.setId() rather than accepting old historical quorum for mutable route changes. |
| 9. User XGR -> Base wXGR | Native principal + Hyperlane gas + native source-chain validator fee; XGR Warp lock, Base Warp mint after quorum verification | Gateway models native quote, guarded against double principal through deployment boolean. Needs test with real existing XGR Warp quote, gas, route gates, ISM. |
| 10. User Base wXGR -> XGR | ERC20 transferFrom user to Gateway, then Warp token burn and XGR unlock | Gateway model and mock tests exist. Needs test with deployed wXGR router's exact transferRemote semantics and allowances. |
| 11. Other token A -> XGR -> chain B | Two independent one-hop burn/mint or lock/mint transfers | Generic protocol supports separate routes. **Automatic intermediate hop execution/recipient forwarding not implemented**; requires an orchestrator/UX design and recovery of stranded intermediate balances. No DEX swap is implied. |
| 12. User calls Warp router directly | Message can dispatch but is not fee-qualified; validators reject missing canonical ILNOperation | Source-chain validator checks Gateway log and canonical route. Target ISM cryptographically checks signed authorizedMessageId; direct router transfers can therefore lock/burn assets without delivery under new ILN. User UI and router access protection require explicit operational policy. |
| 13. Relayer offline after source lock/burn | Message remains in source and can be recovered by any independent relayer with valid quorum/metadata | Trust separation works by design; exact recovery from persisted Merkle and relayer indexes still needs E2E test. |
| 14. Replay/duplicate delivery | Mailbox message delivery protection rejects duplicate processes | Hyperlane Mailbox handles delivered(messageId); requires E2E. |
| 15. Fee collection + validator claims | Validators earn source native fee and claim accrued payouts | **NOT IMPLEMENTED.** Gateway tracks totalValidatorFeesEscrowedWei but has no validator allocation, settlement finality or claim function. |
| 16. Token representation and supply | Canonical locked collateral equals total synthetic supply over all connected chains (adjust for in-flight operations) | Correct design principle; no general multi-hop cross-chain supply invariant or router-level full E2E suite in this repo. |
| 17. Direct A->B routes | Protocol supports generic non-XGR source, but product deploy policy uses XGR as hub | Code is generic. No A->B commercial offering enabled. |
| 18. Fee update during pending messages | Fee for authorization must match route at historical source block | Go re-reads registry at operation block; relayer checks operation and attestation payload. Same-block update ordering and historical log availability require tests. |

## Production blockers / tests still required

### P0 — economic settlement

Implement a route-scoped validator-fee allocator and pull-claim mechanism with signer proof and replay protection; define when an escrowed fee can be credited, including for stuck messages. Do not allow an unrestricted owner withdrawal.

### P0 — direct-router user trap

Existing Warp routers remain directly callable. If they dispatch a Hyperlane message without the canonical fee-qualified Gateway, the v3.1.3 destination security path will refuse it. This can leave user principal locked or burned with no automatic release. Before cutover require wallet/UI gating and an explicit strategy for direct calls (router-level access control, reviewed recovery/refund logic, or enforceable constraints); never advertise a direct router path as safe.

### P0 — end-to-end transport + custody invariants

Run native/erc20 realistic router ABI tests with live deployed router versions, fee quote behavior, Base EIP-2537 precompile compatibility, Hyperlane hook and ISM configuration, all valid/invalid message paths and supply invariants.

### P1 — hub routing orchestrator

Two bridges are currently two separate user steps. An automated XGR hub forwarder with end-to-end intent binding (asset, amount, recipient, destination), deduplication, fee funding and timeout/recovery is separate scope. Do not claim mint-burn-mint automation exists.

### P1 — validator lifecycle matrix

Run realistic multi-destination join / leave / forced removal / PoS key mismatch / set rotation tests, especially pending transfer after validator removal and insufficient-signers stalls. Destination-set membership is independent per chain.

### P1 — governance and deployment safety

Route ADD immediately enables. Maintain fail-closed deployment policy; verify source-chain current governance set, route nonces, expiry and chain/domain. Existing active v3.1.1 router configuration stays unchanged until explicit cutover.

## Verification status

Source code reviewed and targeted governance guard/test committed on feature branch. **No tests have been executed in this review environment** (Forge/Solc not installed here and GitHub clone unavailable). Earlier green suite (65 tests) predates these commits. Do not deploy or migrate on this review alone.
