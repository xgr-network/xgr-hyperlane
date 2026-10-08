# XGR ILN v3.1.4 – accepted decisions (2026-10-08)

This supersedes older v3.1.4 plan statements on validator fee beneficiaries and mandatory router gating.

## Accepted native source fee model

- At original `ILNGateway.bridge()`, source-native fees are allocated exactly once to **all active validators in the canonical local source-chain RegistryV2**; equal shares with rotating wei remainder.
- Allocation is deliberately **not linked to the destination BLS signing bitmap**. Non-signers within the active source registry still receive a share. This is the explicitly agreed simple model.
- `claim()` stays permissionless even after validator removal. Relayers cannot nominate beneficiaries. No owner-only or GmbH-only withdrawals.
- Rotation/recovery never starts another asset operation or credits a second source fee.

## Direct Warp calls

- Only canonical `ILNGateway.bridge()` operations qualify for ILN signing.
- Direct Warp-router calls may lock/burn without ILN approval; this is an explicitly accepted user risk, not a reason to waive validator checks.
- Optional cheap, backward-compatible gating may be added for NEW routers after proof of compatibility. Do not modify legacy v3.1.1 routers or introduce unsafe migrations merely to remove the risk.

## Remaining gates

Durable multi-chain route discovery and restart recovery; bounded public quorum request/retrieval; same-message post-rotation recovery; historical transfers after route disable; full governance CLI; real Base↔XGR native/ERC20/EIP-2537 integration; external relayer outage and validator join/leave tests; safely adding new tokens and chains. Maintain production untouched until tested release.
