# Architecture

## XGR 3.0 native security

Hyperlane remains the message transport layer, but XGR-origin security is native
to XGR 3.0.

The XGR node contains an isolated interchain worker. It is deliberately outside
weighted-IBFT consensus-critical paths and cannot influence block production,
validator voting power, epoch selection or weighted consensus.

For each configured destination, a validator is a valid native interchain signer
only when:

1. it is a member of the destination `XGRInterchainValidatorRegistry`;
2. it is active in XGR staking; and
3. its registry BLS identity matches its XGR staking BLS identity.

The interchain quorum is unweighted two-thirds of the destination registry set.

## XGR-origin message path

1. a user dispatches through the existing XGR Hyperlane Mailbox;
2. the configured MerkleTreeHook inserts the message ID;
3. XGR 3.0 nodes read the hook root from one atomic local XGR state snapshot;
4. the native interchain subset signs the destination-bound checkpoint;
5. nodes aggregate a two-thirds BLS quorum;
6. completed attestations are exposed through read-only
   `xgr_getInterchainAttestation*` RPC;
7. an untrusted relayer reconstructs the message Merkle proof and submits
   metadata plus message to the destination Mailbox;
8. `XGRNativeInterchainISM` verifies the current registry set, signer bitmap,
   BLS aggregate signature and message inclusion;
9. only then does the destination Mailbox deliver the message.

The relayer can withhold availability, but cannot forge acceptance.

## Destination trust stack

Each destination has its own:

- `XGRInterchainBLSVerifier`;
- `XGRInterchainValidatorRegistry`;
- `XGRNativeInterchainISM`.

The registry is the canonical membership state. The ISM does not duplicate the
validator set.

### Bootstrap

The registry constructor receives the initial validator addresses, compressed
XGR BLS keys, EIP-2537 keys, possession proofs and per-validator deactivation
reserve.

After bootstrap, ADD and REMOVE operations are authorized by the current
registry set and increment `setId`.

### Current-set verification

Checkpoint verification uses the current destination registry `setId`.
After a membership transition, XGR nodes autonomously attest the latest root
again under the new set. Removed validators therefore cannot create newly
accepted old-set attestations.

## Hyperlane components retained

The integration continues to use:

- Mailbox;
- Hyperlane message encoding;
- MerkleTreeHook;
- Dispatch / Process semantics;
- permissionless destination `Mailbox.process()`;
- later, Warp route contracts and optional hook infrastructure.

The standard Hyperlane validator, ValidatorAnnounce checkpoint discovery and
ECDSA multisig checkpoint security are not part of XGR-origin native security.

## Native relayer

`runtime/native-relayer` is intentionally untrusted. It:

- indexes XGR Mailbox Dispatch events;
- indexes the canonical XGR MerkleTreeHook leaves;
- retrieves completed native attestations over XGR RPC;
- reconstructs and locally checks the Merkle root;
- builds the custom native ISM metadata;
- submits `Mailbox.process()` on the destination.

Its private key is only a destination gas payer.

## Hook coverage

Native verification can only prove messages inserted into the configured
MerkleTreeHook. Before public launch, the XGR Mailbox deployment must ensure that
the canonical MerkleTreeHook is necessarily executed for every supported
dispatch path (preferably as the required hook), or the route must explicitly
reject unsupported custom-hook dispatch paths.

## Base -> XGR

The existing Base-origin route on XGR is separate. It remains protected by the
existing aggregation ISM including the deliberately paused PausableIsm until the
inbound route is intentionally opened.

## Warp route

The intended first asset route is native XGR on XGRChain and synthetic XGR on
Base. Router deployment remains separate from the native security layer.
