# XGR Interchain Liquidity Network (ILN)

**Document ID:** XGR-ILN-CONCEPT  
**Status:** Base-MVP implementation / deployment preparation  
**Last updated:** 2026-10-06  
**Current production baseline:** XGR Interchain on xgr-node v3.1.1  
**Target implementation baseline:** xgr-node v3.1.2 or later  
**Initial ILN corridor:** Base ↔ XGRChain
**Future spoke:** XDC (deferred from MVP)
**Deployment runbook:** `docs/ILN_BASE_MVP.md`

---

## 1. Purpose

The XGR Interchain Liquidity Network (ILN) extends the existing XGR Interchain bridge into a cross-chain liquidity routing network.

The central design decision is:

> XGR is the common routing and settlement asset between external chains.

The ILN does **not** require a DEX on XGRChain.

Instead, each connected external chain exposes local liquidity between one or more local assets and that chain's canonical wrapped XGR representation.

~~~text
external asset on chain A
        │
        │ local AMM
        ▼
wXGR on chain A
        │
        │ XGR Interchain bridge
        ▼
native XGR on XGRChain
        │
        │ XGR Interchain bridge
        ▼
wXGR on chain B
        │
        │ local AMM
        ▼
external asset on chain B
~~~

XGRChain therefore becomes the common settlement and transit layer without requiring price formation on XGRChain itself.

---

## 2. Initial MVP

The first ILN deployment is intentionally limited to the existing Base spoke:

~~~text
Base
  USDC / wXGR liquidity
        │
        │ message-specific XGR Interchain
        ▼
XGRChain
  native XGR
~~~

Both bridge directions are part of the MVP:

~~~text
Base wXGR → native XGR
native XGR → Base wXGR
~~~

The local Base user flow can therefore be:

~~~text
USDC on Base
    │
    │ local swap
    ▼
wXGR on Base
    │
    │ ILN bridge
    ▼
native XGR on XGRChain
~~~

or the reverse path back to Base liquidity.

The initial pool is deliberately small (approximately 500 USDC on the
USDC side) and is intended to prove route operation and early market demand,
not high-capacity execution.

XDC is a future spoke and is not part of this MVP.

---

## 3. Core principles

### 3.1 XGR is the routing asset

Cross-chain transit uses:

~~~text
wXGR → native XGR → wXGR
~~~

XGR is therefore not merely an optional fee token. It is the common settlement asset connecting external-chain liquidity spokes.

### 3.2 No XGRChain DEX is required

External swaps happen on the external chains.

XGRChain performs:

- native XGR settlement,
- lock / unlock operations,
- message routing,
- validator security,
- BLS quorum attestation,
- route coordination.

It does not need an AMM for ILN v1.

### 3.3 Each Interchain hop is independent

A multi-chain ILN route is decomposed into independent bridge operations.

For example:

~~~text
Base → XGRChain
~~~

and:

~~~text
XGRChain → XDC
~~~

are two separate Interchain hops.

Each hop has:

- its own origin transaction,
- its own source-chain fee,
- its own checkpoint,
- its own BLS quorum,
- its own relayer delivery,
- its own destination verification.

The user signs each source transaction.

A routing UI may orchestrate the workflow, but the protocol remains a sequence of independent signed operations.

### 3.4 Relayers are replaceable

No ILN route may depend cryptographically on a specific XGR GmbH relayer.

A relayer:

- observes eligible messages,
- retrieves completed attestations,
- reconstructs proofs,
- pays destination gas,
- calls the destination Mailbox.

A relayer does **not** create validity.

Any compatible relayer may deliver a valid message. A validator, third party, user or XGR-operated service may act as relayer.

### 3.5 Validator quorum remains the trust anchor

The native XGR Interchain validator set remains responsible for BLS checkpoint attestations.

~~~text
validator quorum = authorization
relayer           = delivery availability
~~~

---

## 4. Validator fee model

The ILN introduces an explicit economic reward for Interchain validator work.

### 4.1 Fee currency

The validator fee is paid in the **native currency of the source chain for each Interchain hop**.

| Source chain | Validator fee asset |
| --- | --- |
| Base | ETH |
| XGRChain | XGR |
| XDC Network | XDC |
| Polygon | POL |
| Arbitrum | ETH |

This rule is intentionally independent of the asset being routed.

For example, a Base user may start with a meme token:

~~~text
MEME
  ↓
local swap path
  ↓
wXGR
  ↓
XGR Interchain
~~~

The validator fee is still paid in ETH because Base is the source chain.

This avoids arbitrary reward-asset selection and keeps the rule consistent across all source assets.

### 4.2 Per-hop accounting

For a route:

~~~text
Base → XGRChain → XDC
~~~

the fee model is:

~~~text
Hop 1: Base → XGRChain
Validator fee = ETH

Hop 2: XGRChain → XDC
Validator fee = XGR
~~~

The second hop does not inherit the original Base fee currency. Each hop is economically independent.

### 4.3 Atomic fee + bridge initiation

The source-chain fee should be collected in the same transaction that starts the corresponding ILN bridge hop where practical.

~~~text
user transaction
      │
      ├── validator fee escrow
      └── bridge dispatch
~~~

If bridge initiation reverts, the fee operation must revert with it.

The user must not pay a validator fee for a bridge operation that was never successfully initiated.

---

## 5. Why native-source-chain fees

Native-source-chain fees provide four important properties.

### Consistency

The fee rule is deterministic and independent of the user's routed token.

### Validator incentive

Validators receive economically useful external assets such as ETH or XDC rather than only XGR. This is especially relevant while XGR market liquidity remains comparatively small.

### No cherry picking

The protocol does not arbitrarily prefer USDC, a specific stablecoin or a particular routed asset.

### Gas compatibility

The user already needs the native source-chain currency to execute the transaction. The validator fee therefore does not necessarily introduce a new asset requirement.

---

## 6. Existing production architecture remains valid

The current XGRChain ↔ Base bridge is a production system and must not be replaced merely to introduce ILN functionality.

ILN is intended to be additive.

### 6.1 Existing Base production components

| Component | Generation | Role |
| --- | --- | --- |
| Base synthetic XGR / wXGR Warp router | existing | mint / burn wXGR |
| Hyperlane Mailbox | existing external infrastructure | message dispatch / processing |
| Hyperlane MerkleTreeHook | existing external infrastructure | checkpoint Merkle tree |
| XGRInterchainBLSVerifier | V1 | BLS verification on Base |
| XGRInterchainValidatorRegistry | V1 | Base destination membership |
| XGRNativeInterchainISM | V1 | XGR-origin message verification on Base |

### 6.2 Existing XGRChain production components

| Component | Generation | Role |
| --- | --- | --- |
| XGR native Warp router | existing | lock / unlock native XGR |
| XGR Hyperlane-compatible Mailbox | existing | message processing |
| XGR MerkleTreeHook | existing | XGR-origin checkpoint tree |
| DomainRoutingISM | existing | source-domain security routing |
| AggregationISM | existing | combines required ISMs |
| PausableISM | existing | operational safety gate |
| XGRInterchainValidatorRegistryV2 | V2 | destination membership and historical sets |
| XGRNativeInterchainISMV2 | V2 | Base-origin BLS / Merkle verification |
| native BLS precompile 0x2040 | existing | compressed BLS verification |

V1 and V2 are contract generations, not synonyms for transfer direction.

New external-chain integrations should use V2-compatible security unless a later generation supersedes it.

---

## 7. Base-MVP source gateway

The Base MVP uses a deliberately minimal `ILNGateway`.

For each source direction, one immutable Gateway is deployed in front of the
already existing Warp router. The Gateway is also its own canonical ILN route
registry:

~~~text
ILN_REGISTRY_ADDR == ILNGateway
~~~

It implements both the node-required Gateway getters and
`getRoute(uint32)` for exactly one constructor-fixed destination.

There is no owner, mutable route table, validator-set mirror or fee-update
function in the Base MVP.

For every successful ILN operation the Gateway:

1. verifies the fixed destination domain;
2. requires the positive native validator fee;
3. invokes the existing canonical Warp router;
4. receives the real Hyperlane `messageId`;
5. emits `ILNOperation(messageId,destinationDomain,validatorFeeWei)`.

The Warp router remains the actual Hyperlane message sender.

The launch validator fee is expected to be nominal, for example 1 wei. A
material fee and signer-based distribution require a later reviewed contract
generation.

Future multi-spoke deployments may introduce a dynamic quorum-governed route
registry if operational evidence justifies the additional complexity.

---

## 8. Canonical-route security

A critical ILN requirement is:

> Foreign contracts must not be able to use the XGR validator quorum as a free generic consensus or attestation service.

v3.1.2 therefore no longer authorizes an entire Hyperlane checkpoint root generically.

The source Warp router remains the actual Hyperlane message sender. The canonical ILNGateway is the fee-qualified entry point in front of that router.

For every ILN operation the Gateway must atomically:

1. read the canonical source route;
2. require / escrow the native validator fee;
3. invoke the canonical source Warp router;
4. receive the returned Hyperlane `messageId`;
5. emit:

~~~solidity
event ILNOperation(
    bytes32 indexed messageId,
    uint32 indexed destinationDomain,
    uint256 validatorFeeWei
);
~~~

Validators scan this event only from the canonical Gateway after the source confirmation policy has been satisfied.

The resulting BLS payload is message-specific and binds:

- source chain and domain,
- destination domain,
- validator set ID,
- exact confirmed source block,
- source ILN registry,
- canonical ILNGateway,
- canonical source Warp router,
- canonical Mailbox,
- canonical MerkleTreeHook,
- canonical destination Warp router,
- the native validator fee escrowed for that operation,
- the authorized Hyperlane message ID,
- checkpoint root and index.

An unrelated contract or a user calling the Warp router directly may still create an ordinary Hyperlane message and alter the common Merkle root. That message does **not** receive a canonical Gateway `ILNOperation` record, so XGR validators do not create an ILN authorization for its message ID.

The destination-side ILN security module must additionally verify that the actual Hyperlane message being processed has exactly the `authorizedMessageId` contained in the BLS payload and is included in the signed Merkle root.

This gives the important security boundary:

~~~text
signed checkpoint root
        +
authorized messageId
        +
canonical route context
        +
Gateway fee proof
        =
one authorized ILN message
~~~

The root alone is never sufficient for ILN authorization.

## 9. Validator fee eligibility

Validator signing is derived independently from canonical source-chain data.

A message becomes eligible only when a confirmed canonical Gateway operation exists for that exact message ID:

~~~text
canonical ILNGateway
        ↓
native fee escrowed atomically
        ↓
canonical Warp transfer succeeds
        ↓
ILNOperation(messageId, destinationDomain, fee)
        ↓
source confirmations satisfied
        ↓
validator independently verifies operation + route + checkpoint
        ↓
validator may sign XGR_ILN_CHECKPOINT_V1
~~~

The relayer is not an authority for fee payment or message eligibility.

A fee update executed later in the same block must not invalidate an operation that was valid earlier in that block. The signed fee therefore comes from the atomic Gateway operation for the authorized message ID rather than from a later end-of-block fee comparison.

## 10. Fee distribution

Signer-based fee distribution is a **future requirement for material fees**,
not part of the Base MVP.

xgr-node v3.1.2 requires a strictly positive operation fee, so the initial
immutable Base/XGR Gateways use an economically negligible value such as
`1 wei`. The Gateway escrows that nominal amount so fee qualification remains
atomic with bridge initiation.

The Base MVP deliberately does not add validator-set mirrors, settlement
proofs and claim accounting solely to distribute a negligible launch fee.

Before a materially non-zero validator fee is introduced, the source-chain
fee contract must be upgraded to a reviewed permissionless settlement model
that credits only validators present in the accepted signer bitmap.

The long-term target remains:

~~~text
completed attestation + signerBitmap
        ↓
permissionless settlement
        ↓
claimable balance per actual signer
~~~

---

## 11. Quorum model

The existing native Interchain quorum model remains:

~~~text
unweighted two-thirds quorum
~~~

of the active destination-specific Interchain validator set.

Example:

~~~text
validators = 3
quorum     = 2
~~~

The completed attestation contains or derives:

- validator set ID,
- checkpoint root,
- checkpoint index,
- signer bitmap,
- aggregate BLS signature,
- route context.

ILN adds **eligibility conditions before signing**. It does not turn the relayer into part of the quorum.

---

## 12. Route registry

### Base MVP

The Base MVP does **not** deploy a separate mutable route registry.

Each immutable `ILNGateway` also implements the exact `getRoute(uint32)` ABI
consumed by xgr-node v3.1.2. Its route-critical values are constructor
immutables, and `ilnRegistry()` returns the Gateway itself.

Therefore the protocol truth for the initial Base spoke is still on-chain,
but it has no route administrator and no mutable route state.

Changing the route requires deploying a new Gateway and performing an explicit
controlled cutover.

### Future dynamic registry

For a larger multi-spoke network, a separate quorum-governed route registry
may become useful for FEE_UPDATE, ROUTE_ADD, ROUTE_ENABLE and ROUTE_DISABLE.
The v3.1.2 node already contains governance payload/quorum capabilities for
that future model, but the Base MVP intentionally does not depend on them.

This preserves the target property:

~~~text
protocol-defined route state
!=
relayer configuration
~~~

---

## 12.1 Node bootstrap configuration

The node environment contains a network-scoped bootstrap pointer to the
canonical on-chain ILN route source.

For the Base MVP that pointer is simply the immutable Gateway address:

~~~text
XGR_INTERCHAIN_BASE_ILN_REGISTRY_ADDR=<BASE_ILN_GATEWAY>
XGR_INTERCHAIN_XGR_ILN_REGISTRY_ADDR=<XGR_ILN_GATEWAY>
~~~

The local route declaration binds only network names:

~~~text
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_NETWORK=base
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_DESTINATION=xgr
~~~

Legacy route-local source fields such as `SOURCE_MAILBOX_ADDR`,
`SOURCE_MERKLE_TREE_HOOK_ADDR`, `SOURCE_CHAIN_ID` and `SOURCE_TYPE` are not
accepted by v3.1.2.

For future dynamic registries, the same ENV field can point to a dedicated
registry contract without changing the node-side route model.

---

### 12.2 v3.1.2 source-network cutover

v3.1.2 is a breaking Interchain security cutover.

The generic v3.1.1 checkpoint signer is removed from the runtime, legacy `checkpoint_vote` gossip is rejected, and the new Interchain network uses:

~~~text
/xgr/interchain/2.0.0
~~~

There is no implicit route fallback.

The route ENV contains only configured network names:

~~~text
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_NETWORK=base
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_DESTINATION=xgr
~~~

For the Base MVP, canonical contract addresses and the nominal fee come from the source network's immutable self-registry Gateway. A future multi-spoke deployment may instead use a separate quorum-governed registry.

Validators persist their source scan cursor and pending local votes. The initial scan starts at `ILNGateway.activationBlock()`; completed attestations are indexed by the authorized Hyperlane `messageId` and exposed through a read-only RPC.

All Interchain validators must be upgraded before any ILN route is activated. The v3.1.2 binary may be rolled out first with no active ILN routes.


---

## 13. Relayer independence

A completed ILN attestation should be consumable by any compatible relayer.

~~~text
source transaction
      ↓
canonical checkpoint
      ↓
XGR validator BLS quorum
      ↓
completed attestation
      ↓
XGR / validator / third-party / user relayer
      ↓
destination Mailbox.process()
~~~

A relayer outage delays delivery.

It must not invalidate the source transaction or require the user to recover funds through a trusted operator.

---

## 14. Liquidity architecture

The ILN does not create liquidity.

Each external spoke requires sufficient local liquidity against wXGR.

Initial examples:

### Base

~~~text
USDC / wXGR
~~~

### XDC

~~~text
wXGR / XDC
~~~

Future examples may include:

~~~text
WETH / wXGR
POL / wXGR
other local assets / wXGR
~~~

A chain does not need pairwise liquidity with every other connected chain.

The common wXGR / XGR transit model avoids an N×N pool topology.

---

## 15. Economic route

For the Base MVP:

~~~text
Base
USDC
  │
  │ local AMM
  ▼
wXGR
  │
  │ message-specific ILN bridge
  ▼
XGRChain
native XGR
~~~

and in the reverse direction:

~~~text
native XGR on XGRChain
  │
  │ message-specific ILN bridge
  ▼
wXGR on Base
~~~

The total user cost consists of Base/XGR transaction gas, the local AMM fee
and slippage, and the nominal source validator fee. With the initial roughly
500-USDC pool side, useful trade size is determined primarily by live AMM
slippage rather than bridge capacity.

XDC and a second external-chain AMM hop are deferred until after Base-MVP
evidence.

---

## 16. Competitive positioning

ILN should compete on **all-in execution cost and route availability**, not on a claim that another protocol always charges a specific protocol fee.

A routing layer may compare the total output of alternative routes and prefer ILN when the XGR route offers better execution.

Potential advantages include:

- efficient local wXGR liquidity,
- low validator fees,
- low-cost source chains,
- direct access to chains or assets not covered by competing routes,
- XGR-native validator security,
- a common routing asset that reduces pairwise liquidity requirements.

---

## 17. Base contract map

### Existing Base production contracts retained

| Logical role | Contract |
| --- | --- |
| wXGR asset routing | existing Base synthetic wXGR Warp router/token |
| message transport | existing Hyperlane Mailbox |
| checkpoint tree | existing Hyperlane MerkleTreeHook |
| XGR BLS verification | existing XGRInterchainBLSVerifier V1 |
| destination validator membership | existing XGRInterchainValidatorRegistry V1 |

### New Base-MVP contracts

| Logical role | Component |
| --- | --- |
| Base -> XGR canonical ILN entry + immutable route + nominal ETH fee escrow | `ILNGateway` |
| XGR -> Base message-specific BLS/Merkle authorization | `XGRILNInterchainISM` |

The existing Base validator registry and wXGR Warp router are reused.

---

## 18. XGRChain contract map

### Existing XGRChain production contracts retained

| Logical role | Contract |
| --- | --- |
| native XGR asset routing | existing native XGR Warp router |
| message transport | existing XGR Mailbox |
| checkpoint tree | existing XGR MerkleTreeHook |
| source-domain routing | existing DomainRoutingISM |
| operational safety | existing PausableISM |
| validator membership / historical sets | existing XGRInterchainValidatorRegistryV2 |
| compressed BLS verification | native precompile `0x2040` |

### New Base-MVP components

| Logical role | Component |
| --- | --- |
| XGR -> Base canonical ILN entry + immutable route + nominal XGR fee escrow | `ILNGateway` |
| Base -> XGR message-specific authorization | `XGRILNInterchainISMV2` |
| safety composition | fresh 2-of-2 PausableISM + ILN-ISM aggregation |

No new validator registry is required on XGRChain.

---

## 19. XDC spoke

A future XDC spoke should use V2-compatible XGR-native security.

At minimum the XDC integration requires:

- XDC Hyperlane-compatible Mailbox / messaging environment as applicable,
- canonical checkpoint path,
- destination-side XGR-native BLS verification,
- V2-compatible Interchain validator registry,
- V2-compatible XGR-native ISM,
- synthetic wXGR router / token representation,
- native relayer compatibility,
- source-chain native XDC fee handling for XDC-origin ILN hops.

The future intended XDC liquidity pool is:

~~~text
wXGR / XDC
~~~

The exact DEX and pool implementation are separate from the Interchain security protocol.

---

## 20. v3.1.2 node scope

The v3.1.2 node scope remains outside consensus-critical execution.

For the Base MVP the required runtime behavior is:

1. discover the immutable source Gateway through `ILN_REGISTRY_ADDR`;
2. read and historically validate its canonical `getRoute(uint32)` tuple;
3. scan only confirmed `ILNOperation` events from that exact Gateway;
4. verify exact messageId, fee, source block, route and Merkle root before signing;
5. aggregate the existing unweighted two-thirds Interchain BLS quorum;
6. persist/rebroadcast message-specific votes and attestations;
7. expose attestations by route and messageId;
8. fail closed for legacy or non-canonical route data.

The governance proposal/quorum machinery implemented in v3.1.2 remains
available for a future dynamic registry generation but is not required to
activate the immutable Base MVP.

The v3.1.2 design does not modify IBFT block-validity rules, EVM
state-transition rules or consensus-critical execution. An ILN failure must
not stop XGRChain block production or finality.

---

## 21. Non-goals for ILN v1

ILN v1 does not require:

- an XGRChain DEX,
- a generic all-assets bridge,
- arbitrary cross-chain application messages,
- arbitrary reward assets,
- a trusted XGR GmbH relayer,
- a new L2,
- a separate synthetic validation-ledger transaction on XGRChain,
- replacement of the existing XGR ↔ Base production bridge.

---

## 22. Security invariants

### Asset safety

A relayer cannot mint or unlock XGR without valid destination security verification.

### Validator authorization

Only the active XGR Interchain validator quorum can produce a valid native attestation.

### Route isolation

An unrelated contract must not be able to convert XGR validator work into a valid generic cross-chain authorization service.

### Fee qualification

An ILN operation must not become eligible for validator signing unless the required source-native validator fee condition is satisfied.

### Relayer independence

A specific relayer operator is never part of message validity.

### Existing bridge compatibility

Introducing ILN must not silently weaken or change the security behavior of the existing XGRChain ↔ Base production route.

### Fail closed

Invalid route, fee, signer set, signature, proof or safety state must reject the operation.

---

## 23. Implementation sequence

A conservative Base-MVP implementation order is:

1. complete and publish xgr-node v3.1.2;
2. upgrade all Interchain validators with no active ILN route;
3. deploy the immutable Base source Gateway;
4. deploy the immutable XGR source Gateway;
5. deploy Base `XGRILNInterchainISM` using the existing Base V1 registry;
6. deploy XGR `XGRILNInterchainISMV2` using the existing XGR RegistryV2;
7. deploy a fresh XGR PausableISM + ILN-ISM 2-of-2 aggregation;
8. configure node `ILN_REGISTRY_ADDR` values to the corresponding Gateways;
9. perform the controlled destination-security cutover;
10. run both ILN relayers in observe-only mode and require static validation;
11. validate tiny transfers in both directions;
12. enable continuous submission only after both directions pass;
13. seed the small Base USDC/wXGR pool;
14. expose live AMM quote/slippage in the user-facing route.

The exact operational sequence is maintained in `docs/ILN_BASE_MVP.md`.

---

## 24. MVP success condition

The first complete ILN proof should demonstrate:

~~~text
USDC on Base
    ↓
wXGR on Base
    ↓
native XGR on XGRChain
~~~

and the reverse bridge direction:

~~~text
native XGR on XGRChain
    ↓
wXGR on Base
~~~

with:

- user-signed source transactions,
- native-source-chain validator fees per bridge hop,
- XGR BLS quorum security,
- no trusted relayer requirement,
- no XGRChain DEX,
- no arbitrary third-party use of the ILN attestation path,
- deterministic accounting of validator rewards,
- recoverable delivery if a relayer disappears after source finalization.

---

## 25. Current versus planned status

| Capability | Status |
| --- | --- |
| XGRChain ↔ Base bridge | Mainnet v3.1.1 baseline |
| XGR-native BLS quorum | Mainnet |
| Replaceable relayer trust model | Mainnet architecture |
| Base wXGR | Mainnet |
| Base USDC / wXGR ILN liquidity | small Base-MVP pool planned |
| immutable self-registry `ILNGateway` | implemented in repository / deployment pending |
| nominal positive source-chain validator fee | implemented / launch target 1 wei |
| signer-based material-fe settlement | deferred |
| Base message-specific V1-registry ISM | implemented / deployment pending |
| XGR message-specific RegistryV2 ISM | implemented / deployment pending |
| dynamic quorum-governed ILN route registry | deferred; node governance capability retained |
| xgr-node v3.1.2 message-specific ILN eligibility | implemented and release validation in progress |
| Base ↔ XGR ILN route | deployment/E2E pending |
| XDC spoke | deferred |

---

## 26. Design summary

The ILN can be summarized as:

~~~text
local liquidity
      +
wXGR spokes
      +
native XGR settlement on XGRChain
      +
XGR validator BLS security
      +
native-source-chain validator rewards
      +
replaceable relayers
~~~

The resulting architecture gives XGR a direct functional role:

> XGR is the common settlement asset that connects independent external-chain liquidity markets through XGR-native validator security.
