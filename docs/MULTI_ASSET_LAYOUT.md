# XGR ILN - generic contracts and per-token configuration

This v3.1.4-feature-branch reorganization is a repository change only.
It does not deploy contracts, alter token custody, enable routes, start
relayers, or modify xgr-node.

## Directory layout

~~~text
contracts/                                generic reusable Solidity
script/DeployV313.s.sol                   generic Foundry deployment
config/chains/
  xgrchain.json                           RPC, domain, chain ID, finality
  base.json
config/assets/XGR/
  asset.json                              canonical asset and representations
  routes.json                             planned ILN routes in both directions
  mainnet.json                            desired mainnet references
config/assets/<TOKEN>/
  asset.json
  routes.json
  mainnet.json
deployments/
  xgrchain-mainnet.json                   original mainnet inventory retained
  xgr-base-route.json                     original XGR/Base inventory retained
  mainnet/infrastructure/
    xgrchain.json                         observed shared-chain infrastructure
    base.json
  mainnet/assets/
    XGR.json                               observed token routers / transfer history
    <TOKEN>.json
runtime/                                   unchanged legacy relayer paths
tools/validate-manifests.mjs              read-only manifest validation
tools/validate-manifests.test.mjs         negative regression tests
~~~

## What is shared and what is per token?

Hyperlane Mailbox, MerkleTreeHook, BLS verifier, destination
ValidatorRegistryV2, source ILN Registry and generic ISM belong to the
shared chain infrastructure. Reuse them for all compatible token routes.

A new token adds its own chain representations / Warp router adapters,
source ILNGateway and FeeVault per route, plus source-chain governance.
The native asset and its representations must not be confused with a DEX
swap: multi-hop hub bridging remains separate user-authorized hops.

Desired chain or route configuration is NOT a blockchain authority.
Actual code addresses, deployment hashes and tested custody state belong
only in deployments/mainnet/... after independent chain verification.
Current v3.1.1 XGR/Base router addresses and E2E evidence are carried over
solely as observed LEGACY state. New v3.1.4 gateway, vault, route ID and
governance transaction fields are deliberately null / unverified.
A ROUTE_ADD source-chain 2/3 quorum activates a new route immediately.
Do not propose it before the destination ISM/router, finality, gas and
validator membership are ready.

## Add a chain

1. Add config/chains/<CHAIN>.json with actual ID/domain, RPC, finality,
   native gas token, verifier format and reference to the observed inventory.
2. Add deployments/mainnet/infrastructure/<CHAIN>.json and verify every
   recorded address. Unknown contracts stay null and are not implicitly
   deployed by adding the file.
3. Configure participating validators for the chain and verify BLS,
   destination ISM, RPC histories and token settlement before route addition.

## Add an asset

1. Create config/assets/<TOKEN>/asset.json, routes.json and mainnet.json,
   declaring exactly one canonical asset and any chain representations.
   Declare separate source/destination routes for the return trip.
2. Create deployments/mainnet/assets/<TOKEN>.json with only observed
   code, addresses, transaction hashes and source evidence.
3. Deploy or reuse asset-specific Warp routers / adapters and gateways.
   Reuse shared chain contracts rather than copying Solidity per token.
4. Verify native and ERC20 quote/allowance behaviour, conservation of
   supply, destination settlement, relay-independent recovery and
   source-chain fee claims.
5. Complete source-chain validator approvals and execute ROUTE_ADD only
   after all components are operational.

Do not add invented live XDC, Polygon or other deployment addresses.
Create their configs when their real topology and finality policy are known.

## Offline checks

~~~bash
node tools/validate-manifests.mjs
node --test tools/validate-manifests.test.mjs
forge build
forge test -vvv
~~~

The manifest checks do not use private keys, deploy contracts, access RPCs,
or change production state. They detect legacy-address drift, mismatched
chain IDs/domains, invalid route endpoints and fictitious ILN activation.

The planned idempotent xgr-interchain deploy-asset command is NOT implemented
by this repository organization patch. Existing generic Foundry deployment
and manual source-chain quorum governance remain the supported workflows.
