# XGR Interchain — Operations and Rollout

## 1. Scope

This document describes operational procedures for the XGRChain ↔ Base Interchain route.

It covers:

- XGRChain node prerequisites,
- native Interchain route configuration,
- forward and reverse attestation routes,
- native attestation RPC,
- native relayer operation,
- relayer state management,
- forward and reverse runtime separation,
- deployment verification,
- controlled route testing,
- pause and submission controls,
- validator lifecycle operations,
- security boundaries,
- launch gates,
- incident handling.

The first implemented XGR asset route connects:

    XGRChain ↔ Base

with:

    XGRChain: native XGR
    Base:     synthetic XGR / wXGR

Both transfer directions have been validated end-to-end on mainnet.

This does not mean that both directions must remain continuously enabled or that a public bridge is automatically open.

---

# Current baseline

## 2. XGRChain node baseline

Current public node release:

    xgr-node v3.1.1

Release commit:

    1a4844b311fb856cb8c2303a40fa8aa69b560544

Participating XGR validators require a node build containing:

- native Interchain worker,
- native BLS verification support,
- destination-specific Interchain routes,
- read-only attestation RPC.

Native BLS verification precompile:

    0x0000000000000000000000000000000000002040

The Interchain worker is isolated from weighted-IBFT consensus.

External-chain or Interchain failures must not stop:

- XGR block production,
- XGR block validation,
- IBFT finalization,
- chain synchronization,
- validator voting.

---

## 3. Networks

| Network | Chain ID | Hyperlane domain |
| --- | ---: | ---: |
| XGRChain Mainnet | `1643` | `1643` |
| Base | `8453` | `8453` |

XGR RPC:

    https://rpc.xgr.network

Canonical Base RPC is deployment-configurable.

The current non-secret reference configuration uses:

    https://base.publicnode.com

---

# Repository state

## 4. Branch-state warning

The repository currently contains relevant implementation work on:

    feature/native-interchain-registry-v1

while `main` still contains older prelaunch documentation and deployment state.

Before `main` is treated as the sole canonical operational source, synchronize:

- native Interchain contract source,
- deployment manifests,
- runtime configuration examples,
- README,
- architecture documentation,
- operations documentation.

Verified on-chain state and observed runtime state must not be replaced conceptually by stale repository text.

---

# XGR node route configuration

## 5. Canonical non-secret reference

The route configuration reference is:

    runtime/xgr-node-interchain-mainnet.env.example

Production values are loaded into the XGR node environment.

Both directions must be configured explicitly.

Once an explicit:

    XGR_INTERCHAIN_ROUTE_<NAME>_*

route exists, the node no longer relies on the legacy automatically synthesized local-route configuration.

Therefore do not configure only the reverse route while accidentally dropping the forward route.

---

## 6. Forward route — XGRChain → Base

Required route identity:

    XGR_INTERCHAIN_ROUTE_XGR_TO_BASE_DESTINATION=base
    XGR_INTERCHAIN_ROUTE_XGR_TO_BASE_SOURCE_TYPE=local

Destination configuration includes:

    XGR_INTERCHAIN_BASE_CHAIN_ID=8453
    XGR_INTERCHAIN_BASE_DOMAIN=8453
    XGR_INTERCHAIN_BASE_REGISTRY_ADDR=0x70F5752326735b31641f21D174BA035E904Db93c

Current verifier format:

    XGR_INTERCHAIN_BASE_VERIFIER_FORMAT=eip2537

The origin is local XGRChain canonical state.

---

## 7. Reverse route — Base → XGRChain

Required reverse route identity:

    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_DESTINATION=xgr
    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_TYPE=evm
    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_CHAIN_ID=8453
    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_DOMAIN=8453
    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_RPC=https://base.publicnode.com
    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_MAILBOX_ADDR=0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_MERKLE_TREE_HOOK_ADDR=0x19dc38aeae620380430C200a6E990D5Af5480117
    XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_CONFIRMATIONS=12

Reverse destination RegistryV2:

    0x013F2F2f7dB897F941b19C4ab71C5395a48A0292

Reverse verifier format:

    XGR_INTERCHAIN_XGR_VERIFIER_FORMAT=compressed

The reverse route therefore observes confirmed external Base checkpoints and produces destination-bound attestations for XGRChain.

---

# Native attestation RPC

## 8. Forward attestation

Latest completed XGR → Base attestation:

    xgr_getInterchainAttestation("base")

---

## 9. Reverse attestation

Latest completed Base → XGR attestation:

    xgr_getInterchainAttestation("base_to_xgr")

---

## 10. Historical checkpoint attestation

Specific checkpoint lookup:

    xgr_getInterchainAttestationByCheckpoint(
        route,
        setId,
        index,
        root
    )

These RPC methods are read-only.

They cannot:

- request a validator signature,
- force quorum,
- trigger an attestation,
- dispatch a message,
- submit a destination transaction.

Only completed native validator attestations are exposed.

---

# Native relayer runtime

## 11. Runtime model

The current native relayer runs under Node.js.

Implementation:

    runtime/native-relayer/

Process management:

    runtime/manage-relayers.sh

Runtime state:

    runtime/runtime-state/

Forward and reverse routes use independent processes.

They have separate:

- environment files,
- PID files,
- logs,
- persistent indexing state,
- source chains,
- destination chains,
- metadata formats,
- submission controls.

---

## 12. Relayer trust boundary

The relayer is intentionally untrusted.

Its responsibilities are:

- index origin Dispatch events,
- index canonical MerkleTreeHook leaves,
- retrieve completed XGR BLS attestations,
- reconstruct the Hyperlane Merkle proof,
- verify the reconstructed root locally,
- construct destination ISM metadata,
- submit `Mailbox.process()`.

The relayer transaction key pays destination gas.

It does not provide BLS authorization.

Compromise of the relayer gas key cannot by itself produce a valid native XGR quorum proof.

---

# Install and verify native relayer

## 13. Dependencies

From the repository:

    cd runtime/native-relayer
    npm install --no-audit --no-fund

Run tests:

    npm test

Syntax checks:

    node --check index.mjs
    node --check merkle.mjs

Do not start or restart production relayers after a code change unless the relevant tests and syntax checks succeed.

---

# Relayer process management

## 14. Status

From:

    runtime/

check both directions:

    ./manage-relayers.sh status all

Individual routes:

    ./manage-relayers.sh status forward
    ./manage-relayers.sh status reverse

Possible output:

    forward: RUNNING pid=<pid>

or:

    forward: STOPPED

and equivalently for reverse.

---

## 15. Start

Forward:

    ./manage-relayers.sh start forward

Reverse:

    ./manage-relayers.sh start reverse

Both:

    ./manage-relayers.sh start all

Starting a process does not override:

    RELAYER_SUBMIT=false

A running relayer with submission disabled can observe and build state without submitting destination transactions.

Therefore:

    process running

and:

    destination submission enabled

are separate states.

---

## 16. Stop

Forward:

    ./manage-relayers.sh stop forward

Reverse:

    ./manage-relayers.sh stop reverse

Both:

    ./manage-relayers.sh stop all

Stopping a relayer affects message availability only.

It does not revert:

- finalized origin transactions,
- existing attestations,
- already submitted destination transactions,
- deployed route contracts.

---

## 17. Restart

Forward:

    ./manage-relayers.sh restart forward

Reverse:

    ./manage-relayers.sh restart reverse

Both:

    ./manage-relayers.sh restart all

Do not use a blanket restart when only one direction requires intervention unless both directions have been deliberately reviewed.

---

## 18. Logs

Forward:

    ./manage-relayers.sh logs forward

Reverse:

    ./manage-relayers.sh logs reverse

The management script tails the route-specific runtime log.

---

# Forward relayer

## 19. Forward configuration

Forward route:

    XGRChain → Base

Canonical non-secret forward reference:

    runtime/relayer-forward-mainnet.env

Relevant values include:

    XGR_CHAIN_ID=1643
    XGR_DOMAIN=1643
    XGR_MAILBOX=0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79
    XGR_MERKLE_TREE_HOOK=0xeD98Af715b5a72dCD412567eb086d48225CDDACF
    XGR_ATTESTATION_DESTINATION=base
    ATTESTATION_SIGNATURE_FORMAT=eip2537

Destination:

    DESTINATION_CHAIN_ID=8453
    DESTINATION_DOMAIN=8453
    DESTINATION_MAILBOX=0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D

The repository reference currently contains:

    RELAYER_SUBMIT=true

This is a configuration default/reference value.

Actual process status must still be checked using:

    ./manage-relayers.sh status forward

Do not infer that the process is running solely from the environment file.

---

# Reverse relayer

## 20. Reverse configuration

Reverse route:

    Base → XGRChain

Configuration file:

    runtime/.env.relayer.reverse

Reference template:

    runtime/.env.relayer.reverse.example

Relevant route values:

    ATTESTATION_CHAIN_ID=1643
    ATTESTATION_ROUTE=base_to_xgr
    ATTESTATION_SIGNATURE_FORMAT=compressed

Origin:

    ORIGIN_CHAIN_ID=8453
    ORIGIN_DOMAIN=8453
    ORIGIN_MAILBOX=0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
    ORIGIN_MERKLE_TREE_HOOK=0x19dc38aeae620380430C200a6E990D5Af5480117
    ORIGIN_CONFIRMATIONS=12

Destination:

    DESTINATION_CHAIN_ID=1643
    DESTINATION_DOMAIN=1643
    DESTINATION_MAILBOX=0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79

---

## 21. Reverse aggregation metadata

The XGR destination uses a 2-of-2 aggregation ISM.

Reverse metadata configuration:

    DESTINATION_AGGREGATION_MODULE_COUNT=2
    DESTINATION_AGGREGATION_INNER_INDEX=1
    DESTINATION_AGGREGATION_EMPTY_INDEXES=0

Interpretation:

- module `0` is the PausableISM and receives empty metadata,
- module `1` is `XGRNativeInterchainISMV2` and receives native BLS/Merkle metadata.

The relayer must construct metadata accordingly.

---

## 22. Reverse initial-state bootstrap

A fresh reverse relayer must not blindly replay the entire historical Base Hyperlane tree.

Before the first start of a fresh state:

1. determine the current Base head,
2. set:

       ORIGIN_START_BLOCK=<Base head + 1>

3. start the reverse relayer,
4. confirm the log reports successful state bootstrap,
5. only then dispatch a new controlled Base → XGR message.

The relayer snapshots:

    MerkleTreeHook.tree()

at:

    ORIGIN_START_BLOCK - 1

and indexes subsequent leaves.

This prevents an unnecessary full historical replay while preserving correct Merkle state from the chosen bootstrap point.

---

# Current reverse operational state

## 23. State after mainnet E2E validation

The Base → XGR route has completed a controlled end-to-end mainnet validation.

After that validation, reverse automatic submission was deliberately disabled.

Current configuration:

    RELAYER_SUBMIT=false

Current process state:

    reverse: STOPPED

This state was intentionally established with:

    ./manage-relayers.sh stop reverse

followed by disabling submission in:

    .env.relayer.reverse

and verifying:

    ./manage-relayers.sh status reverse

and:

    grep '^RELAYER_SUBMIT=' .env.relayer.reverse

Expected current result:

    reverse: STOPPED
    RELAYER_SUBMIT=false

---

## 24. Meaning of the current state

The current reverse runtime state does **not** mean the Base → XGR protocol path is unimplemented.

The following statements are simultaneously true:

    Base → XGR contracts deployed
    Base → XGR native BLS path operational
    Base → XGR E2E mainnet validation completed
    reverse relayer stopped
    automatic reverse submission disabled

Protocol capability and current runtime availability must be documented separately.

---

## 25. Deliberately re-enabling reverse submission

Do not enable reverse submission as an incidental troubleshooting step.

Before enabling it, verify:

- intended operational approval,
- current RegistryV2 state,
- current reverse ISM state,
- PausableISM state,
- XGR native router inbound state,
- Base synthetic router outbound state,
- reverse relayer persistent state,
- destination gas balance,
- current XGR validator attestation health.

Only after those checks should:

    RELAYER_SUBMIT=true

be intentionally configured.

Then start the reverse process and verify logs before exposing the route to users.

---

# Relayer state and compaction

## 26. Persistent state

Forward and reverse routes maintain separate state files under:

    runtime/runtime-state/

Reverse reference:

    runtime-state/native-relayer-reverse-state.json

Forward reference:

    runtime-state/native-relayer-state.json

Do not delete persistent state casually.

Loss of relayer state can require a controlled re-bootstrap from a known canonical Merkle tree state.

---

## 27. State compaction

The native relayer can compact its accumulated local state back to an on-chain Merkle tree snapshot when no destination-bound messages remain.

Reverse reference configuration:

    RELAYER_COMPACT_AFTER_LEAVES=10000

Compaction must preserve the ability to reconstruct valid proofs for messages that still require processing.

---

# Warp route operations

## 28. XGRChain native router

Network:

    XGRChain 1643

Address:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

Function:

    lock / unlock native XGR

---

## 29. Base synthetic router

Network:

    Base 8453

Address:

    0x3b83687d77170d42feddfe221629cc21e771e021

Function:

    mint / burn synthetic XGR / wXGR

---

## 30. Cross-chain address warning

The XGR native router address:

    0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

is also the BLS verifier address on Base.

The Base synthetic router address:

    0x3b83687d77170d42feDDFe221629cc21e771e021

is also the reverse `XGRNativeInterchainISMV2` address on XGRChain.

Always identify contracts by:

    chain + address

Never perform an administrative transaction based on the address alone.

---

# Forward validation

## 31. XGR → Base E2E validation

The forward route has been validated on mainnet with:

    0.1 XGR

Observed behavior included:

- native XGR locked on XGRChain,
- Hyperlane message created,
- native XGR attestation completed,
- message proof reconstructed,
- Base Mailbox processed the message,
- `0.1` synthetic XGR / wXGR minted.

This validates the complete forward protocol path.

It does not automatically define permanent public availability.

---

# Reverse validation

## 32. Base → XGR E2E validation

The reverse route has also been validated end-to-end on mainnet under controlled conditions.

The validation exercised:

- Base synthetic asset path,
- Base message dispatch,
- confirmed Base checkpoint observation,
- `base_to_xgr` native attestation,
- compressed BLS aggregate verification,
- reverse native relayer,
- XGR destination Mailbox processing,
- 2-of-2 aggregation path,
- native XGR destination router path.

After the test, automatic reverse submission was disabled and the reverse relayer stopped.

---

# Validator lifecycle

## 33. Activation requirements

Native Interchain validator activation requires the configured protocol conditions, including:

- active XGR staking identity,
- matching BLS identity,
- destination Interchain membership authorization,
- candidate BLS possession proof,
- destination transaction gas,
- required destination-native deactivation reserve.

Interchain membership changes are distinct from XGRChain consensus validator-set changes.

---

## 34. Removal

Operational removal is relevant when an Interchain registry member:

- is no longer XGR-staking-active,
- disappears from required eligibility state,
- has a BLS identity mismatch,
- otherwise becomes invalid under the registry rules.

Remaining eligible Interchain validators authorize membership transitions according to the registry protocol.

---

## 35. Historical sets

RegistryV2 preserves historical sets.

Do not delete or invalidate old membership state merely because the current set has advanced.

Historical checkpoints must remain verifiable against the set that originally authorized them.

---

# Gas and reimbursement

## 36. Relayer gas

Forward and reverse relayer accounts require only enough destination-native gas for bounded operational submission.

A relayer wallet should not hold unnecessary asset inventory.

The relayer does not custody bridged XGR as part of its trust role.

---

## 37. Registry lifecycle gas

Validator registry lifecycle transactions can require destination-native gas and reserve handling.

Where the registry implements executor reimbursement, operators should monitor:

    claimableWei

and use:

    claim()

when appropriate.

Do not confuse registry reserve funds with user bridge liquidity.

---

# Monitoring

## 38. XGR node monitoring

Monitor:

- XGR block progression,
- validator health,
- Interchain route configuration,
- completed attestation availability,
- current `setId`,
- signer quorum,
- BLS identity consistency.

Interchain failures must not degrade consensus liveness.

---

## 39. Relayer monitoring

For each direction monitor:

- process state,
- submission enabled/disabled,
- indexed block position,
- Merkle leaf state,
- state bootstrap status,
- attestation availability,
- root match,
- destination transaction submission,
- destination receipt,
- retry behavior,
- gas balance.

Always monitor forward and reverse separately.

---

## 40. Contract monitoring

Monitor live state of:

- Warp routers,
- registry,
- native ISM,
- DomainRoutingISM,
- aggregation ISM,
- PausableISM,
- Mailbox.

Deployment manifests are an inventory.

They are not a substitute for querying live contract state when making operational decisions.

---

# Pause and fail-closed behavior

## 41. Safety principle

The route must fail closed when required security conditions are not satisfied.

Examples include:

- insufficient BLS quorum,
- unknown registry set,
- invalid signer bitmap,
- invalid aggregate signature,
- invalid Merkle proof,
- modified message,
- incorrect origin,
- incorrect destination,
- paused safety module,
- disabled router direction,
- relayer submission disabled.

Do not bypass one security gate to compensate for another component being unavailable.

---

## 42. PausableISM

Reverse traffic is routed through an aggregation that includes:

    PausableISM
    +
    XGRNativeInterchainISMV2

The PausableISM is an operational safety control.

Its state must be verified directly before reverse route activation.

Do not assume its current live state solely from a static document.

---

# Incident handling

## 43. Relayer down

If a relayer stops while chain state remains healthy:

- messages remain finalized on the origin,
- existing attestations remain protocol state,
- delivery is delayed,
- XGRChain consensus is unaffected.

Restore the relayer only after verifying its persistent state and route configuration.

---

## 44. Invalid proof or root mismatch

Do not submit the transaction.

Check:

- origin block,
- Dispatch event,
- MerkleTreeHook leaf sequence,
- local Merkle state,
- attested root,
- checkpoint index,
- set ID.

A root mismatch is a security failure, not something to bypass operationally.

---

## 45. Insufficient BLS quorum

Do not lower verification requirements operationally.

Investigate:

- Interchain validator availability,
- staking eligibility,
- BLS identity consistency,
- route configuration,
- registry membership.

---

## 46. Destination transaction reverted

Determine whether the revert occurred in:

- Mailbox,
- DomainRoutingISM,
- AggregationISM,
- PausableISM,
- native ISM,
- router/recipient.

Do not blindly retry until the revert reason and current route state are understood.

---

## 47. Persistent-state loss

If relayer state is lost:

- stop submission,
- determine a safe canonical bootstrap point,
- reconstruct from known on-chain Merkle state,
- verify proof generation locally,
- resume only after state consistency is established.

Do not begin a reverse relayer from an arbitrary block with an empty tree.

---

# Public-launch gates

## 48. Technical gates

The following major technical milestones have already been demonstrated:

- XGR native Interchain node support,
- forward native attestation,
- reverse external-checkpoint attestation,
- forward destination native ISM,
- reverse RegistryV2 / native ISMV2,
- native relayer,
- deployed XGR native router,
- deployed Base synthetic router,
- XGR → Base mainnet E2E validation,
- Base → XGR mainnet E2E validation.

These completed engineering milestones should not remain documented as future work.

---

## 49. Public-availability gates

Public availability remains a separate decision.

Before intentionally exposing normal user traffic, verify at minimum:

1. intended source and destination router direction states;
2. current PausableISM state;
3. current DomainRoutingISM route;
4. current registry and validator-set state;
5. BLS attestation health;
6. relayer process state;
7. relayer submission setting;
8. relayer gas funding;
9. persistent-state health;
10. route monitoring;
11. failure and pause procedures;
12. public deployment manifest accuracy;
13. public documentation accuracy;
14. user-facing UI availability state.

A successful controlled E2E test does not override these checks.

---

# Secrets

## 50. Never commit

Never commit:

- consensus validator private keys,
- Interchain validator private keys,
- relayer private keys,
- deployer private keys,
- seed phrases,
- wallet exports,
- SSH private keys,
- cloud credentials,
- populated `.env` files,
- production secrets.

Reference configuration should contain:

- public addresses,
- public chain IDs,
- public contract addresses,
- non-secret defaults,
- placeholders for secrets.

---

# Operational state vocabulary

## 51. Use precise status terms

Use these terms consistently:

### `deployed`

Required contract code exists on-chain.

### `configured`

Required contract relationships have been established.

### `attestation-ready`

Native validators can produce the required attestation.

### `E2E validated`

A controlled complete message or asset-transfer path has succeeded.

### `submission disabled`

The relayer may run but will not submit destination transactions.

### `stopped`

The relayer process is not running.

### `operationally enabled`

All intended route components required for delivery are enabled.

### `publicly available`

The route has intentionally been exposed for ordinary user traffic.

These states must not be conflated.

---

# Current operational summary

## 52. XGR → Base

Protocol:

    implemented

Contracts:

    deployed

Asset route:

    deployed

Mainnet E2E:

    validated

Reference forward submission configuration:

    RELAYER_SUBMIT=true

Live forward process status:

    verify operationally with manage-relayers.sh

---

## 53. Base → XGR

Protocol:

    implemented

RegistryV2 / ISMV2:

    deployed

Asset route:

    deployed

Mainnet E2E:

    validated

Automatic reverse submission:

    disabled

Current reverse configuration:

    RELAYER_SUBMIT=false

Current reverse process:

    STOPPED

---

## 54. Design principle

Operations must keep these layers separate:

    protocol implemented
            │
            ▼
    contracts deployed
            │
            ▼
    route configured
            │
            ▼
    E2E validated
            │
            ▼
    runtime enabled
            │
            ▼
    public availability

Advancing one layer does not automatically advance the next.

That distinction is particularly important for the Base → XGR route, which is technically implemented and mainnet-validated while reverse automatic submission is currently deliberately disabled.
