# XGR native Interchain contracts

This directory contains destination-side trust contracts for XGR-native Interchain security.

## Security model

Both deployed contract generations are secured by XGR validator BLS quorum attestations.

The standard Hyperlane validator / ECDSA multisig path is not the trust anchor for XGR-native routes.

The relayer is untrusted and has no validator signing authority.

## Contract generations

### V1

Components:

- `XGRInterchainBLSVerifier`
- `XGRInterchainValidatorRegistry`
- `XGRNativeInterchainISM`

The current XGR → Base deployment uses V1 on Base.

V1 verifies checkpoints against the current destination validator set and uses EIP-2537-formatted verification keys/signatures on the current Base deployment.

### V2

Components:

- `XGRInterchainValidatorRegistryV2`
- `XGRNativeInterchainISMV2`

The current Base → XGR deployment uses V2 on XGRChain.

V2 adds:

- immutable historical verification-set snapshots by `setId`,
- verification of checkpoints against the set that actually signed them,
- configurable compressed or EIP-2537 verification-key format,
- separation between membership-origin chain identity and checkpoint-origin chain identity.

V1 and V2 are **contract generations**, not synonyms for forward and reverse directions. V2 can be used for any compatible destination. Both generations use XGR-native BLS validator security.

## Destination-scoped membership

Membership belongs to a destination registry.

Multiple independently configured checkpoint routes may share one destination registry.

For example, a future set of routes:

    base_to_xgr
    polygon_to_xgr
    arbitrum_to_xgr

can all use the same XGRChain destination RegistryV2 membership while keeping independent source checkpoints.

## Membership authority

After bootstrap there is no administrator membership override.

ADD and REMOVE transitions require the current unweighted two-thirds XGR Interchain BLS quorum.

The XGR node also binds Interchain participation to canonical XGR PoS/BLS identity checks.

## Reserve model

An ADD transition is payable. The attached value becomes the validator's deactivation reserve.

A REMOVE transition is non-payable. The removed validator's reserve funds bounded executor reimbursement; the remaining balance is credited back to the validator. Credits are withdrawn through `claim()`.

## Forward deployment order

1. deploy the BLS verifier;
2. collect bootstrap possession proofs;
3. deploy the destination registry;
4. deploy the native ISM against that registry and canonical origin Mailbox/MerkleTreeHook;
5. configure the destination recipient/router to use the ISM;
6. validate a bounded end-to-end transfer.

Do not deploy a verifier format on a destination until the required BLS execution support has been verified.


## ILN v3.1.2 Base MVP

The Base-only ILN MVP reuses the already deployed XGR Interchain validator
security and adds only message-specific ILN authorization.

New contracts:

- `ILNGateway`
- `XGRILNInterchainISM`
- `XGRILNInterchainISMV2`

### ILNGateway

The Gateway is the fee-qualified source entry point and, for the Base MVP,
also the immutable canonical route registry.

`ilnRegistry()` returns the Gateway itself and `getRoute(uint32)` exposes
one constructor-fixed route. There is no owner, route admin, mutable fee,
validator-set mirror, or dynamic route-governance contract.

The Gateway:

1. enforces the configured positive validator fee;
2. invokes the existing Warp router;
3. receives the real Hyperlane `messageId`;
4. emits `ILNOperation(messageId,destinationDomain,validatorFeeWei)`.

The existing Warp router remains the Hyperlane sender.

The implementation supports:

- Base synthetic wXGR as source;
- XGRChain native XGR as source.

Synthetic Warp token-fe shapes outside the supported no-extra-fee Base MVP
are rejected fail-closed. Native quote-principal semantics are explicit
constructor configuration and are never guessed at runtime.

### Destination ISMs

`XGRILNInterchainISM` is the message-specific Base destination verifier.
It deliberately reuses the existing Base V1 validator registry and EIP-2537
BLS verifier.

`XGRILNInterchainISMV2` is the message-specific XGRChain destination
verifier. It reuses the existing XGRChain RegistryV2 and native compressed
BLS verifier.

Both verify `XGR_ILN_CHECKPOINT_V1` and require:

- exact origin and destination domains;
- exact source Warp router as Hyperlane sender;
- exact destination Warp router as recipient;
- `keccak256(message) == authorizedMessageId`;
- Merkle inclusion in the signed root;
- exact source route context and source block;
- positive validator fee;
- unweighted two-thirds XGR Interchain BLS quorum.

A signed checkpoint root without the matching authorized message ID is not
sufficient.

### Launch fee

xgr-node v3.1.2 requires a strictly positive validator fee. The Base MVP
therefore uses a nominal value such as 1 wei.

Signer-based fee distribution is intentionally deferred while the fee is
economically negligible. It must be added and reviewed before introducing a
material validator fee.

### Deployment

The Base-MVP deployment scripts are in:

`script/DeployILNBaseSpoke.s.sol`

They deploy contracts only. They deliberately do not:

- alter the existing validator registries;
- alter the Base wXGR router ISM;
- alter XGRChain DomainRoutingISM;
- start ILN relayers.

The controlled activation sequence is documented in
`docs/ILN_BASE_MVP.md`.
