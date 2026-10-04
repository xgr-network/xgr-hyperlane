# XGR Interchain — Operations and Rollout

## 1. Scope

This document describes operation of XGR Interchain routes, destination-scoped validator membership, native checkpoint attestations, native relayers and the XGRChain ↔ Base asset route.

The first production route connects:

    XGRChain ↔ Base

with native XGR on XGRChain and synthetic XGR / wXGR on Base.

Both transfer directions have been validated end-to-end on mainnet. E2E validation does not by itself mean that every direction is continuously enabled or publicly exposed.

---

## 2. Current node baseline

Current public XGRChain node baseline:

    xgr-node v3.1.1

Release commit:

    1a4844b311fb856cb8c2303a40fa8aa69b560544

Required native Interchain capabilities include:

- destination-specific validator registries,
- route-specific checkpoint observation,
- native BLS checkpoint aggregation,
- read-only attestation RPC,
- destination membership quorum transitions.

Native BLS verification precompile on XGRChain:

    0x0000000000000000000000000000000000002040

The Interchain worker is outside the weighted-IBFT consensus-critical path.

---

## 3. Networks

| Network | Chain ID | Hyperlane domain |
| --- | ---: | ---: |
| XGRChain Mainnet | `1643` | `1643` |
| Base | `8453` | `8453` |

XGR RPC:

    https://rpc.xgr.network

Base reference RPC:

    https://base.publicnode.com

---

# Validator membership model

## 4. Membership is destination-scoped

The command:

    xgrchain ibft interchain set-active --chain <destination> --active <true|false> --data-dir <data-dir>

changes membership in exactly one configured **destination registry**.

Examples:

    xgrchain ibft interchain set-active --chain base --active true --data-dir ./data

joins the Base destination registry used by XGR-origin routes to Base.

And:

    xgrchain ibft interchain set-active --chain xgr --active true --data-dir ./data

joins the XGRChain destination RegistryV2.

The command is intentionally destination-scoped rather than route-scoped.

---

## 5. Multiple routes can share one destination membership

Checkpoint routes are independently named and independently configured.

Multiple routes may point to the same destination:

    xgr_to_base
        source      = local XGRChain
        destination = base

    base_to_xgr
        source      = Base
        destination = xgr

Future examples:

    polygon_to_xgr
        source      = Polygon
        destination = xgr

    arbitrum_to_xgr
        source      = Arbitrum
        destination = xgr

A validator that is active in the `xgr` destination registry does **not** need a second membership transition for every external source route.

The same XGR destination membership can secure all configured routes whose destination is `xgr`.

Each route still has independent:

- source chain ID and Hyperlane domain,
- source RPC,
- Mailbox,
- MerkleTreeHook,
- confirmation delay,
- checkpoint root/index,
- attestation stream,
- relayer state.

Therefore:

    membership scope = destination
    checkpoint scope = route

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

Membership is therefore quorum-authorized by the XGR Interchain validator set. It is not an administrator-only registration path.

---

# Route configuration

## 7. Canonical node reference

Reference configuration:

    runtime/xgr-node-interchain-mainnet.env.example

Destination configuration and checkpoint-route configuration are deliberately separate.

A destination defines registry membership and destination verification parameters.

A route binds:

    unique route name
        +
    source checkpoint context
        +
    destination

When explicit `XGR_INTERCHAIN_ROUTE_<NAME>_*` configuration is present, all required routes should be configured explicitly.

---

## 8. Forward route — XGRChain → Base

Destination:

    base

Attestation route:

    xgr_to_base

The current production-compatible alias used by existing forward runtime/RPC is:

    base

Forward verification format:

    eip2537

Base destination registry:

    0x70F5752326735b31641f21D174BA035E904Db93c

Base destination native ISM:

    0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc

The deployed forward stack uses the V1 registry/ISM generation. V1 is still XGR-native BLS validator security.

---

## 9. Reverse route — Base → XGRChain

Destination:

    xgr

Route:

    base_to_xgr

Source:

    Chain ID / domain: 8453
    Mailbox: 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
    MerkleTreeHook: 0x19dc38aeae620380430C200a6E990D5Af5480117
    confirmations: 12

XGR destination RegistryV2:

    0x013F2F2f7dB897F941b19C4ab71C5395a48A0292

XGR destination native ISMV2:

    0x3b83687d77170D42feDDFe221629cc21e771E021

Reverse verifier format:

    compressed

V2 preserves historical validator-set snapshots and separates membership-origin identity from external checkpoint origin.

---

# Native attestation RPC

## 10. Latest attestation

Forward:

    xgr_getInterchainAttestation("base")

Reverse:

    xgr_getInterchainAttestation("base_to_xgr")

Future routes follow the route name, for example:

    xgr_getInterchainAttestation("polygon_to_xgr")

Checkpoint-specific lookup:

    xgr_getInterchainAttestationByCheckpoint(
        route,
        setId,
        index,
        root
    )

These methods are read-only and expose only completed native quorum attestations.

---

# Native relayer

## 11. Runtime

Implementation:

    runtime/native-relayer/

Process management:

    runtime/manage-relayers.sh

Forward and reverse use independent process state, logs and persisted Merkle/indexing state.

The relayer is untrusted. It provides availability and destination transaction submission, not security authorization.

---

## 12. Fail-closed submission default

The native relayer defaults to:

    RELAYER_SUBMIT=false

unless submission is explicitly enabled.

Production forward configuration explicitly sets:

    RELAYER_SUBMIT=true

The reverse runtime currently explicitly sets:

    RELAYER_SUBMIT=false

A running process with submission disabled may still index state and statically validate the destination `Mailbox.process()` path without changing chain state.

---

## 13. Process commands

From `runtime/`:

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

Process state and submission state are separate.

---

## 14. Reverse runtime state

After successful controlled Base → XGR mainnet E2E validation:

    reverse: STOPPED
    RELAYER_SUBMIT=false

This does not mean the reverse protocol path is incomplete.

It means:

    contracts deployed                 yes
    native BLS attestation path        yes
    reverse E2E validation             yes
    automatic reverse submission       no
    reverse relayer process running    no

---

# Warp asset route

## 15. Routers

XGRChain native router:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

Base synthetic XGR / wXGR router:

    0x3b83687d77170d42feddfe221629cc21e771e021

Forward semantics:

    native XGR lock → synthetic XGR mint

Reverse semantics:

    synthetic XGR burn → native XGR unlock

The route is a bridge, not an AMM swap.

---

## 16. Cross-chain address collisions

Always identify contracts by chain plus address.

The address:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

is the native XGR router on XGRChain and the XGR BLS verifier on Base.

The address:

    0x3b83687d77170D42feDDFe221629cc21e771E021

is XGRNativeInterchainISMV2 on XGRChain and the synthetic XGR router on Base.

---

# Validation evidence

## 17. XGR → Base

Controlled mainnet E2E transfer:

    0.1 XGR

Origin transaction:

    0x08671a6c4bc10ab8af4fda602f8d09a393f17212b3e4bf729002c92ce1e50613

Message ID:

    0x1b73073ea020bbebbd716a68a58f11a10f8c0d712ccbd38d41ed1dfc53550ad7

Base process transaction:

    0x686e93af92e2a14dee061b33042b62683bd51dcc7069374339d778c54403b90e

The test demonstrated lock, attestation, proof, process and mint.

---

## 18. Base → XGRChain

Controlled mainnet E2E transfer:

    0.01 XGR

Base origin transaction:

    0x7a1b61b106e4d631ac599af322cdd7a54510e110ce747076fd934880e27edc89

Message ID:

    0x47919e62a3811e192d5bfe3c1b70f1309675c6d8f8c2b2ee3a439358276c2160

XGR destination transaction:

    0x968503696b8a2eebd2c3701fc4c25ef7bde650883e1d81c63a472b0587f333ec

Destination block:

    11140781

The XGR receipt succeeded and emitted the router delivery/unlock path.

---

# Operational safety

## 19. Live state must be queried

Do not infer route availability from deployed bytecode or a static manifest.

Before enabling user traffic, verify live:

- router direction gates,
- PausableISM state,
- DomainRoutingISM mapping,
- current registry set and quorum,
- attestation production,
- relayer process state,
- `RELAYER_SUBMIT`,
- RPC health,
- relayer gas balance,
- persistent relayer state.

---

## 20. Failure behavior

The route must fail closed for:

- insufficient quorum,
- unknown validator set,
- invalid signer bitmap,
- invalid aggregate signature,
- invalid Merkle proof,
- wrong origin or destination,
- paused safety module,
- disabled router direction,
- disabled relayer submission.

Never weaken cryptographic or routing checks to recover availability.

---

# Public-launch checklist

## 21. Before exposing a public bridge

Verify:

1. source and destination router gates;
2. PausableISM state;
3. DomainRoutingISM configuration;
4. registry membership and quorum;
5. native attestation health;
6. relayer process state;
7. explicit submission state;
8. gas funding;
9. persisted relayer state;
10. route monitoring;
11. pause/recovery procedures;
12. current deployment manifests;
13. current public documentation;
14. user-facing status reporting.

E2E validation is necessary evidence, not automatic public-launch authorization.

---

# Secrets

## 22. Never commit

Never commit:

- consensus validator private keys,
- Interchain validator private keys,
- relayer private keys,
- deployer private keys,
- seed phrases,
- wallet exports,
- SSH private keys,
- cloud credentials,
- populated production secret files.

Public configuration should contain only public chain metadata, public addresses, non-secret defaults and explicit placeholders.
