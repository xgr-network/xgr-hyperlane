# XGR Interchain — Operations and Rollout

**Document ID:** XGR-INTERCHAIN-OPERATIONS  
**Last updated:** 2026-10-04  
**Audience:** Node operators, validator operators, Interchain operators, infrastructure engineers, integrators, auditors  
**Implementation status:** Mainnet  
**XGRChain baseline:** `xgr-node v3.1.1`  
**Interchain implementation:** `xgr-network/xgr-hyperlane`, branch `main`  
**Scope:** Mainnet operation of XGR Interchain validator membership, checkpoint attestations, native relayers and the XGRChain ↔ Base asset route

---

## 1. Scope

This document describes mainnet operation of:

- XGR Interchain routes,
- destination-scoped validator membership,
- native checkpoint attestations,
- native relayers,
- route safety controls,
- the XGRChain ↔ Base asset bridge.

The first production route connects:

```text
XGRChain ↔ Base
```

with:

```text
XGRChain: native XGR
Base:     wXGR
```

Both transfer directions are:

```text
Mainnet
deployed
cryptographically configured
E2E validated
operationally enabled
publicly available
```

Public bridge:

```text
https://bridge.xgr.network
```

Dynamic process and contract state must still be verified live during operation.

---

## 2. Current node baseline

Current public XGRChain node baseline:

```text
xgr-node v3.1.1
```

Release commit:

```text
1a4844b311fb856cb8c2303a40fa8aa69b560544
```

Required native Interchain capabilities include:

- destination-specific validator registries,
- route-specific checkpoint observation,
- native BLS checkpoint aggregation,
- read-only attestation RPC,
- destination membership quorum transitions,
- external-source checkpoint observation,
- compressed BLS verification support.

Native BLS12-381 verification precompile on XGRChain:

```text
0x0000000000000000000000000000000000002040
```

The Interchain worker is outside the weighted-IBFT consensus-critical path.

Therefore an external-chain or relayer outage must not stop XGRChain consensus.

---

## 3. Networks

| Network | Chain ID | Hyperlane domain | Status |
| --- | ---: | ---: | --- |
| XGRChain | `1643` | `1643` | Mainnet |
| Base | `8453` | `8453` | Mainnet |

XGRChain public RPC:

```text
https://rpc.xgr.network
```

Base production RPC used by the current Interchain runtime:

```text
https://base-rpc.publicnode.com
```

XGRChain explorer:

```text
https://explorer.xgr.network
```

Base explorer:

```text
https://basescan.org
```

---

# Validator membership model

## 4. Membership is destination-scoped

The command:

```text
xgrchain ibft interchain set-active --chain <destination> --active <true|false> --data-dir <data-dir>
```

changes membership in exactly one configured destination registry.

Example:

```text
xgrchain ibft interchain set-active --chain base --active true --data-dir ./data
```

joins the Base destination registry used by XGR-origin routes whose destination is Base.

Example:

```text
xgrchain ibft interchain set-active --chain xgr --active true --data-dir ./data
```

joins the XGRChain destination RegistryV2.

The command is intentionally destination-scoped rather than route-scoped.

---

## 5. Multiple routes can share one destination membership

Checkpoint routes are independently named and independently configured.

Multiple routes may point to the same destination.

Current routes include:

```text
XGRChain → Base
destination = base
attestation route = base
```

and:

```text
Base → XGRChain
destination = xgr
attestation route = base_to_xgr
```

Future examples may include:

```text
polygon_to_xgr
arbitrum_to_xgr
```

A validator that is active in the `xgr` destination registry does not need a separate membership transition for every external source route.

The same XGR destination membership can secure configured routes whose destination is `xgr`.

Each route still maintains independent:

- source chain ID,
- source Hyperlane domain,
- source RPC,
- Mailbox,
- MerkleTreeHook,
- confirmation delay,
- checkpoint root and index,
- attestation stream,
- relayer indexing state.

Therefore:

```text
membership scope = destination
checkpoint scope = route
```

---

## 6. What the XGR node does during membership activation

For each destination activation request, the running XGR validator node:

1. verifies that the local validator exists in XGR PoS;
2. requires active XGR PoS state for activation;
3. verifies that the local BLS public key matches canonical XGR staking state;
4. reads the destination registry and current `setId`;
5. constructs the membership payload;
6. signs it with the existing XGR validator BLS key;
7. collects the current unweighted two-thirds Interchain quorum over XGR P2P;
8. submits the destination `applyMembership()` transaction;
9. waits for the configured destination confirmations;
10. reads the final destination registry state back;
11. verifies the requested active state and exact `setId` transition.

Membership is therefore quorum-authorized by the XGR Interchain validator set.

It is not merely an administrator-only registration path.

---

# Route configuration

## 7. Canonical node reference

Reference configuration:

```text
runtime/xgr-node-interchain-mainnet.env.example
```

Destination configuration and checkpoint-route configuration are deliberately separate.

A destination defines:

- registry membership,
- destination verification parameters,
- membership identity.

A route binds:

```text
unique route name
+
source checkpoint context
+
destination
```

When explicit:

```text
XGR_INTERCHAIN_ROUTE_<NAME>_*
```

configuration is present, all required production routes should be configured explicitly.

---

## 8. Forward route — XGRChain → Base

Destination:

```text
base
```

Current production attestation route identifier:

```text
base
```

Source:

```text
XGRChain
Chain ID: 1643
Domain:   1643
```

Destination:

```text
Base
Chain ID: 8453
Domain:   8453
```

Forward verification format:

```text
eip2537
```

Base destination registry:

```text
0x70F5752326735b31641f21D174BA035E904Db93c
```

Base destination native ISM:

```text
0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc
```

Base BLS verifier:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

The deployed forward stack uses the V1 registry/ISM generation.

V1 still uses XGR-native BLS validator security.

Validated forward configuration includes:

```text
setId = 3
quorum = 2
```

Current registry membership must be read from live chain state when required.

---

## 9. Reverse route — Base → XGRChain

Destination:

```text
xgr
```

Route:

```text
base_to_xgr
```

Source:

```text
Chain:          Base
Chain ID:       8453
Domain:         8453
Mailbox:        0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
MerkleTreeHook: 0x19dc38aeae620380430C200a6E990D5Af5480117
Confirmations:  12
```

XGR destination RegistryV2:

```text
0x013F2F2f7dB897F941b19C4ab71C5395a48A0292
```

XGR destination native ISMV2:

```text
0x3b83687d77170D42feDDFe221629cc21e771E021
```

Reverse AggregationISM:

```text
0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e
```

Reverse PausableISM:

```text
0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA
```

Reverse verifier format:

```text
compressed
```

Validated reverse configuration:

```text
setId = 1
validators = 3
quorum = 2
```

V2 preserves historical validator-set snapshots and separates membership-origin identity from external checkpoint origin.

---

# Native attestation RPC

## 10. Latest attestation

Forward:

```text
xgr_getInterchainAttestation("base")
```

Reverse:

```text
xgr_getInterchainAttestation("base_to_xgr")
```

Future routes follow their configured route names, for example:

```text
xgr_getInterchainAttestation("polygon_to_xgr")
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

They expose only completed native quorum attestations.

They do not:

- request validator signatures,
- force validator participation,
- create quorum,
- submit destination transactions.

---

# Native relayer

## 11. Runtime

Implementation:

```text
runtime/native-relayer/
```

Process management:

```text
runtime/manage-relayers.sh
```

Forward and reverse use independent:

- process state,
- logs,
- environment configuration,
- submission state,
- persisted Merkle/indexing state.

The relayer is untrusted for message validity.

It provides:

```text
availability
+
destination transaction submission
```

not:

```text
security authorization
```

---

## 12. Fail-closed submission default

The native relayer software defaults to:

```text
RELAYER_SUBMIT=false
```

unless submission is explicitly enabled.

This is a fail-closed software default.

The production configurations explicitly enable submission.

Forward production state:

```text
RELAYER_SUBMIT=true
```

Reverse production state:

```text
RELAYER_SUBMIT=true
```

A non-production or recovery configuration may deliberately set:

```text
RELAYER_SUBMIT=false
```

to allow indexing or validation without submitting destination transactions.

The software default and the production runtime state are therefore intentionally different concepts.

---

## 13. Process commands

From `runtime/`:

```text
./manage-relayers.sh status all
./manage-relayers.sh status forward
./manage-relayers.sh status reverse

./manage-relayers.sh start forward
./manage-relayers.sh start reverse

./manage-relayers.sh stop forward
./manage-relayers.sh stop reverse

./manage-relayers.sh restart forward
./manage-relayers.sh restart reverse

./manage-relayers.sh logs forward
./manage-relayers.sh logs reverse
```

Process state and submission state are separate.

For example:

```text
process RUNNING
```

does not by itself prove:

```text
RELAYER_SUBMIT=true
```

Both should be checked.

---

## 14. Current production relayer state

At the current mainnet documentation baseline:

### Forward

```text
route: XGRChain → Base
process: RUNNING
RELAYER_SUBMIT=true
status: Mainnet
```

### Reverse

```text
route: Base → XGRChain
process: RUNNING
RELAYER_SUBMIT=true
status: Mainnet
```

The reverse production origin RPC is:

```text
ORIGIN_RPC_URL=https://base-rpc.publicnode.com
```

Both directions are publicly enabled.

Operational state remains dynamic and must be monitored live.

A process restart, host outage, RPC outage or insufficient destination gas balance can affect availability without changing the deployed protocol architecture.

---

# Warp asset route

## 15. Routers

XGRChain native router:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

Base official wXGR / synthetic router:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

Forward semantics:

```text
native XGR lock
→
wXGR mint
```

Reverse semantics:

```text
wXGR burn
→
native XGR unlock
```

The nominal bridge representation is:

```text
1 XGR ↔ 1 wXGR
```

before applicable transaction and routing fees.

The bridge conversion itself is not an AMM swap.

DEX liquidity for wXGR is a separate application layer.

---

## 16. Cross-chain address collisions

Always identify contracts by chain plus address.

The address:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

is:

- **XGRChain:** native XGR router
- **Base:** XGR Interchain BLS verifier

The address:

```text
0x3b83687d77170d42feDDFe221629cc21e771e021
```

is:

- **XGRChain:** XGRNativeInterchainISMV2
- **Base:** official wXGR / synthetic XGR router

Therefore the correct identity is:

```text
chain ID + address
```

not the address alone.

---

# Validation evidence

## 17. XGRChain → Base

Controlled mainnet E2E transfer:

```text
0.1 XGR
```

Origin transaction:

```text
0x08671a6c4bc10ab8af4fda602f8d09a393f17212b3e4bf729002c92ce1e50613
```

Message ID:

```text
0x1b73073ea020bbebbd716a68a58f11a10f8c0d712ccbd38d41ed1dfc53550ad7
```

Base process transaction:

```text
0x686e93af92e2a14dee061b33042b62683bd51dcc7069374339d778c54403b90e
```

The test demonstrated:

- native XGR lock,
- message dispatch,
- checkpoint attestation,
- BLS quorum,
- Merkle proof,
- destination verification,
- Mailbox processing,
- wXGR mint.

---

## 18. Base → XGRChain

Controlled mainnet E2E transfer:

```text
0.01 wXGR
```

Base origin transaction:

```text
0x7a1b61b106e4d631ac599af322cdd7a54510e110ce747076fd934880e27edc89
```

Message ID:

```text
0x47919e62a3811e192d5bfe3c1b70f1309675c6d8f8c2b2ee3a439358276c2160
```

XGR destination transaction:

```text
0x968503696b8a2eebd2c3701fc4c25ef7bde650883e1d81c63a472b0587f333ec
```

Destination block:

```text
11140781
```

Observed destination gas use:

```text
461505
```

The successful XGR receipt demonstrated:

- wXGR burn,
- Base message dispatch,
- confirmed checkpoint observation,
- reverse BLS attestation,
- native BLS verification,
- Merkle verification,
- XGR Mailbox processing,
- native XGR unlock.

---

# Operational safety

## 19. Live state must be queried

Do not infer current route availability solely from deployed bytecode, README text or a static manifest.

For forward production operation, verify as required:

```text
XGR router outboundEnabled
Base destination router state
forward relayer process
forward RELAYER_SUBMIT
attestation health
RPC health
relayer gas balance
persistent relayer state
```

For reverse production operation, verify as required:

```text
Base router outboundEnabled
XGR router inboundEnabled
PausableISM paused
DomainRoutingISM mapping
reverse relayer process
reverse RELAYER_SUBMIT
attestation health
RPC health
relayer gas balance
persistent relayer state
```

Current deployed architecture does not eliminate the need for runtime monitoring.

---

## 20. Reverse safety checks

The reverse Base → XGRChain path includes:

```text
DomainRoutingISM
        ↓
2-of-2 AggregationISM
        ├── PausableISM
        └── XGRNativeInterchainISMV2
```

Both aggregation modules must accept the message.

Production availability therefore requires the PausableISM to permit processing in addition to successful cryptographic verification.

The pause state must always be read live.

---

## 21. Failure behavior

The route must fail closed for:

- insufficient quorum,
- unknown validator set,
- invalid signer bitmap,
- invalid aggregate signature,
- invalid Merkle proof,
- wrong checkpoint origin,
- wrong destination,
- invalid message,
- paused safety module,
- disabled router direction,
- disabled relayer submission.

Never weaken cryptographic, membership or routing checks to recover availability.

A temporary availability failure is preferable to bypassing a security condition.

---

# Mainnet operational checklist

## 22. Normal production checks

For the active public bridge, operators should verify:

1. source and destination RPC health;
2. source and destination router gates;
3. PausableISM state for reverse delivery;
4. DomainRoutingISM configuration;
5. current registry membership and quorum;
6. native attestation progress;
7. relayer process state;
8. explicit `RELAYER_SUBMIT` state;
9. destination gas funding;
10. persistent relayer indexing state;
11. recent message processing;
12. public bridge route status.

The existence of deployed contracts alone is not an availability check.

---

## 23. Forward production checklist

Forward route:

```text
XGRChain → Base
```

Verify:

```text
XGR source RPC healthy
XGR native router outbound enabled
XGR MerkleTreeHook progressing
base attestation progressing
forward relayer RUNNING
RELAYER_SUBMIT=true
Base RPC healthy
relayer ETH balance sufficient
Base Mailbox processing available
Base destination ISM configured
Base wXGR router available
```

---

## 24. Reverse production checklist

Reverse route:

```text
Base → XGRChain
```

Verify:

```text
Base source RPC healthy
Base wXGR router outbound enabled
Base Mailbox accessible
Base MerkleTreeHook progressing
12-block confirmation policy applied
base_to_xgr attestation progressing
reverse relayer RUNNING
RELAYER_SUBMIT=true
XGR RPC healthy
relayer XGR balance sufficient
DomainRoutingISM configured
PausableISM not paused
AggregationISM configured 2-of-2
XGRNativeInterchainISMV2 available
XGR native router inbound enabled
```

---

# Recovery and controlled shutdown

## 25. Disable transaction submission

To stop one relayer from submitting destination transactions while preserving deployed contracts, set:

```text
RELAYER_SUBMIT=false
```

and restart or stop the corresponding process according to the operational objective.

This affects delivery availability.

It does not remove:

- deployed contracts,
- validator registries,
- historical attestations,
- completed transfers.

---

## 26. Stop a route relayer

Examples:

```text
./manage-relayers.sh stop forward
```

or:

```text
./manage-relayers.sh stop reverse
```

This stops the selected off-chain delivery process.

It does not alter XGRChain consensus.

It does not disable the opposite route process.

---

## 27. Restart a route relayer

Examples:

```text
./manage-relayers.sh restart forward
```

or:

```text
./manage-relayers.sh restart reverse
```

After restart, verify:

```text
process state
submission state
RPC connectivity
gas balance
restored persistent state
latest indexed block
latest attestation
recent relay logs
```

Do not treat a successful process launch as sufficient proof that delivery is healthy.

---

## 28. Emergency reverse pause

The reverse XGR destination stack contains a PausableISM:

```text
0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA
```

This is a separate on-chain safety control.

Pausing the module changes destination message acceptance and is materially different from stopping a relayer.

Operational controls should distinguish:

```text
stop relayer
```

from:

```text
disable submission
```

from:

```text
disable router direction
```

from:

```text
pause destination security module
```

These actions operate at different layers.

---

# Monitoring

## 29. What should be monitored

Production monitoring should cover at least:

- XGRChain RPC availability,
- Base RPC availability,
- XGRChain block progress,
- Base block progress,
- XGR Interchain attestation progress,
- registry state,
- router gate state,
- PausableISM state,
- relayer processes,
- relayer submission flags,
- relayer gas balances,
- message backlog,
- relay failures,
- destination transaction receipts,
- public bridge availability.

---

## 30. Relayer logs

Forward:

```text
./manage-relayers.sh logs forward
```

Reverse:

```text
./manage-relayers.sh logs reverse
```

Operators should distinguish:

```text
indexing activity
```

from:

```text
relay submission
```

and from:

```text
successful destination processing
```

A healthy indexing loop does not necessarily prove successful message delivery.

---

# Deployment and runtime source of truth

## 31. Static deployment state

Canonical deployed component inventory is maintained under:

```text
deployments/
```

The deployment documentation is maintained in:

```text
docs/DEPLOYMENTS.md
```

Static deployment data includes:

- chain identity,
- contract address,
- deployment transaction,
- deployment block,
- configuration relationships.

---

## 32. Dynamic runtime state

Dynamic runtime state includes:

- relayer process status,
- `RELAYER_SUBMIT`,
- RPC connectivity,
- relayer balance,
- current indexed block,
- pending messages,
- current pause state,
- current router gate state.

Dynamic state must not be inferred from static deployment files.

---

## 33. Public specification boundary

Public protocol-level XGR Interchain documentation is maintained in:

```text
https://github.com/xgr-network/XGR/tree/main/docs/interchain
```

Current public specification set:

```text
XGR_INTERCHAIN_Overview.md
XGR_INTERCHAIN_Security_Model.md
XGR_INTERCHAIN_Asset_Bridge.md
XGR_INTERCHAIN_Deployment_Reference.md
```

This repository remains the implementation and operational source for:

- contracts,
- deployment manifests,
- relayer runtime,
- operational configuration,
- implementation-specific procedures.

---

# Public bridge

## 34. Production bridge

Public bridge:

```text
https://bridge.xgr.network
```

Current production route:

```text
XGRChain ↔ Base
```

Supported asset conversion:

```text
XGR ↔ wXGR
```

Forward:

```text
native XGR
→
wXGR
```

Reverse:

```text
wXGR
→
native XGR
```

The user signs the source transaction using the user's own wallet.

The relayer does not possess or require the user's private key.

---

## 35. Public availability model

The production bridge must not derive route availability merely from the presence of contract bytecode.

Availability depends on live operational conditions.

A route may temporarily become unavailable because of:

- RPC outage,
- relayer outage,
- insufficient destination gas balance,
- missing validator quorum,
- pause activation,
- router gate change,
- destination network disruption.

Therefore:

```text
Mainnet
```

describes the deployed production environment.

It does not mean that individual infrastructure components can never experience temporary outages.

---

# Secrets

## 36. Never commit

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

Public configuration should contain only:

- public network metadata,
- public contract addresses,
- non-secret defaults,
- explicit placeholders.

---

# Update rule

## 37. Documentation updates

After a production deployment or architecture/configuration change, update where applicable:

- network / chain ID,
- component,
- contract address,
- deployment transaction,
- deployment block,
- source branch / commit,
- owner or administration relationship,
- route configuration,
- security-module configuration,
- route-direction state,
- E2E transaction/message evidence,
- runtime reference configuration,
- public documentation.

Dynamic runtime events such as an ordinary process restart do not require changing the static protocol architecture documentation.

---

## 38. Mainnet status summary

| Component | Current production status |
| --- | --- |
| XGRChain | Mainnet |
| Base | Mainnet |
| XGR native Interchain support | Mainnet |
| Forward validator security | Mainnet |
| Reverse validator security | Mainnet |
| Native BLS verification | Mainnet |
| XGR native router | Mainnet |
| Base wXGR router | Mainnet |
| XGR → Base | Mainnet / E2E validated / public |
| Base → XGRChain | Mainnet / E2E validated / public |
| Forward relayer | Running / submission enabled |
| Reverse relayer | Running / submission enabled |
| Public bridge | Mainnet |

The production XGRChain ↔ Base route is fully deployed in both directions.

XGRChain consensus remains independent from Interchain relayer and external-chain availability.

The relayer provides delivery.

The Interchain validator quorum provides authorization.

The destination security module verifies authorization and message inclusion.

The asset routers enforce lock/mint and burn/unlock semantics.
