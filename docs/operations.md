# Operations and rollout

## XGR 3.0 prerequisite

All participating XGR validator nodes must run the XGR 3.0 node release that
contains the native interchain worker and read-only attestation RPC.

The interchain worker is isolated from weighted-IBFT consensus. Destination
outages must never stop XGR block production, validation, finalization or sync.

## XGR node environment

The canonical non-secret mainnet reference is
`runtime/xgr-node-interchain-mainnet.env.example`.

The production nodes load these values from `/etc/xgrchain/node.conf`. The
node process is managed by `/home/xgradmin/xgrchain/bin/nodectl.sh`.

Both directions must be configured explicitly. Once any
`XGR_INTERCHAIN_ROUTE_<NAME>_*` route exists, the node stops synthesizing the
legacy local destination routes. Therefore never add `BASE_TO_XGR` without
also preserving `XGR_TO_BASE`.

Forward route:

```text
XGR_INTERCHAIN_ROUTE_XGR_TO_BASE_DESTINATION=base
XGR_INTERCHAIN_ROUTE_XGR_TO_BASE_SOURCE_TYPE=local
```

Reverse route:

```text
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_DESTINATION=xgr
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_TYPE=evm
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_CHAIN_ID=8453
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_DOMAIN=8453
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_RPC=https://base.publicnode.com
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_MAILBOX_ADDR=0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_MERKLE_TREE_HOOK_ADDR=0x19dc38aeae620380430C200a6E990D5Af5480117
XGR_INTERCHAIN_ROUTE_BASE_TO_XGR_SOURCE_CONFIRMATIONS=12
```

The reverse destination is XGRChain itself and uses RegistryV2
`0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` with
`XGR_INTERCHAIN_XGR_VERIFIER_FORMAT=compressed`.

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

Latest completed forward attestation:

```text
xgr_getInterchainAttestation("base")
```

Latest completed reverse attestation:

```text
xgr_getInterchainAttestation("base_to_xgr")
```

Archived checkpoint attestation:

```text
xgr_getInterchainAttestationByCheckpoint(route, setId, index, root)
```

The RPC is read-only. It cannot request or trigger a signature.

## Relayer

The production relayer runs **natively under Node.js**, not in Docker and not
as a systemd service. The process is supervised by `runtime/manage-relayers.sh`
using `nohup`, PID files, logs and persistent state under
`runtime/runtime-state/`.

Forward uses `.env.relayer`; reverse uses `.env.relayer.reverse`.
The two directions have separate processes, logs, PID files and state files.

Forward metadata uses the EIP-2537 aggregate signature. Reverse metadata uses
`aggregateSignatureCompressed`, matching RegistryV2 verifier format 1.

The relayer key only pays destination gas. Compromise of that key cannot produce
a valid XGR BLS quorum proof.

Install/update dependencies once:

```bash
cd runtime/native-relayer
npm install --no-audit --no-fund
npm test
node --check index.mjs
node --check merkle.mjs
```

Prepare reverse configuration:

```bash
cd runtime
cp .env.relayer.reverse.example .env.relayer.reverse
# set RELAYER_PRIVATE_KEY and ORIGIN_START_BLOCK before first start
```

A fresh reverse state does not replay the full Base Hyperlane history. It reads
`MerkleTreeHook.tree()` at `ORIGIN_START_BLOCK - 1` and indexes only later
leaves. Set `ORIGIN_START_BLOCK` to Base head + 1 immediately before the first
start, and do not send the first Base -> XGR test message until the reverse log
contains `native_relayer_state_bootstrapped`.

Native process management:

```bash
cd runtime
./manage-relayers.sh status all
./manage-relayers.sh start forward
./manage-relayers.sh start reverse
./manage-relayers.sh restart all
./manage-relayers.sh logs forward
./manage-relayers.sh logs reverse
```

The relayer reconstructs the 32-level Hyperlane Merkle proof and checks that its
computed root exactly equals the XGR-validator-attested root before submitting
the destination transaction. When no destination-bound messages remain, it
periodically compacts its state back to an on-chain tree snapshot.

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
8. native relayer indexes the origin without Merkle history gaps;
9. minimal XGR -> Base message delivery succeeds;
10. minimal Base -> XGR message delivery succeeds under controlled conditions;
11. invalid proof, stale setId, insufficient bitmap and modified message tests
    fail closed;
12. validator ADD, voluntary REMOVE and forced REMOVE are tested;
13. executor reimbursement and `claim()` are tested;
14. final deployment manifests contain the verified addresses;
15. public UI remains disabled until the complete route is intentionally opened.

## Secrets

Never commit validator keys, relayer/deployer keys, SSH keys, cloud credentials,
seed phrases, wallet exports or populated `.env` files.
