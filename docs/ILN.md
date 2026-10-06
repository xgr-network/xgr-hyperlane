# XGR Interchain Liquidity Network (ILN)

**Document ID:** XGR-ILN-CONCEPT  
**Status:** Design / planned implementation  
**Last updated:** 2026-10-06  
**Current production baseline:** XGR Interchain on xgr-node v3.1.1  
**Target implementation baseline:** xgr-node v3.1.2 or later  
**Initial ILN corridor:** Base ↔ XGRChain ↔ XDC

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

The first proposed ILN corridor is:

~~~text
Base
  USDC / wXGR liquidity
        │
        ▼
XGRChain
  native XGR transit
        │
        ▼
XDC Network
  wXGR / XDC liquidity
~~~

Example user route:

~~~text
USDC on Base
    │
    │ local swap
    ▼
wXGR on Base
    │
    │ bridge hop 1
    ▼
native XGR on XGRChain
    │
    │ bridge hop 2
    ▼
wXGR on XDC
    │
    │ local swap
    ▼
native XDC
~~~

The intended user-level result is:

~~~text
USDC on Base → XDC
~~~

while the protocol internally uses XGR as the common routing asset.

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

## 7. Planned ILN source-chain gateway

The ILN needs a canonical entry point for fee-qualified bridge operations.

Working name:

~~~text
ILNGateway
~~~

For the initial implementation, fee-vault functionality may be integrated directly into the same contract to reduce:

- deployment count,
- gas overhead,
- call depth,
- attack surface.

Conceptually:

~~~text
User
  │
  ▼
ILNGateway / FeeVault
  │
  ├── validates ILN parameters
  ├── escrows native validator fee
  ├── emits fee / route accounting
  └── invokes the canonical bridge path
          │
          ▼
      Warp router
          │
          ▼
       Mailbox
          │
          ▼
    MerkleTreeHook
~~~

The exact contract split is an implementation choice. The protocol invariant is more important than whether gateway and vault are one or two contracts.

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

The long-term invariant is:

> The source-chain fee must be distributable to the validators whose signatures contributed to the accepted quorum for that hop, without requiring custody by a specific XGR-operated relayer.

The attestation already exposes a signer bitmap and aggregate BLS proof.

The v3.1.2 settlement model is **claim-based**.

After a completed attestation exists, any compatible caller may submit the settlement proof to the source-chain ILN fee contract:

~~~text
attestation + setId + signerBitmap + aggregate signature
        ↓
settle(...)
        ↓
verify quorum and prevent duplicate settlement
        ↓
claimable[signer] += equal signer share
~~~

Only validators whose bits are set in the accepted signer bitmap receive the fee for that operation.

For ILN v1, the fee is divided **equally among the validators that actually signed the accepted quorum**.

The contract accumulates balances per validator. Validators later withdraw their accumulated native-currency rewards themselves:

~~~text
validator → claim() → native source-chain currency
~~~

This avoids pushing one native-currency transfer per signer during the user's bridge transaction and allows validators to batch many small rewards into one withdrawal.

Settlement and withdrawal must not require an XGR-operated relayer or custodian. A settlement transaction may be submitted by any party, while only the validator's registered payout address may claim that validator's accrued balance.

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

For a permissionless operating model, canonical ILN routes should not ultimately depend only on an XGR GmbH server's local configuration.

A planned ILN route registry should define the protocol-recognized route set.

Working concept:

~~~text
ILNRouteRegistry
~~~

Possible route fields include:

- source chain / domain,
- destination chain / domain,
- canonical source gateway,
- canonical source Mailbox,
- canonical checkpoint hook or path,
- canonical destination recipient / router,
- validator-fe asset rule,
- minimum or configured fee parameters,
- confirmation policy,
- enabled / disabled state.

Canonical ILN route state and mutable ILN parameters are governed by the Interchain validator quorum rather than by a privileged administrator key.

The governance lifecycle is:

~~~text
proposal create
      ↓
proposal ID / canonical payload
      ↓
Interchain validators inspect and approve/sign
      ↓
unweighted 2/3 BLS quorum
      ↓
proposal becomes executable
      ↓
any party may execute
      ↓
on-chain state changes
~~~

Initial ILN v1 proposal types are:

- FEE_UPDATE,
- ROUTE_ADD,
- ROUTE_ENABLE,
- ROUTE_DISABLE.

A fee update binds at minimum the source chain, destination domain, new native fee, validator set context and a replay-safe proposal nonce / identifier.

The proposer and executor do not need privileged authority. The BLS quorum is the authorization.

Completed governance quorums are exposed by validator nodes through a read-only RPC so that any executor can retrieve the proof package without trusting a specific XGR-operated service:

~~~text
proposal + validator votes
        ↓
2/3 BLS quorum
        ↓
validator node persists quorum
        ↓
read-only RPC by proposalId
        ↓
payload + signerBitmap + aggregateSignature
        ↓
any executor
        ↓
ILN registry execute(...) on the affected source chain
~~~

The RPC is read-only and must never create, approve, sign or execute a proposal.

The target security property is:

~~~text
protocol-defined route state
≠
XGR GmbH relayer configuration
~~~

A relayer may choose what it delivers. It must not define what is valid.

---

## 12.1 Node bootstrap configuration

The node environment is not the canonical source of individual ILN route addresses.

The node should be configured with the minimum bootstrap information required to locate the canonical on-chain ILN registry **per network**, for example:

~~~text
XGR_INTERCHAIN_BASE_ILN_REGISTRY_ADDR=0x...
XGR_INTERCHAIN_XGR_ILN_REGISTRY_ADDR=0x...
XGR_INTERCHAIN_XDC_ILN_REGISTRY_ADDR=0x...
~~~

together with the RPC / chain connectivity required to read the corresponding network.

The ILN registry pointer is therefore network-scoped, not global. A validator may operate several network connections, each with its own local ILN registry contract.

The canonical gateway, route state and mutable ILN parameters are then read from the quorum-governed on-chain registry.

Therefore:

~~~text
ENV = bootstrap pointer
on-chain ILN registry = protocol truth
~~~

A validator operator changing a local environment variable must not be able to redefine a valid ILN route.

In v3.1.2, the local route declaration only binds configured network names:

~~~text
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_NETWORK=base
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_DESTINATION=xgr
~~~

Legacy route-local source fields such as `SOURCE_MAILBOX_ADDR`, `SOURCE_MERKLE_TREE_HOOK_ADDR`, `SOURCE_CHAIN_ID` and `SOURCE_TYPE` are not accepted by the v3.1.2 route loader. The canonical contract addresses come from the source network ILN registry.

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

Canonical contract addresses and mutable fee state come from the source network's quorum-governed ILN registry.

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

For the initial MVP:

~~~text
Base
USDC
  │
  │ local AMM
  ▼
wXGR
  │
  │ bridge fee in ETH
  ▼
XGRChain
native XGR
  │
  │ bridge fee in XGR
  ▼
XDC
wXGR
  │
  │ local AMM
  ▼
XDC
~~~

The total user cost consists of:

- local AMM fees,
- local AMM slippage,
- source transaction gas for each hop,
- native Interchain validator fee for each hop,
- destination delivery gas / relayer economics as applicable.

The number of deployed contracts is not the number of user transactions. Internal contract calls remain part of the same source transaction where designed atomically.

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

### Existing Base production contracts

| Logical role | Contract |
| --- | --- |
| wXGR asset routing | Base synthetic XGR / wXGR Warp router |
| message transport | Hyperlane Mailbox |
| checkpoint tree | Hyperlane MerkleTreeHook |
| XGR BLS verification | XGRInterchainBLSVerifier V1 |
| destination validator membership | XGRInterchainValidatorRegistry V1 |
| XGR-origin security module | XGRNativeInterchainISM V1 |

### Planned Base ILN additions

| Logical role | Planned component |
| --- | --- |
| canonical ILN entry + native ETH validator fee escrow | ILNGateway / FeeVault |
| canonical ILN application / route restriction | v3.1.2 ILN authorization mechanism; final contract split TBD |

The existing production bridge contracts are not discarded.

---

## 18. XGRChain contract map

### Existing XGRChain production contracts

| Logical role | Contract |
| --- | --- |
| native XGR asset routing | XGR native Warp router |
| message transport | XGR Hyperlane-compatible Mailbox |
| checkpoint tree | XGR MerkleTreeHook |
| source-domain routing | DomainRoutingISM |
| reverse security composition | AggregationISM |
| operational safety | PausableISM |
| native BLS security | XGRNativeInterchainISMV2 |
| validator membership / historical sets | XGRInterchainValidatorRegistryV2 |
| compressed BLS verification | native precompile 0x2040 |

### Planned XGRChain ILN additions

Potential additions include:

- ILN route registry,
- XGR-source ILN fee handling for outbound hops,
- ILN authorization policy consumed by the native worker,
- XDC route configuration and XDC destination security deployment.

Exact contract count should be minimized.

---

## 19. XDC spoke

The initial XDC spoke should use V2-compatible XGR-native security.

At minimum the XDC integration requires:

- XDC Hyperlane-compatible Mailbox / messaging environment as applicable,
- canonical checkpoint path,
- destination-side XGR-native BLS verification,
- V2-compatible Interchain validator registry,
- V2-compatible XGR-native ISM,
- synthetic wXGR router / token representation,
- native relayer compatibility,
- source-chain native XDC fee handling for XDC-origin ILN hops.

The intended liquidity pool is:

~~~text
wXGR / XDC
~~~

The exact DEX and pool implementation are separate from the Interchain security protocol.

---

## 20. v3.1.2 node scope

The planned xgr-node v3.1.2 scope should remain narrowly focused.

Required node-side changes are expected to include:

1. ILN route / application eligibility checks before signing;
2. canonical ILN registry discovery from a minimal bootstrap configuration;
3. native source-chain fee verification for ILN operations;
4. ILN governance proposal creation, inspection, validator approval/signing, quorum aggregation and read-only quorum retrieval by proposal ID;
5. initial governance actions for FEE_UPDATE, ROUTE_ADD, ROUTE_ENABLE and ROUTE_DISABLE;
6. preservation of existing v3.1.1 bridge behavior;
7. explicit fail-closed handling for non-canonical ILN messages;
8. support for the new XDC route;
9. deterministic tests covering foreign-contract abuse attempts;
10. deterministic tests covering missing or invalid fee conditions;
11. deterministic tests covering stale/replayed governance proposals and insufficient quorum.

The ILN worker remains outside weighted-IBFT consensus-critical execution.

The v3.1.2 design does **not** require a chain hard fork as long as it remains confined to the Interchain worker, ordinary EVM contracts and existing BLS execution support. It must not modify IBFT block-validity rules, EVM state-transition rules or consensus-critical execution.

An ILN failure must not stop XGRChain block production or finality.

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

A conservative implementation order is:

1. freeze this ILN concept and security invariants;
2. design the exact v3.1.2 ILN eligibility rule;
3. design the minimal ILNGateway / FeeVault interface;
4. define source-chain validator reward settlement;
5. implement canonical route authorization;
6. add node-side ILN checks without changing current bridge behavior;
7. add XDC destination contracts using V2-compatible security;
8. deploy wXGR on XDC;
9. validate XGRChain ↔ XDC bridge E2E;
10. seed Base USDC / wXGR liquidity;
11. seed XDC wXGR / XDC liquidity;
12. validate a controlled Base USDC → XDC ILN route;
13. expose route orchestration in the user-facing interface;
14. publish operational and security documentation.

---

## 24. MVP success condition

The first complete ILN proof should demonstrate:

~~~text
USDC on Base
    ↓
wXGR on Base
    ↓
native XGR on XGRChain
    ↓
wXGR on XDC
    ↓
native XDC
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
| XGRChain ↔ Base bridge | Mainnet |
| XGR-native BLS quorum | Mainnet |
| Replaceable relayer trust model | Mainnet architecture |
| Base wXGR | Mainnet |
| Base USDC / wXGR ILN liquidity | Planned |
| ILNGateway / FeeVault | Planned |
| Native source-chain validator fee | Planned |
| Equal-share signer settlement + claim() | Design fixed / implementation planned |
| 2/3 BLS proposal governance | Node implementation complete on PoS_3; on-chain executor contract pending |
| On-chain canonical ILN route registry | Node reader/interface fixed; contract deployment pending |
| ILN application / route authorization | Planned |
| xgr-node v3.1.2 ILN eligibility | Implemented on PoS_3; build/test validation pending |
| XGRChain ↔ XDC bridge | Planned |
| XDC wXGR | Planned |
| XDC wXGR / XDC liquidity | Planned |
| Base → XDC end-to-end ILN route | Planned |

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
