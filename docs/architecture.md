# Architecture

## Separation from the XGR node

Hyperlane is not compiled into the XGRChain node.

The XGR node provides the EVM execution environment and JSON-RPC interface.
Hyperlane adds an interoperability layer consisting of:

1. **Mailbox/Core contracts** on each chain;
2. **ISM security modules** that define message verification;
3. the XGR node's **native interchain worker**, which signs XGR-origin checkpoints with the validator's existing BLS key;
4. an untrusted **attestation publisher** that may expose completed quorum attestations from node-local storage;
5. a **relayer** that transports messages, Merkle proofs and quorum metadata;
6. later, **Warp Route contracts** that implement the asset bridge;
7. later, a user-facing **bridge UI**.

This is why the integration is maintained in this repository rather than in
`xgr-node`.

## Initial route

- Canonical asset: native XGR on XGRChain
- Destination representation: synthetic XGR on Base
- XGRChain domain: 1643
- Base domain: 8453

A traditional liquidity pool is not required for this lock/mint and burn/release
model.

## Current inbound security on XGRChain

Base-origin verification is routed through an aggregation ISM with threshold 2.

The required modules are:

1. Hyperlane Base 3-of-5 Merkle-root multisig verification; and
2. XGR's PausableIsm.

The PausableIsm is currently paused, so Base → XGR fails closed.

## Native checkpoint signer and trustless relayer

For XGR-origin native verification, the Hyperlane agent validator is not a trust
anchor. The XGR node's isolated interchain worker reads the configured
MerkleTreeHook from the local finalized XGR state and signs a deterministic,
destination-bound checkpoint payload with the validator's existing XGR BLS key.

Only validators that are both active in XGR staking and members of the current
destination interchain registry set may contribute checkpoint signatures. The
worker aggregates an unweighted two-thirds quorum and writes the completed
attestation to node-local storage.

A publisher may copy these completed attestations to public-readable storage.
The publisher is untrusted: modifying an attestation cannot create a valid BLS
quorum proof.

The relayer watches XGRChain dispatch and MerkleTreeHook events, reconstructs the
message and Merkle inclusion proof, obtains any valid public quorum attestation,
and submits message plus metadata to the destination Mailbox. The destination
ISM is authoritative. The relayer has no signing authority accepted by the ISM;
a malicious relayer can only submit invalid data (which is rejected) or withhold
delivery.

The legacy Hyperlane validator runtime may remain useful for beta/legacy
infrastructure, but it is not part of the native XGR-origin security model.

## Warp Route

The intended Warp Route will use native XGR on XGRChain and a synthetic XGR
representation on Base. Router addresses are intentionally absent from the
deployment manifest until the exact implementation has passed the security gate
and been deployed.

## UI contract

The future bridge UI must derive live state rather than assume availability.

At minimum it should display and track:

- source and destination chain;
- route pause state;
- router addresses from a published deployment manifest;
- amount and token decimals;
- approval requirement when applicable;
- origin transaction hash;
- Hyperlane message ID;
- delivery state;
- destination transaction hash.

If a route is paused, incomplete or absent from the deployment manifest, the UI
must render it unavailable.
