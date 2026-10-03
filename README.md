# XGR Interchain / Hyperlane Integration

This repository contains the public contracts, deployment manifests, native relayer runtime and operational documentation for XGR Interchain infrastructure using Hyperlane-compatible messaging.

The first implemented asset route connects:

**XGRChain ↔ Base**

with:

- native XGR on XGRChain,
- synthetic XGR / wXGR on Base,
- lock/mint semantics from XGRChain to Base,
- burn/unlock semantics from Base to XGRChain.

Both directions have been validated end-to-end on mainnet.

The route is **not described as a permanently open public bridge** merely because both directions have passed end-to-end tests.

Runtime submission, pause controls, router controls and user-facing availability are separate operational states.

---

## Current status

| Component | Status |
| --- | --- |
| XGRChain mainnet | Live |
| XGRChain chain/domain | `1643` |
| Base chain/domain | `8453` |
| XGRChain Hyperlane Core | Deployed |
| XGR native Interchain node support | Active in current XGRChain node baseline |
| XGR → Base native security stack | Deployed |
| Base → XGR native security stack | Deployed |
| XGR native Warp router | Deployed |
| Base synthetic XGR / wXGR router | Deployed |
| XGR → Base E2E asset transfer | Mainnet validated |
| Base → XGR E2E asset transfer | Mainnet validated |
| User-facing public bridge | Not implied by E2E validation |
| Reverse relayer submission | Currently disabled |
| Reverse relayer process | Currently stopped |

Current XGRChain public node baseline:

    xgr-node v3.1.1

Release commit:

    1a4844b311fb856cb8c2303a40fa8aa69b560544

The current native Interchain implementation has been developed on:

    feature/native-interchain-registry-v1

The public `main` branch and its deployment manifests must be kept synchronized with the verified production implementation before they are treated as the sole authoritative deployment inventory.

---

# Architecture

## Separation from XGRChain consensus

XGR Interchain is deliberately separated from weighted IBFT consensus.

The XGRChain node provides:

- EVM execution,
- canonical chain state,
- IBFT finality,
- delegated PoS,
- native BLS cryptography,
- native Interchain attestation generation,
- read-only Interchain attestation RPC.

Hyperlane-compatible infrastructure provides:

- message dispatch,
- MerkleTreeHook insertion,
- destination Mailbox processing,
- message transport semantics.

The native Interchain worker is not part of the weighted-IBFT consensus-critical path.

A destination outage or relayer outage must not prevent:

- XGR block production,
- XGR block validation,
- IBFT finalization,
- chain synchronization.

---

## Security model

The XGR-origin route does not use the relayer as a trust anchor.

For an XGR-origin message:

1. the message is dispatched through the XGR Hyperlane Mailbox,
2. the canonical MerkleTreeHook inserts the message,
3. participating XGR validator nodes observe the canonical root,
4. the destination-specific XGR Interchain validator subset signs the checkpoint,
5. XGR nodes aggregate the required BLS quorum,
6. completed attestations become available through read-only XGR RPC,
7. an untrusted relayer reconstructs the Merkle proof,
8. the relayer submits the message, proof and attestation,
9. the destination native XGR ISM independently verifies the proof and BLS quorum,
10. the destination Mailbox delivers the message only after successful verification.

The relayer can delay or withhold delivery.

It cannot create a valid XGR BLS quorum attestation by itself.

---

## Consensus validators versus Interchain validators

These are related but separate roles.

An XGR Interchain validator must satisfy destination-specific Interchain membership rules.

The native security model also checks its relationship to XGR staking and BLS identity.

Conceptually:

    XGR consensus validator
            │
            ├── active staking identity
            └── BLS identity
                    │
                    ▼
        destination-specific
        Interchain registry
                    │
                    ▼
          Interchain signer

Membership in an Interchain validator set does not create additional XGRChain IBFT voting authority.

Likewise, normal XGRChain validator participation does not automatically make a validator an Interchain signer for every destination.

---

# XGR → Base

## Message and asset path

The forward asset path is:

    native XGR
        │
        │ lock
        ▼
    XGR native Warp router
        │
        ▼
    XGR Hyperlane Mailbox
        │
        ▼
    XGR MerkleTreeHook
        │
        ▼
    native XGR BLS attestation
        │
        ▼
    native relayer
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

A successful mainnet test transferred:

    0.1 XGR

from native XGR on XGRChain to synthetic XGR / wXGR on Base.

The observed forward test confirmed:

- native XGR locking,
- Hyperlane message dispatch,
- native XGR attestation,
- Merkle proof construction,
- Base Mailbox processing,
- destination ISM verification,
- synthetic asset minting.

---

## Forward native security stack on Base

| Component | Address |
| --- | --- |
| XGRInterchainBLSVerifier | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| XGRInterchainValidatorRegistry | `0x70F5752326735b31641f21D174BA035E904Db93c` |
| XGRNativeInterchainISM | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` |

The destination registry is the canonical Interchain membership state for the forward XGR-origin security path.

The destination ISM verifies:

- registry membership,
- current validator set,
- signer bitmap,
- BLS aggregate signature,
- quorum,
- Merkle message inclusion.

---

# Base → XGR

## Reverse message and asset path

The reverse asset path is:

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
    XGR validator nodes observe
    confirmed Base checkpoint
        │
        ▼
    base_to_xgr BLS attestation
        │
        ▼
    reverse native relayer
        │
        ▼
    XGR Hyperlane Mailbox
        │
        ▼
    DomainRoutingISM
        │
        ▼
    2-of-2 AggregationISM
        │
        ├── PausableISM
        │
        └── XGRNativeInterchainISMV2
                  │
                  ▼
        native BLS precompile 0x2040
                  │
                  ▼
        XGR native Warp router
                  │
                  │ unlock
                  ▼
              native XGR

This direction has also been validated end-to-end on mainnet under controlled conditions.

---

## Reverse native security stack on XGRChain

### RegistryV2

    0x013F2F2f7dB897F941b19C4ab71C5395a48A0292

`XGRInterchainValidatorRegistryV2` preserves historical validator sets.

This allows a checkpoint signed under set N to remain verifiable after a later membership transition.

### XGRNativeInterchainISMV2

    0x3b83687d77170D42feDDFe221629cc21e771E021

The reverse V2 ISM verifies compressed BLS aggregate signatures through the native XGRChain precompile:

    0x0000000000000000000000000000000000002040

### Reverse aggregation

    0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e

The reverse path uses a 2-of-2 aggregation containing:

1. PausableISM
2. XGRNativeInterchainISMV2

PausableISM:

    0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA

This provides an explicit operational safety gate in addition to native BLS verification.

---

# Warp routers

## XGRChain native router

| Field | Value |
| --- | --- |
| Network | XGRChain |
| Chain/domain | `1643` |
| Address | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Asset | Native XGR |
| Function | Lock / unlock |

## Base synthetic router

| Field | Value |
| --- | --- |
| Network | Base |
| Chain/domain | `8453` |
| Address | `0x3b83687d77170d42feddfe221629cc21e771e021` |
| Asset | Synthetic XGR / wXGR |
| Function | Mint / burn |

---

## Important: identical addresses on different chains

Two address collisions exist across the deployment.

The address:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

means:

- **XGRChain:** native XGR Warp router
- **Base:** XGR Interchain BLS verifier

Likewise:

    0x3b83687d77170D42feDDFe221629cc21e771E021

means:

- **XGRChain:** `XGRNativeInterchainISMV2`
- **Base:** synthetic XGR / wXGR Warp router

Always identify the chain together with the address.

An address alone is not sufficient identification in an Interchain deployment.

---

# Hyperlane Core

## XGRChain contracts

| Component | Address |
| --- | --- |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| DomainRoutingISM | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |

`ValidatorAnnounce` remains part of the deployed Hyperlane infrastructure and history but is not the trust anchor for XGR-origin native BLS security.

---

## External Hyperlane contracts on Base

| Component | Address |
| --- | --- |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| ValidatorAnnounce | `0x182E8d7c5F1B06201b102123FC7dF0EaeB445a7B` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| InterchainGasPaymaster | `0xc3F23848Ed2e04C0c6d41bd7804fa8f89F940B94` |

These Base contracts are external Hyperlane infrastructure rather than XGRChain consensus components.

---

# Native attestation RPC

XGRChain nodes expose completed native Interchain attestations through read-only RPC.

Latest completed forward attestation:

    xgr_getInterchainAttestation("base")

Latest completed reverse attestation:

    xgr_getInterchainAttestation("base_to_xgr")

Checkpoint-specific lookup:

    xgr_getInterchainAttestationByCheckpoint(
        route,
        setId,
        index,
        root
    )

These methods are read-only.

They cannot request, force or trigger validator signatures.

Attestations appear only after the native Interchain validator path has independently reached quorum.

---

# Native relayer

The current XGR native relayer implementation lives under:

    runtime/native-relayer/

It runs under Node.js and is intentionally untrusted.

Its responsibilities include:

- indexing Hyperlane Dispatch events,
- indexing canonical MerkleTreeHook leaves,
- retrieving completed XGR BLS attestations,
- reconstructing Hyperlane Merkle proofs,
- checking reconstructed roots locally,
- constructing native-ISM metadata,
- calling destination `Mailbox.process()`.

Its signing key is a destination transaction gas payer.

The relayer key is **not** an Interchain validator key and cannot manufacture a valid BLS quorum proof.

---

## Forward and reverse processes

The runtime maintains independent forward and reverse relayer processes.

Forward:

    XGRChain → Base

Reverse:

    Base → XGRChain

Each direction has independent:

- configuration,
- logs,
- PID state,
- indexed relayer state,
- submission control.

Runtime management is handled by:

    runtime/manage-relayers.sh

Example operations:

    ./manage-relayers.sh status all
    ./manage-relayers.sh start forward
    ./manage-relayers.sh start reverse
    ./manage-relayers.sh stop reverse
    ./manage-relayers.sh logs forward
    ./manage-relayers.sh logs reverse

---

## Current reverse runtime state

At the current documentation baseline, reverse automatic submission has intentionally been disabled after the controlled mainnet validation.

Current configuration:

    RELAYER_SUBMIT=false

Current process state:

    reverse: STOPPED

This is an **operational state**, not a limitation of the protocol implementation.

It demonstrates why:

    bidirectional E2E validated

must not be interpreted as:

    both relayers permanently running
    or
    public bridge continuously open

Operational state can change independently from deployed contracts and protocol capability.

---

# Repository layout

| Path | Purpose |
| --- | --- |
| `contracts/` | Native destination registry, verifier and ISM contracts |
| `test/` | Foundry tests for native Interchain contracts |
| `deployments/` | Machine-readable deployment and route manifests |
| `runtime/` | Native relayer and runtime configuration |
| `docs/` | Architecture, deployment and operations documentation |
| `script/` | Deployment scripts |
| `.github/workflows/` | Validation and controlled deployment workflows |

---

# Branch and deployment-state rule

The public repository currently contains two relevant development states:

    main

and:

    feature/native-interchain-registry-v1

The native Registry/ISM/relayer implementation and more recent deployment inventory have been developed on the feature branch.

Before `main` is treated as the canonical source for the complete deployed route, the following must agree:

- source code,
- deployment manifests,
- runtime examples,
- README,
- architecture documentation,
- operations documentation.

A stale `main` manifest must not override verified on-chain deployment state.

Likewise, an undocumented runtime state must not silently be presented as a permanent protocol state.

---

# Security boundaries

## Relayer

A relayer:

- observes messages,
- constructs proofs,
- pays destination gas,
- submits delivery transactions.

It does not have authority to forge BLS quorum approval.

---

## Interchain validator

An Interchain validator:

- participates in destination-specific checkpoint attestation,
- uses its BLS identity,
- must satisfy the native registry/staking rules.

It does not automatically gain additional IBFT consensus authority.

---

## Consensus validator

An XGRChain consensus validator:

- participates in IBFT,
- produces/finalizes XGRChain blocks,
- has stake- and uptime-weighted consensus power.

It is not automatically an Interchain signer for every route.

---

## Router owner / administration

Router or security-module administration is a separate permission domain.

Contract ownership does not grant:

- XGRChain consensus authority,
- BLS quorum authority,
- validator keys.

Operational controls should remain separated wherever practical.

---

# Fail-closed operation

A route must remain unavailable when its required security conditions are not met.

Examples include:

- insufficient BLS quorum,
- invalid signer bitmap,
- unknown validator set,
- stale or invalid set ID,
- invalid aggregate signature,
- invalid Merkle proof,
- modified message,
- paused safety module,
- disabled router direction,
- disabled relayer submission.

The system should fail closed rather than bypass verification.

---

# User-facing availability

A user-facing bridge must derive current availability from verified operational state.

It must not assume that a deployed router is usable merely because code exists at its address.

Relevant runtime state can include:

- source router enabled state,
- destination router enabled state,
- security-module state,
- relayer submission state,
- validator quorum availability,
- route configuration,
- destination chain health.

The repository therefore distinguishes:

    deployed

from:

    E2E validated

from:

    operationally enabled

from:

    publicly available

These are not synonymous.

---

# Testing

The native Interchain implementation includes deterministic contract and relayer tests.

The RegistryV2 / ISMV2 contract suite has been exercised against cases including:

- valid BLS verification,
- invalid signatures,
- insufficient signer sets,
- historical validator-set verification,
- unknown historical sets,
- membership transitions.

The native relayer contains tests for:

- Merkle-tree reconstruction,
- proof generation,
- metadata construction.

Before changing native security or relayer behavior, run the corresponding contract and runtime test suites.

---

# Documentation

- [Architecture](docs/architecture.md)
- [Operations and rollout](docs/operations.md)
- [Deployment inventory](docs/DEPLOYMENTS.md)
- [Security policy](SECURITY.md)

XGRChain protocol documentation:

https://github.com/xgr-network/XGR/tree/main/docs/chain

XGRChain node:

https://github.com/xgr-network/xgr-node

---

# Secrets

Never commit:

- consensus validator private keys,
- Interchain validator private keys,
- relayer/deployer private keys,
- seed phrases,
- wallet exports,
- SSH keys,
- cloud credentials,
- populated `.env` files,
- production API credentials.

Example and reference environment files must contain only non-secret values and placeholders.

---

# Update rule

After every production deployment, configuration change or E2E route test, update the public inventory with:

- network / chain ID,
- component,
- address,
- deployment transaction,
- deployment block,
- source branch / commit,
- owner or administration relationship,
- active/staged/paused state,
- relevant configuration transaction,
- route-direction state,
- E2E transaction/message evidence.

Do not delete superseded deployments.

Mark them clearly as historical or superseded.

---

# Official XGR resources

- Website: https://xgr.network
- Documentation: https://xgr.network/docs/
- Explorer: https://explorer.xgr.network
- XGR specifications: https://github.com/xgr-network/XGR
- XGRChain node: https://github.com/xgr-network/xgr-node
- GitHub organization: https://github.com/xgr-network

---

# License

Apache License 2.0.
