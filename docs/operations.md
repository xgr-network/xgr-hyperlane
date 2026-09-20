# Operations and rollout

## XGR 3.0 prerequisite

All participating XGR validator nodes must run the XGR 3.0 node release that
contains the native interchain worker and read-only attestation RPC.

The interchain worker is isolated from weighted-IBFT consensus. Destination
outages must never stop XGR block production, validation, finalization or sync.

## XGR node environment

For XGRChain mainnet:

```bash
XGR_INTERCHAIN_ORIGIN_MAILBOX_ADDR=0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79
XGR_INTERCHAIN_ORIGIN_MERKLE_TREE_HOOK_ADDR=0xeD98Af715b5a72dCD412567eb086d48225CDDACF
```

Each destination uses:

```text
XGR_INTERCHAIN_<NAME>_CHAIN_ID
XGR_INTERCHAIN_<NAME>_DOMAIN
XGR_INTERCHAIN_<NAME>_REGISTRY_ADDR
XGR_INTERCHAIN_<NAME>_RPC
XGR_INTERCHAIN_<NAME>_DEACTIVATION_RESERVE_WEI
XGR_INTERCHAIN_<NAME>_CONFIRMATIONS
XGR_INTERCHAIN_<NAME>_MEMBERSHIP_VALIDITY_SECONDS
XGR_INTERCHAIN_<NAME>_EXECUTOR_STEP_DELAY_SECONDS
```

## Bootstrap sequence

For the first Base deployment:

1. verify Base supports every EIP-2537 precompile used by
   `XGRInterchainBLSVerifier`;
2. choose the initial XGR interchain validators;
3. collect each validator address, compressed BLS key, EIP-2537 BLS key and
   bootstrap possession proof from XGR 3.0 tooling;
4. choose the minimum deactivation reserve and executor reimbursement cap;
5. deploy the BLS verifier;
6. deploy the registry with the complete initial set and reserve funding;
7. deploy `XGRNativeInterchainISM`;
8. configure every participating XGR node with the Base registry address and
   destination policy;
9. verify the nodes produce a completed Base attestation;
10. configure the Base test recipient/router to return the native ISM.

## Native attestation RPC

Latest completed attestation:

```text
xgr_getInterchainAttestation("base")
```

Archived checkpoint attestation:

```text
xgr_getInterchainAttestationByCheckpoint("base", setId, index, root)
```

The RPC is read-only. It cannot request or trigger a signature.

A public object-store publisher is optional for redundancy; it is no longer a
security or operational requirement because independent relayers can read
completed attestations from any XGR 3.0 RPC endpoint.

## Relayer

The production runtime no longer starts a Hyperlane validator.

`runtime/native-relayer` uses the existing Hyperlane Mailbox and MerkleTreeHook,
but obtains security metadata from XGR 3.0 native attestations.

The relayer key only pays destination gas. Compromise of that key cannot produce
a valid XGR BLS quorum proof.

Before starting:

```bash
cd runtime
cp .env.relayer.example .env.relayer
# fill destination gas key and RPC values
docker compose up -d --build
```

The relayer reconstructs the 32-level Hyperlane Merkle proof and checks that its
computed root exactly equals the attested root before submitting the destination
transaction.

## Validator lifecycle operations

Activation requires:

- active XGR staking identity;
- matching BLS identity;
- current interchain-set two-thirds authorization;
- candidate BLS possession proof;
- destination transaction gas;
- full destination-native deactivation reserve.

Forced removal is triggered operationally when a registry member is no longer
XGR-staking-active, disappears, or its BLS identity no longer matches. Remaining
eligible interchain validators authorize the removal. The executor initially
pays destination gas and receives pull-credit reimbursement from the target's
locked reserve.

Operators must maintain a small destination-native gas balance and periodically
withdraw non-zero `claimableWei` with `claim()`.

## Launch gates

Do not expose the bridge to users until all of the following are evidenced:

1. XGR 3.0 is running on the participating validator nodes;
2. the canonical XGR Mailbox / MerkleTreeHook relationship is verified and all
   supported dispatches necessarily enter the signed tree;
3. destination EIP-2537 precompiles are verified on the live chain;
4. production BLS verifier is deployed and deterministic XGR vectors pass;
5. registry is bootstrapped with the intended initial validator set and
   reserves;
6. native ISM is deployed against that registry and canonical XGR origin
   context;
7. a completed two-thirds native attestation is readable over XGR RPC;
8. native relayer indexes XGR without Merkle history gaps;
9. minimal XGR -> Base message delivery succeeds;
10. invalid proof, stale setId, insufficient bitmap and modified message tests
    all fail closed on Base;
11. validator ADD, voluntary REMOVE and forced REMOVE are tested;
12. executor reimbursement and `claim()` are tested;
13. final deployment manifests contain the verified addresses;
14. Warp routers are deployed only after their separate security gate;
15. public UI remains disabled until the complete route is intentionally opened.

## Secrets

Never commit validator keys, relayer/deployer keys, SSH keys, cloud credentials,
seed phrases, wallet exports or populated `.env` files.
