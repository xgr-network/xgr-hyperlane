# XETA — XGR Interchain Liquidity Network (ILN) v3.1.4

**Status:** XETA v3.1.4 contracts and multi-asset manifests are in development. NOT deployed or activated by this branch. Do not confuse historical v3.1.1 mainnet bridge evidence with active v3.1.4 routes.

## Architecture
XGRChain (chain ID/domain 1643) is the permanent, validator-secured routing hub. Each external chain (Base 8453, planned Polygon 137, Arbitrum One 42161) connects to XGRChain independently; external-to-external bridging is always two hops via XGRChain. No direct third-party EVM-to-EVM public routes.

Each direction uses an authorized ILNGateway, source FeeVault, source ILNRegistry, a version-pinned guarded Hyperlane Warp router, Mailbox/MerkleTreeHook and a destination generic ILN ISM backed by the chain's destination ValidatorRegistryV2. Quorum = current destination-specific XGR Interchain validator set 2/3, secured by BLS, separate from XGRChain consensus.

**xgr-node v3.1.4 is frozen for this Solidity/application work.** Source chain EVM fees are regular source-native fees, even when XETA offers separate offchain UI refunds. An XGR second-hop sponsor/forwarder is a future feature, not active; two-hop transfers are not currently XGR-wallet-free.

## Current code
- contracts/: generic v3.1.4 XETA Gateway, local FeeVault, RegistryV2, ILN Registry, BLS verifier and route/message-specific destination ISM.
- contracts/XETARouterCore.sol: shared guarded Hyperlane 11.1.0 TokenRouter supporting several quorum-controlled destinations; native and synthetic adapters implement only asset custody.
- script/DeployXETARouters.s.sol: deploy shared native/synthetic asset-router instances independently of route-specific gateways.
- config/chains/: chain identities and finality; config/assets/: desired canonical asset representations/routes.
- deployments/mainnet/: observed infrastructure/asset evidence, kept separately from planned contracts. Old v3.1.1 addresses are archival only and do NOT imply ILN v3.1.4 deployment.
- runtime/native-relayer/: current ILN message relay, quorum and recovery. Existing forward/reverse legacy service control files remain until old bridge shutdown is operationally verified.
- script/DeployXETA.s.sol: generic deployment entrypoint, but deploys ILN Registry, Gateway, ValidatorRegistryV2, EIP2537 verifier and generic destination ILN ISM. It does NOT activate governance routes.
- docs/XETA_SPEC_V314.md: accepted source of truth for architecture, fees, sponsored refunds, permanent routes and security.
- docs/XETA_ONBOARDING.md: free partner applications via PR or form.
- docs/REPOSITORY_LAYOUT.md: current XETA-only project map.\n\n## Non-negotiable protections
1. New Warp router transferRemote MUST reject direct caller and accept only the canonical ILNGateway; incoming Mailbox handle() must still work. Shared upstream-compatible guarded routers are implemented and covered by unit/integration tests; live fork/mainnet E2E remains a deployment gate.
2. Users may always redeem wrapped tokens despite website delisting from featured/top lists. Inactivity MUST NEVER turn a working on-chain route off. Emergency pause requires quorum-controlled safety operation and recovery policy.
3. Normal on-chain positive validator fees are collected in source-native currency and claimable via FeeVault; optional subsidy is an offchain, verified, budget-limited refund, not a new privileged contract.
4. All routes are approved using 2/3 current registry BLS quorum, never by a GmbH-owned admin key.
5. New integrations must check token behavior, real mainnet EIP-2537, supply invariants, no-loss recovery, replay and gas profile.

## Validation
    forge build
    forge test -vvv
    node tools/validate-manifests.mjs
    node --test tools/validate-manifests.test.mjs
    cd runtime/native-relayer && npm test

Passing mocked Foundry unit tests is not equal to a successful live cross-chain transfer. Mainnet route state must be verified on-chain before being advertised as active.

## XETA-only branch boundary\nOld v3.1.1/V1 source files, relayers and on-chain router addresses are not part of this branch. Existing chain history remains verifiable externally. Production migrations require an independent on-chain handover checklist; do not delete running services by merely checking out this branch.\n