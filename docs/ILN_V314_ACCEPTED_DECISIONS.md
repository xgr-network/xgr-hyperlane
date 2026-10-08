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

## Governance CLI (feature/interchain-v3.1.4)

The chain-local registry does not have a GmbH-controlled governance authority. Validators approve proposals explicitly and the source-chain registry enforces the current local validator set quorum.

```bash
xgrchain ibft interchain proposal create --data-dir ./data --source xgr --destination base --type fee-update --route-id 0xROUTE_ID --fee-wei 1000000000000000
xgrchain ibft interchain proposal show --data-dir ./data --proposal-id 0xPROPOSAL_ID
xgrchain ibft interchain proposal approve --data-dir ./data --proposal-id 0xPROPOSAL_ID
xgrchain ibft interchain proposal execute --data-dir ./data --proposal-id 0xPROPOSAL_ID
```

The execute operation uses the local validator node's ECDSA transaction key only as a gas-paying sender. Any independent account can submit equivalent signed calldata. It reads the persisted original proposal and quorum, verifies hash, signature, source-chain setId, next route nonce, expiration, gas coverage, receipt and confirmed post-state. Proposal create does **not** auto-approve. Multi-validator approval is always explicit from each validator's own node. Fees are **source-native**. Set realistic TTL and make sure source gas is funded before approving.

The CLI must not be used on production before the new EVM ABI encoding, live EIP-2537 compatibility, route additions and disabling/reenabling have passed an isolated network end-to-end test. This description documents the feature-branch implementation, not a production release approval.
