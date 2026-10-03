# XGR Interchain Architecture

## 1. Scope

This document describes the architecture of the XGRChain ↔ Base Interchain integration.

The implementation combines:

- Hyperlane-compatible message transport,
- native XGRChain Interchain attestation generation,
- destination-specific XGR Interchain validator registries,
- BLS quorum verification,
- Merkle inclusion proofs,
- destination Interchain Security Modules,
- native relayers,
- Warp-style lock/mint and burn/unlock asset routing.

The first implemented asset route connects:

    XGRChain ↔ Base

with:

    XGRChain: native XGR
    Base:     synthetic XGR / wXGR

Both transfer directions have been validated end-to-end on mainnet.

This does not by itself mean that the route is permanently enabled for public user traffic.

---

## 2. Network identities

| Network | Chain ID | Hyperlane domain |
| --- | ---: | ---: |
| XGRChain Mainnet | `1643` | `1643` |
| Base | `8453` | `8453` |

Current public XGRChain node baseline:

    xgr-node v3.1.1

Release commit:

    1a4844b311fb856cb8c2303a40fa8aa69b560544

---

# Separation from XGRChain consensus

## 3. Native Interchain worker

XGRChain contains native Interchain functionality, but the Interchain worker is deliberately isolated from weighted-IBFT consensus-critical execution.

It must not control or block:

- block production,
- block verification,
- IBFT finalization,
- validator voting power,
- validator-set selection,
- staking epochs,
- normal chain synchronization.

Conceptually:

    XGRChain consensus
            │
            ├── EVM execution
            ├── IBFT finality
            ├── delegated PoS
            └── canonical state
                    │
                    │ observed by
                    ▼
            Interchain worker
                    │
                    └── attestations

A destination outage, relayer outage or external-chain failure must not stop XGRChain consensus.

---

## 4. Hyperlane remains the transport layer

Hyperlane-compatible infrastructure remains responsible for the message transport model.

The integration retains:

- Mailbox,
- Hyperlane message encoding,
- Dispatch semantics,
- Process semantics,
- MerkleTreeHook,
- destination `Mailbox.process()`.

XGR-specific security replaces the standard Hyperlane validator trust path for the native XGR security routes.

The standard Hyperlane validator / ValidatorAnnounce / ECDSA multisig checkpoint model is therefore not the trust anchor for XGR-origin native security.

`ValidatorAnnounce` may remain deployed for compatibility and historical infrastructure purposes.

---

# Validator and security model

## 5. Destination-specific Interchain validator sets

Interchain signing is destination-specific.

An XGR validator is a valid signer for a destination only when the configured native Interchain rules are satisfied.

The architecture binds Interchain membership to:

1. destination registry membership,
2. active XGR staking identity,
3. matching BLS identity.

Conceptually:

    XGR staking validator
            │
            ├── active staking identity
            └── BLS identity
                    │
                    ▼
        destination validator registry
                    │
                    ▼
           Interchain signer

Interchain validator membership does not grant additional IBFT authority.

Likewise, being an XGRChain consensus validator does not automatically make the validator an Interchain signer for every destination.

---

## 6. Interchain quorum

The native Interchain set uses an unweighted two-thirds quorum of the destination registry set.

This is intentionally different from XGRChain's stake- and uptime-weighted IBFT voting power.

Therefore:

    XGRChain consensus voting power
    ≠
    Interchain attestation voting weight

The two systems share validator identities and BLS infrastructure where configured, but they have separate quorum semantics.

---

# XGR-origin path

## 7. XGRChain → external destination

For an XGR-origin message:

1. a user or router dispatches through the XGR Hyperlane Mailbox,
2. the canonical XGR MerkleTreeHook inserts the message ID,
3. XGR nodes read the canonical hook state,
4. the destination-specific Interchain subset signs the checkpoint,
5. nodes aggregate the required BLS quorum,
6. the completed attestation becomes available through read-only XGR JSON-RPC,
7. an untrusted relayer reconstructs the Hyperlane message inclusion proof,
8. the relayer submits the message, proof and BLS metadata to the destination Mailbox,
9. the destination XGR-native ISM verifies the attestation and Merkle inclusion,
10. the destination Mailbox delivers the message.

Flow:

    XGR Mailbox
        │
        ▼
    XGR MerkleTreeHook
        │
        ▼
    canonical root
        │
        ▼
    XGR Interchain validators
        │
        ▼
    BLS quorum attestation
        │
        ▼
    read-only XGR RPC
        │
        ▼
    untrusted native relayer
        │
        ▼
    destination Mailbox
        │
        ▼
    XGRNativeInterchainISM
        │
        ▼
    recipient / router

The relayer can delay availability.

It cannot forge a valid XGR BLS quorum.

---

## 8. Native attestation RPC

Completed attestations are exposed through read-only XGR RPC.

Forward route:

    xgr_getInterchainAttestation("base")

Reverse route:

    xgr_getInterchainAttestation("base_to_xgr")

Specific archived checkpoint:

    xgr_getInterchainAttestationByCheckpoint(
        route,
        setId,
        index,
        root
    )

These RPC methods:

- expose completed attestations,
- do not request a signature,
- do not force validator participation,
- do not submit cross-chain messages.

The relayer consumes already completed quorum state.

---

# Destination trust stack

## 9. Native destination components

A destination-native XGR security stack consists conceptually of:

1. BLS verifier,
2. Interchain validator registry,
3. native XGR ISM.

The registry is the canonical membership state.

The ISM does not maintain an independent duplicate validator set.

---

## 10. Registry lifecycle

The registry contains the destination-specific Interchain validator set.

Membership changes advance:

    setId

The V2 design preserves historical validator sets.

This is important because an attestation created under set N must remain verifiable after the registry later advances to set N+1.

Therefore verification can distinguish:

    current membership

from:

    validator set that signed a historical checkpoint

without accepting unknown or fabricated historical sets.

---

## 11. BLS verification

The XGRChain node exposes native BLS12-381 verification through:

    0x0000000000000000000000000000000000002040

This is a native execution precompile.

It has no ordinary deployed EVM bytecode requirement.

The reverse XGR destination path uses compressed BLS aggregate signatures verified through this native precompile.

Other destination implementations can use the destination's supported BLS/EIP-2537 verification environment as appropriate.

---

# Forward route: XGRChain → Base

## 12. Forward security stack on Base

The currently deployed native XGR-origin stack on Base includes:

| Component | Address |
| --- | --- |
| `XGRInterchainBLSVerifier` | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| `XGRInterchainValidatorRegistry` | `0x70F5752326735b31641f21D174BA035E904Db93c` |
| `XGRNativeInterchainISM` | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` |

The Base registry provides the canonical Interchain validator membership used to verify XGR-origin attestations.

---

## 13. Forward asset route

The XGR → Base asset path is:

    native XGR
        │
        │ lock
        ▼
    XGR native Warp router
        │
        ▼
    XGR Mailbox
        │
        ▼
    XGR native BLS attestation
        │
        ▼
    Base Mailbox
        │
        ▼
    XGRNativeInterchainISM
        │
        ▼
    Base synthetic router
        │
        │ mint
        ▼
    synthetic XGR / wXGR

XGRChain native router:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

Base synthetic router:

    0x3b83687d77170D42feDDFe221629cc21e771e021

The forward direction has been validated end-to-end on mainnet with a controlled:

    0.1 XGR

transfer.

The validation demonstrated:

- XGR locking,
- message dispatch,
- BLS attestation,
- Merkle proof construction,
- destination verification,
- Base Mailbox processing,
- synthetic XGR minting.

---

# Reverse route: Base → XGRChain

## 14. External checkpoint observation

For the reverse route, XGR validator nodes independently observe the canonical Base Hyperlane state.

Configured origin:

| Field | Value |
| --- | --- |
| Chain | Base |
| Chain ID | `8453` |
| Domain | `8453` |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| Confirmation delay | `12` blocks |

After the configured confirmation delay, participating XGR validators can attest the confirmed Base checkpoint through the explicit:

    base_to_xgr

route.

---

## 15. Reverse RegistryV2

Canonical reverse RegistryV2:

    0x013F2F2f7dB897F941b19C4ab71C5395a48A0292

The V2 registry supports historical-set verification.

It is configured with compressed BLS verification using the native XGR precompile.

Its role is:

- Interchain membership,
- set versioning,
- historical-set retention,
- validator identity,
- quorum context.

---

## 16. Reverse native ISM

Canonical reverse ISM:

    0x3b83687d77170D42feDDFe221629cc21e771E021

`XGRNativeInterchainISMV2` verifies:

- checkpoint origin,
- destination,
- registry set ID,
- signer bitmap,
- quorum,
- compressed BLS aggregate signature,
- Hyperlane Merkle inclusion proof.

The contract resolves validator membership through RegistryV2 rather than maintaining a duplicate validator set.

---

## 17. Reverse safety aggregation

The Base domain on XGRChain routes through a 2-of-2 aggregation:

    0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e

Modules:

1. PausableISM  
   `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA`

2. XGRNativeInterchainISMV2  
   `0x3b83687d77170D42feDDFe221629cc21e771E021`

Both required modules must accept the message.

The PausableISM therefore acts as an explicit operational safety gate around the cryptographic native verification path.

Its current pause state is an operational deployment property and must be read from the live deployment state rather than assumed from architecture documentation.

---

## 18. Reverse asset route

The Base → XGRChain asset path is:

    synthetic XGR / wXGR
        │
        │ burn
        ▼
    Base synthetic router
        │
        ▼
    Base Mailbox
        │
        ▼
    Base MerkleTreeHook
        │
        ▼
    XGR validators observe checkpoint
        │
        ▼
    base_to_xgr BLS attestation
        │
        ▼
    reverse native relayer
        │
        ▼
    XGR Mailbox
        │
        ▼
    reverse 2-of-2 AggregationISM
        │
        ▼
    XGR native router
        │
        │ unlock
        ▼
    native XGR

This path has been validated end-to-end on mainnet under controlled conditions.

That validation demonstrates protocol capability.

It does not imply continuous automatic reverse submission.

---

# Warp asset model

## 19. Lock/mint and burn/unlock

The first XGR asset route does not require a liquidity pool.

Forward:

    XGRChain native XGR
            │
            │ lock
            ▼
      Base synthetic XGR

Reverse:

    Base synthetic XGR
            │
            │ burn
            ▼
      XGRChain native XGR

Supply correctness therefore depends on the router custody/mint/burn/unlock invariants rather than liquidity-pool inventory.

---

## 20. Router identities

### XGRChain

Native XGR router:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

### Base

Synthetic XGR / wXGR router:

    0x3b83687d77170D42feDDFe221629cc21e771e021

---

## 21. Cross-chain address collisions

Addresses must always be interpreted together with their chain.

For example:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

is:

- the native XGR Warp router on XGRChain,
- the XGR BLS verifier on Base.

And:

    0x3b83687d77170D42feDDFe221629cc21e771E021

is:

- `XGRNativeInterchainISMV2` on XGRChain,
- the synthetic XGR router on Base.

Therefore:

    chain + address

is the correct Interchain identity tuple.

An address alone is insufficient.

---

# Native relayer

## 22. Trust model

The native relayer is intentionally untrusted.

It performs availability and transaction-submission work.

It does not create security approval.

Responsibilities include:

- reading origin Dispatch events,
- indexing MerkleTreeHook leaves,
- retrieving completed native attestations,
- reconstructing Merkle proofs,
- locally checking the computed root,
- constructing ISM metadata,
- submitting `Mailbox.process()`.

Its private key pays destination transaction gas.

Compromise of a relayer gas key does not provide a valid BLS quorum signature.

---

## 23. Independent route processes

Forward and reverse delivery use independent relayer processes.

Forward:

    XGRChain → Base

Reverse:

    Base → XGRChain

They maintain separate:

- environment configuration,
- logs,
- PID files,
- persisted indexing state,
- submission controls.

One direction can therefore be disabled without disabling the other.

This is an operational property, not a protocol asymmetry.

---

## 24. Current reverse operational state

After controlled reverse-path mainnet validation, automatic reverse submission has been disabled.

Current documented runtime state:

    RELAYER_SUBMIT=false

and:

    reverse: STOPPED

The deployed reverse protocol path remains distinct from the current relayer process state.

Therefore these statements can simultaneously be true:

    Base → XGR is implemented
    Base → XGR passed E2E mainnet validation
    reverse automatic submission is disabled
    reverse relayer process is stopped

There is no contradiction.

---

# Hook integrity

## 25. MerkleTreeHook coverage

Native message verification proves inclusion in the configured canonical Hyperlane Merkle tree.

Therefore supported dispatch paths must reliably enter the expected MerkleTreeHook.

If a custom dispatch path bypasses that hook, the native proof system cannot establish inclusion in the expected tree.

Public route operation must therefore either:

- enforce the canonical MerkleTreeHook for supported dispatches, or
- explicitly reject unsupported custom-hook paths.

Hook configuration is part of the route's security boundary.

---

# Availability states

## 26. Deployment state is not route availability

The architecture distinguishes at least four states:

### Deployed

Contracts exist on-chain.

### Cryptographically configured

Registry, ISM and routing relationships are configured.

### E2E validated

A complete test message or asset transfer has succeeded.

### Operationally available

Required routers, safety modules, validator quorum and relayer submission are currently enabled.

### Publicly available

The system is intentionally exposed for normal user traffic.

These states must not be treated as synonyms.

In particular:

    E2E validated
    ≠
    permanently enabled

and:

    deployed
    ≠
    user-facing bridge open

---

# UI architecture

## 27. User-facing bridge requirements

A future or active bridge UI must derive live route state instead of assuming availability.

At minimum it should track:

- source chain,
- destination chain,
- source router,
- destination router,
- source-direction enabled state,
- destination-direction enabled state,
- pause state,
- token and decimals,
- amount,
- approval requirement where applicable,
- origin transaction hash,
- Hyperlane message ID,
- relay/delivery status,
- destination transaction hash.

A route should render unavailable when required security or operational conditions are not satisfied.

---

## 28. UI must not infer state from deployment alone

The existence of:

    router bytecode

or:

    deployment manifest entry

does not prove that a transfer can currently complete.

A user-facing availability decision should consider:

- router controls,
- safety-module state,
- validator quorum availability,
- relayer submission state,
- source and destination RPC health,
- current route configuration.

---

# Repository and source boundaries

## 29. XGRChain node repository

`xgr-node` contains chain-side primitives such as:

- native Interchain worker,
- BLS precompile,
- attestation state,
- attestation RPC.

Repository:

    https://github.com/xgr-network/xgr-node

---

## 30. Interchain repository

This repository contains:

- native destination contracts,
- registries,
- ISMs,
- deployment scripts,
- route manifests,
- relayer runtime,
- Interchain operations documentation.

Repository:

    https://github.com/xgr-network/xgr-hyperlane

---

## 31. Branch-state caveat

The repository currently contains implementation and deployment information that has evolved on:

    feature/native-interchain-registry-v1

while the `main` branch still contains older prelaunch documentation and manifests.

Before `main` is considered the complete canonical public representation of the deployed route, the following must be synchronized:

- contract source,
- deployment manifests,
- runtime examples,
- architecture documentation,
- operations documentation.

Verified on-chain deployment state and current runtime state must not be overwritten conceptually by stale repository text.

---

# Security principles

## 32. No single relayer trust

Message validity does not depend on trusting a relayer.

The relayer cannot bypass:

- registry membership,
- quorum,
- BLS signature verification,
- Merkle inclusion,
- destination ISM validation.

---

## 33. Fail closed

A message must not be delivered if required verification fails.

Examples:

- unknown set ID,
- insufficient signer bitmap,
- invalid BLS signature,
- invalid checkpoint,
- modified message,
- invalid Merkle proof,
- wrong origin,
- wrong destination,
- paused safety module.

The security architecture should reject rather than degrade into a weaker verification path.

---

## 34. Separate key domains

The following keys have different authority and should remain separate:

| Key | Authority |
| --- | --- |
| XGR consensus validator key | IBFT consensus |
| XGR Interchain BLS identity | Native checkpoint attestation |
| Relayer key | Destination transaction gas/submission |
| Router/deployer owner key | Contract administration |
| User wallet key | User asset transactions |

Compromise of one domain must not be treated as equivalent to compromise of all others.

---

# Current architecture summary

## 35. Forward

    XGR native router
        ↓
    XGR Mailbox
        ↓
    XGR MerkleTreeHook
        ↓
    XGR native BLS quorum
        ↓
    native relayer
        ↓
    Base Mailbox
        ↓
    XGR native ISM
        ↓
    Base synthetic router

Status:

    mainnet E2E validated

---

## 36. Reverse

    Base synthetic router
        ↓
    Base Mailbox
        ↓
    Base MerkleTreeHook
        ↓
    XGR base_to_xgr BLS quorum
        ↓
    reverse native relayer
        ↓
    XGR Mailbox
        ↓
    2-of-2 safety aggregation
        ↓
    XGR native router

Status:

    mainnet E2E validated
    reverse automatic submission currently disabled
    reverse relayer currently stopped

---

## 37. Design principle

The XGR Interchain architecture separates:

    chain consensus
        │
        ▼
    canonical chain state
        │
        ▼
    destination-specific BLS attestation
        │
        ▼
    untrusted message transport
        │
        ▼
    destination verification
        │
        ▼
    asset/message delivery

The relayer provides availability.

The validator quorum provides authorization.

The destination ISM provides verification.

The Warp routers provide asset semantics.

And XGRChain consensus remains independent from external-chain availability.
