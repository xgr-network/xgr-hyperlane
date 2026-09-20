# XGR.Network Hyperlane Integration

Public contracts, runtime configuration and operational documentation for the
XGRChain native interchain security integration with Hyperlane transport.

## XGR 3.0 architecture

XGR 3.0 moves XGR-origin interchain security into the XGR node itself.

The Hyperlane Mailbox and MerkleTreeHook remain the transport/message layer.
XGR validators that explicitly opt into a destination form a native,
destination-specific BLS validator subset. XGR nodes autonomously attest the
configured Hyperlane Merkle root and expose only completed quorum attestations
through read-only XGR JSON-RPC.

The relayer is not a trust anchor. It reconstructs a Hyperlane message inclusion
proof, retrieves a completed XGR BLS attestation, and submits both to the
destination Mailbox. The destination XGR native ISM independently verifies the
current registry set, unweighted two-thirds quorum, BLS aggregate signature and
Merkle inclusion proof.

## Current status

- XGRChain mainnet chain/domain: `1643`
- XGR 3.0 native interchain node support: deployed
- XGRChain Hyperlane Core: deployed
- first destination: Base (`8453`)
- Base native XGR registry / verifier / ISM: pre-deployment
- user-facing bridge: not open

Base-origin verification on XGRChain remains fail-closed while the reverse
direction and final Warp route are completed.

## Repository layout

- `contracts/` — destination registry, BLS verifier and native XGR ISM
- `test/` — Foundry contract tests
- `deployments/` — verified deployment manifests and route state
- `runtime/` — trustless native relayer runtime
- `docs/` — architecture and operations
- `.github/workflows/` — validation workflows

## Existing XGRChain contracts

| Component | Address |
| --- | --- |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| DomainRoutingIsm | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| PausableIsm | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Base route aggregation ISM | `0x320e8501677532cc1f5c5bb7990b6db72c627b6c` |

`ValidatorAnnounce` remains deployed for compatibility/history but is not part
of XGR-origin native security.

## Native destination contracts

The XGR-origin destination stack consists of:

1. `XGRInterchainBLSVerifier`
2. `XGRInterchainValidatorRegistry`
3. `XGRNativeInterchainISM`

The registry receives the initial validator set during deployment. The ISM stores
only the immutable registry and XGR origin context; subsequent validator changes
are read from the registry automatically.

## Security state

The bridge remains prelaunch until the destination contracts are deployed,
bootstrapped, the native relayer passes a live XGR -> Base message test, and the
Warp route has passed its launch gates.

Private keys, populated environment files and deployment secrets must never be
committed.

## Documentation

- [Architecture](docs/architecture.md)
- [Operations and rollout](docs/operations.md)
- [Security policy](SECURITY.md)

## Official XGR resources

- https://xgr.network
- https://xgr.network/docs/
- https://explorer.xgr.network
- https://github.com/xgr-network

## License

Apache License 2.0.
