# Architecture

## Separation from the XGR node

Hyperlane is not compiled into the XGRChain node.

The XGR node provides the EVM execution environment and JSON-RPC interface.
Hyperlane adds an interoperability layer consisting of:

1. **Mailbox/Core contracts** on each chain;
2. **ISM security modules** that define message verification;
3. a **validator** that signs XGR-origin checkpoints;
4. a **relayer** that transports messages and metadata;
5. later, **Warp Route contracts** that implement the asset bridge;
6. later, a user-facing **bridge UI**.

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

## Validator and relayer

The XGR validator watches the XGRChain MerkleTreeHook, signs checkpoints and
publishes checkpoint data.

The relayer watches XGRChain and Base, discovers validator checkpoints, builds
message verification metadata and submits eligible messages to the destination
Mailbox.

Validator and relayer do not themselves custody XGR.

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
