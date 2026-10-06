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

The Base-only ILN MVP adds an application-specific security layer on top of
the existing Warp routers.

New contracts:

- `IILNRouteRegistry`
- `ILNRouteRegistry`
- `ILNGateway`
- `XGRILNInterchainISMV2`

### ILNRouteRegistry

Stores the canonical route tuple consumed by xgr-node v3.1.2.

The registry is bound to exactly one destination-domain validator-set
contract. Route mutation has no owner/admin path. It accepts only the
canonical `XGR_ILN_GOVERNANCE_V1` payload with an unweighted two-thirds
BLS quorum.

### ILNGateway

The Gateway is the fee-qualified source entry point.

It does not replace the Warp router as Hyperlane sender. It:

1. reads the canonical route;
2. enforces the configured positive validator fee;
3. invokes the existing Warp router;
4. receives the real Hyperlane `messageId`;
5. emits `ILNOperation(messageId,destinationDomain,validatorFeeWei)`;
6. retains only the validator-fe portion for later signer settlement.

The implementation supports the two Base-MVP asset modes:

- Base synthetic wXGR router;
- XGRChain native XGR router.

Native quote-principal semantics are explicit constructor configuration and
are never guessed at runtime.

### XGRILNInterchainISMV2

The destination ILN ISM verifies `XGR_ILN_CHECKPOINT_V1`.

Authorization is message-specific. Verification requires:

- exact origin and destination domains;
- exact source Warp router as Hyperlane sender;
- exact destination Warp router as recipient;
- `keccak256(message) == authorizedMessageId`;
- Merkle inclusion of that message in the signed root;
- exact source route context;
- exact source operation block and validator fee;
- historical validator-set lookup by `setId`;
- unweighted two-thirds BLS quorum.

A signed checkpoint root without the matching authorized message ID is not
sufficient.

### Fee settlement

The source Gateway accepts settlement from any caller after a valid completed
attestation exists.

The accepted signer bitmap determines the validators credited for the
operation. Balances are claim-based and do not require custody by a specific
relayer.

### Deployment

The Base-MVP deployment scripts are in:

`script/DeployILNBaseSpoke.s.sol`

They deploy contracts only. They deliberately do not:

- execute ILN ROUTE_ADD;
- alter the Base wXGR router ISM;
- alter XGRChain DomainRoutingISM;
- start relayers.

The controlled activation sequence is documented in
`docs/ILN_BASE_MVP.md`.
