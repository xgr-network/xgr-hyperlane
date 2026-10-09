# XETA v3.1.4 active Solidity contracts

ILNGateway.sol: source-chain fee-qualified canonical Bridge entry point.
XGRILNFeeVault.sol: source-native validator fee allocation, sparse wei payouts, pull-claims.
XGRILNRegistry.sol: quorum-governed route add/fee/update/enable/disable.
XGRInterchainValidatorRegistryV2.sol: membership, BLS keys, historical snapshots, lightweight fee-recipient getter.
XGRILNInterchainISMV2.sol: route-aware destination BLS verification and exact Message ID authorization.
XGRInterchainBLSVerifier.sol: EIP-2537 BLS verifier, conditional on actual chain compatibility.
XETAGatewayOnlyRouterGuard.sol: OUTBOUND guard mixin for new WarpRouter subclasses only. It is not a deployed router. No upstream Hyperlane code is vendored here; integration and E2E testing remain release blockers.

No V1/legacy implementations are active in this branch. See docs/XETA_SPEC_V314.md.
