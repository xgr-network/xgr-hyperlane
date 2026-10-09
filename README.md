# XETA — XGR EVM Token Alliance
XETA ILN v3.1.4 is an open, quorum-governed interchain token protocol. This source branch is **pre-deployment**, not evidence of active XETA routes.

XGRChain (chain ID/domain 1643) is the central hub. Base, Polygon and Arbitrum are configured as planned spokes. Transfers between two external networks always route through XGRChain in two independent steps.

## Contracts and deployment
- `contracts/XETARouterCore.sol` is the shared, gateway-only, multi-spoke Hyperlane 11.1.0 TokenRouter.
- `contracts/XETAGuardedNativeWarpRouter.sol` handles native XGR custody on the hub.
- `contracts/XETAGuardedSyntheticWarpRouter.sol` handles synthetic wXGR mint/burn on spoke chains.
- One router instance per asset per chain. Each directed route has its own ILNGateway and automatically created FeeVault. Governance remains with the current validator quorum.
- `XGRILNInterchainISMV2`, `XGRILNProtocol` and `XGRInterchainValidatorRegistryV2` are **current** V2 cryptographic/wire interfaces; those names are not legacy bridges.
- `script/DeployXETA.s.sol` and `script/DeployXETARouters.s.sol` provide deployment helpers; neither can approve routes.

## Token and chain manifests
`config/chains/` lists supported/planned networks. `config/assets/XGR/{asset,routes,mainnet}.json` defines native XGR, planned wXGR representations and six directed hub-only routes. `deployments/mainnet/` contains verified observations; null values must remain null until deployment and governance are confirmed.

## XETA web platform
The standalone UI is intended for `xeta.xgr.network` and belongs with the protocol in the future `xgr-interchain` repository; `XGR_Web` remains the umbrella website. Overview, Markets, /bridge, /join and /token/:id are planned. **Every token profile must contain the same working Bridge component as /bridge**, not merely a hyperlink. See `docs/XETA_UI_ARCHITECTURE.md`.

## Economic guarantees
Alliance applications and standard integration are free. Token and route approval requires quorum. Source-native validator fees remain positive; offchain promotional refunds are optional. Future XGRChain hop sponsorship is not yet deployed. Inactive routes must remain accessible for redeem and recovery.

## Validate
```sh
forge build && forge test -vvv
node tools/validate-manifests.mjs
node --test tools/validate-manifests.test.mjs
node tools/check-xeta-clean.mjs
bash -n runtime/manage-relayers.sh
cd runtime/native-relayer && npm test
```

## Production boundary
The prior v3.1.1 bridge and its original synthetic supply remain separately accountable. This source cleanup neither deletes on-chain contracts nor shuts down servers. Any migration must preserve historical user balances and permissionless recovery. Do not deploy or advertise new routes until real cross-chain custody, validator signatures, ISM/EIP-2537 compatibility and relayer-outage recovery pass.
