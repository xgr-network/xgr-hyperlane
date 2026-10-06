# XGR Interchain / Hyperlane Integration

XGR Interchain is the mainnet cross-chain infrastructure of XGR Network.

This repository contains the public contracts, deployment manifests, native relayer runtime and operational documentation for XGR Interchain using Hyperlane-compatible messaging and XGR-native BLS validator security.

The first production asset route connects:

**XGRChain ↔ Base**

with:

- native XGR on XGRChain,
- wrapped XGR / wXGR on Base,
- lock/mint semantics from XGRChain to Base,
- burn/unlock semantics from Base to XGRChain.

Both directions are deployed and have been validated end-to-end on mainnet.

The public bidirectional bridge is available at:

```text
https://bridge.xgr.network
```

Official Base wXGR:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

---

## Current status

| Component | Status |
| --- | --- |
| XGRChain | Mainnet |
| XGRChain chain/domain | `1643` |
| Base | Mainnet |
| Base chain/domain | `8453` |
| XGRChain Hyperlane Core | Mainnet |
| XGR native Interchain node support | Mainnet |
| XGR → Base native security stack | Mainnet |
| Base → XGR native security stack | Mainnet |
| XGR native Warp router | Mainnet |
| Base synthetic XGR / wXGR router | Mainnet |
| XGR → Base E2E asset transfer | Mainnet validated |
| Base → XGR E2E asset transfer | Mainnet validated |
| Public bidirectional bridge | Mainnet |
| Forward relayer submission | Mainnet enabled |
| Reverse relayer submission | Mainnet enabled |
| Forward relayer process | Mainnet running |
| Reverse relayer process | Mainnet running |

Current XGRChain public node baseline:

```text
xgr-node v3.1.1
```

Release commit:

```text
1a4844b311fb856cb8c2303a40fa8aa69b560544
```

The `main` branch is the canonical public source for the current XGR Interchain implementation, deployment manifests, runtime examples and operational documentation.

Dynamic runtime state can change independently from static repository documentation and should be verified live when current route availability matters.

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

Therefore:

```text
XGRChain consensus
≠
XGR Interchain validator quorum
```

A destination outage, remote RPC outage or relayer outage must not prevent:

- XGR block production,
- XGR block validation,
- IBFT finalization,
- normal chain synchronization.

---

## Security model

XGR Interchain does not use the relayer as the trust anchor for message validity.

For an XGR-origin message:

1. the message is dispatched through the XGR Hyperlane-compatible Mailbox,
2. the canonical MerkleTreeHook inserts the message,
3. participating XGR validator nodes observe the canonical root,
4. the destination-specific XGR Interchain validator subset signs the checkpoint,
5. XGR nodes aggregate the required BLS quorum,
6. completed attestations become available through read-only XGR RPC,
7. the native relayer reconstructs the Merkle proof,
8. the relayer submits the message, proof and attestation,
9. the destination XGR-native ISM independently verifies the proof and BLS quorum,
10. the destination Mailbox delivers the message only after successful verification.

The relayer can affect delivery availability.

It cannot create a valid XGR BLS quorum attestation by itself.

---

## Consensus validators versus Interchain validators

These are related but separate roles.

An XGR Interchain validator must satisfy destination-specific Interchain membership rules.

The native security model connects:

```text
XGR validator identity
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
```

Membership in an Interchain validator set does not create additional XGRChain IBFT voting authority.

Likewise, normal XGRChain validator participation does not automatically make a validator an Interchain signer for every destination.

### Destination-scoped membership

Interchain membership is scoped to the destination registry.

Checkpoint attestations remain route-specific.

For example:

```text
base_to_xgr
polygon_to_xgr
arbitrum_to_xgr
```

can share:

```text
destination = XGRChain
```

and therefore use the same XGR destination registry membership while retaining independent:

- source chains,
- Mailboxes,
- MerkleTreeHooks,
- confirmation policies,
- checkpoint streams,
- attestations.

V1 and V2 identify contract generations.

They do not mean forward versus reverse security models.

Both deployed generations use XGR-native BLS validator security.

---

## Interchain quorum

The native Interchain validator set uses an unweighted two-thirds quorum.

This is intentionally separate from XGRChain's stake- and uptime-weighted IBFT voting power.

Therefore:

```text
XGRChain consensus voting power
≠
Interchain attestation voting weight
```

The two systems use separate quorum semantics for separate security functions.

---

# XGR → Base

## Message and asset path

The forward asset path is:

```text
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
XGR native BLS attestation
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
wXGR
```

A successful controlled mainnet validation transferred:

```text
0.1 XGR
```

from native XGR on XGRChain to wXGR on Base.

The observed forward validation confirmed:

- native XGR locking,
- Hyperlane-compatible message dispatch,
- native XGR attestation,
- BLS quorum,
- Merkle proof construction,
- Base Mailbox processing,
- destination ISM verification,
- wXGR minting.

The forward route is deployed on mainnet and publicly available through the XGR Bridge.

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
- validator set,
- signer bitmap,
- BLS aggregate signature,
- quorum,
- Merkle message inclusion.

---

# Base → XGR

## Reverse message and asset path

The reverse asset path is:

```text
wXGR
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
confirmed Base checkpoint
    │
    ▼
XGR Interchain validators
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
```

This direction has also been validated end-to-end on mainnet.

A successful controlled reverse validation transferred:

```text
0.01 wXGR
```

from Base back to native XGR on XGRChain.

The reverse route is deployed on mainnet and publicly enabled through the XGR Bridge.

---

## Reverse source confirmation

The current Base source configuration uses a confirmation delay of:

```text
12 Base blocks
```

before the corresponding external checkpoint becomes eligible for XGR Interchain attestation.

This is a route-level Interchain policy.

It is separate from XGRChain IBFT finality.

---

## Reverse native security stack on XGRChain

### RegistryV2

```text
0x013F2F2f7dB897F941b19C4ab71C5395a48A0292
```

`XGRInterchainValidatorRegistryV2` preserves historical validator sets.

This allows a checkpoint signed under set N to remain verifiable after a later membership transition.

Current validated reverse configuration includes:

```text
setId = 1
validators = 3
quorum = 2
```

Current live membership must be read from the deployed registry when operationally relevant.

### XGRNativeInterchainISMV2

```text
0x3b83687d77170D42feDDFe221629cc21e771E021
```

The reverse V2 ISM verifies compressed BLS aggregate signatures through the native XGRChain precompile:

```text
0x0000000000000000000000000000000000002040
```

### Reverse aggregation

```text
0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e
```

The reverse path uses a 2-of-2 aggregation containing:

1. PausableISM
2. XGRNativeInterchainISMV2

PausableISM:

```text
0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA
```

Both modules must accept the message.

The PausableISM provides an explicit operational safety gate in addition to native BLS verification.

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
| Status | Mainnet |

## Base synthetic router

| Field | Value |
| --- | --- |
| Network | Base |
| Chain/domain | `8453` |
| Address | `0x3b83687d77170d42feddfe221629cc21e771e021` |
| Asset | wXGR |
| Function | Mint / burn |
| Status | Mainnet |

The Base synthetic router is also the official Base wXGR token contract.

Nominal bridge representation:

```text
1 XGR ↔ 1 wXGR
```

before applicable transaction and routing fees.

---

## Important: identical addresses on different chains

Two address collisions exist across the deployment.

The address:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

means:

- **XGRChain:** native XGR Warp router
- **Base:** XGR Interchain BLS verifier

Likewise:

```text
0x3b83687d77170d42feDDFe221629cc21e771e021
```

means:

- **XGRChain:** `XGRNativeInterchainISMV2`
- **Base:** official wXGR contract / synthetic XGR router

Always identify the chain together with the address.

The correct identity tuple is:

```text
chain + address
```

An address alone is insufficient.

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

`ValidatorAnnounce` remains part of the deployed Hyperlane-compatible infrastructure and deployment history but is not the trust anchor for XGR-native BLS security.

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

```text
xgr_getInterchainAttestation("base")
```

Latest completed reverse attestation:

```text
xgr_getInterchainAttestation("base_to_xgr")
```

Checkpoint-specific lookup:

```text
xgr_getInterchainAttestationByCheckpoint(
    route,
    setId,
    index,
    root
)
```

These methods are read-only.

They cannot request, force or trigger validator signatures.

Attestations appear only after the native Interchain validator path has independently reached quorum.

---

# Native relayer

The current XGR native relayer implementation lives under:

```text
runtime/native-relayer/
```

It runs under Node.js and is intentionally untrusted for message validity.

Its responsibilities include:

- indexing Hyperlane Dispatch events,
- indexing canonical MerkleTreeHook leaves,
- retrieving completed XGR BLS attestations,
- reconstructing Hyperlane Merkle proofs,
- checking reconstructed roots locally,
- constructing native-ISM metadata,
- calling destination `Mailbox.process()`.

Its signing key is a destination transaction gas payer.

The relayer key is not an Interchain validator key and cannot manufacture a valid BLS quorum proof.

---

## Forward and reverse processes

The runtime maintains independent forward and reverse relayer processes.

Forward:

```text
XGRChain → Base
```

Reverse:

```text
Base → XGRChain
```

Each direction has independent:

- environment configuration,
- logs,
- PID state,
- persisted indexing state,
- submission control.

Runtime management is handled by:

```text
runtime/manage-relayers.sh
```

Example operations:

```text
./manage-relayers.sh status all
./manage-relayers.sh start forward
./manage-relayers.sh start reverse
./manage-relayers.sh restart forward
./manage-relayers.sh restart reverse
./manage-relayers.sh stop forward
./manage-relayers.sh stop reverse
./manage-relayers.sh logs forward
./manage-relayers.sh logs reverse
```

---

## Current mainnet relayer state

Both production transfer directions are enabled.

Forward:

```text
route: XGRChain → Base
RELAYER_SUBMIT=true
process: RUNNING
status: Mainnet
```

Reverse:

```text
route: Base → XGRChain
RELAYER_SUBMIT=true
process: RUNNING
status: Mainnet
```

The reverse relayer currently uses:

```text
ORIGIN_RPC_URL=https://base-rpc.publicnode.com
```

The forward relayer uses the corresponding production Base RPC endpoint for destination submission.

These are runtime dependencies and may be changed without changing the deployed Interchain protocol.

Current relayer process state must still be monitored live because an off-chain process can restart, stop or lose connectivity independently from the deployed contracts.

---

# Public bridge

The production user-facing XGR Bridge is available at:

```text
https://bridge.xgr.network
```

It supports:

```text
XGR → wXGR
```

and:

```text
wXGR → XGR
```

for the current XGRChain ↔ Base route.

The user signs the source transaction with the user's own wallet.

XGR.Network infrastructure does not require possession of the user's wallet private key.

The public interface intentionally presents simplified transfer terminology.

Deep protocol and operator details remain in the technical documentation.

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

# Source-of-truth rule

The `main` branch is the canonical public repository state.

The following must remain synchronized whenever production state changes:

- contract source,
- deployment manifests,
- runtime examples,
- README,
- architecture documentation,
- operations documentation.

Machine-readable manifests under `deployments/` are the repository inventory.

Dynamic operational state must still be verified from live contract and runtime state.

A stale manifest or README must never override verified on-chain or runtime state.

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
- must satisfy the native registry and identity rules.

It does not automatically gain additional IBFT consensus authority.

---

## Consensus validator

An XGRChain consensus validator:

- participates in IBFT,
- produces and finalizes XGRChain blocks,
- has stake- and uptime-weighted consensus power.

It is not automatically an Interchain signer for every destination.

---

## Router owner / administration

Router or security-module administration is a separate permission domain.

Contract ownership does not grant:

- XGRChain consensus authority,
- Interchain BLS quorum authority,
- user-wallet authority.

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

The system must fail closed rather than bypass verification.

---

# User-facing availability

The public bridge derives route availability from current operational state.

It must not assume that a deployed router is usable merely because code exists at its address.

Relevant runtime state can include:

- source router enabled state,
- destination router enabled state,
- security-module state,
- relayer submission state,
- relayer process state,
- validator quorum availability,
- route configuration,
- source and destination RPC health.

The repository distinguishes:

```text
deployed
```

from:

```text
E2E validated
```

from:

```text
operationally enabled
```

from:

```text
publicly available
```

The current XGRChain ↔ Base route has reached all four states.

Dynamic operational availability nevertheless remains subject to current live state.

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

Mainnet end-to-end validation exists for:

```text
XGRChain → Base
```

and:

```text
Base → XGRChain
```

---

# Documentation

Implementation documentation:

- [Architecture](docs/architecture.md)
- [Interchain Liquidity Network (ILN)](docs/ILN.md)
- [Operations and rollout](docs/operations.md)
- [Deployment inventory](docs/DEPLOYMENTS.md)
- [Security policy](SECURITY.md)

Public XGR Interchain specifications:

```text
https://github.com/xgr-network/XGR/tree/main/docs/interchain
```

Public Interchain specification files:

```text
XGR_INTERCHAIN_Overview.md
XGR_INTERCHAIN_Security_Model.md
XGR_INTERCHAIN_Asset_Bridge.md
XGR_INTERCHAIN_Deployment_Reference.md
```

XGRChain protocol documentation:

```text
https://github.com/xgr-network/XGR/tree/main/docs/chain
```

XGRChain node:

```text
https://github.com/xgr-network/xgr-node
```

---

# Secrets

Never commit:

- consensus validator private keys,
- Interchain validator private keys,
- relayer private keys,
- deployer private keys,
- seed phrases,
- wallet exports,
- SSH private keys,
- cloud credentials,
- populated production secret files,
- production API credentials.

Example and reference environment files must contain only non-secret values and explicit placeholders.

---

# Update rule

After every production deployment, configuration change or E2E route test, update the public inventory where applicable with:

- network / chain ID,
- component,
- address,
- deployment transaction,
- deployment block,
- source branch / commit,
- owner or administration relationship,
- active or superseded state,
- relevant configuration transaction,
- route-direction state,
- E2E transaction/message evidence.

Dynamic process status must not be documented as if it were an immutable protocol property.

Do not delete superseded deployments.

Mark them clearly as historical or superseded.

---

# Official XGR resources

- Website: https://xgr.network
- Public Bridge: https://bridge.xgr.network
- Documentation: https://xgr.network/docs/
- Explorer: https://explorer.xgr.network
- XGR specifications: https://github.com/xgr-network/XGR
- XGR Interchain specifications: https://github.com/xgr-network/XGR/tree/main/docs/interchain
- XGRChain node: https://github.com/xgr-network/xgr-node
- GitHub organization: https://github.com/xgr-network

---

# License

Apache License 2.0.
