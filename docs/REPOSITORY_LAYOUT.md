# XETA v3.1.4 repository layout

contracts/ and test/: active ILN v3.1.4 contracts, security mixin, unit tests.
script/DeployXETA.s.sol: generic chain infrastructure/Gateway deployments; governance route ADD remains separate.
config/chains/: chain settings, planned Polygon and Arbitrum pending independent validation.
config/assets/XGR/: canonical native XGR, new wXGR on Base/Polygon/Arbitrum, six directed XGR-hub routes.
deployments/mainnet/: observed mainnet Hyperlane cores and explicit NULL values for undeployed XETA security contracts and routes.
runtime/native-relayer/: ILN v3.1.4 relayer, codec, independently constructible recovery calldata. No V1 service scripts.
docs/XETA_SPEC_V314.md and docs/XETA_ONBOARDING.md: binding product policy.

Historical V1 contracts, old bridge addresses/relayers and archived documents have been removed from this branch. On-chain history is not deleted or altered. Do not run this clean branch's runtime manager as a substitute for stopping any existing legacy services on the live server.
Shared guarded native and synthetic Warp routers now compile against Hyperlane 11.1.0. Live source/destination E2E and full custody checks remain mandatory before route activation.

The actual multi-spoke design and bootstrap rules are specified in docs/XETA_ROUTER_ARCHITECTURE.md.
