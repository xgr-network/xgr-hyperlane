# XGR.Network Hyperlane Integration

Public deployment manifests, runtime configuration and operational documentation
for the XGRChain ↔ Hyperlane integration.

This repository is intentionally separate from
[`xgr-network/xgr-node`](https://github.com/xgr-network/xgr-node). Hyperlane
does **not** require a modification of the XGRChain node implementation. The
integration consists of on-chain Hyperlane contracts plus off-chain validator
and relayer services that communicate with XGRChain through standard EVM JSON-RPC.

## Current status

The XGRChain Hyperlane Core is deployed on XGRChain mainnet (chain/domain 1643).
The intended first asset route is native XGR on XGRChain ↔ synthetic XGR on Base.

The route is **not open for users yet**.

Base-origin verification on XGRChain currently includes a deliberately paused
PausableIsm. This keeps the route fail-closed while validator/relayer
infrastructure, Base-side contracts and bounded end-to-end tests are completed.

## Repository layout

- `deployments/` — verified on-chain deployment manifests and route state
- `runtime/` — reproducible validator/relayer Docker runtime
- `docs/` — architecture, operations and rollout documentation
- `.github/workflows/` — validation and controlled beta deployment workflows

## Main XGRChain contracts

| Component | Address |
| --- | --- |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| DomainRoutingIsm | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| PausableIsm | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Base route aggregation ISM | `0x320e8501677532cc1f5c5bb7990b6db72c627b6c` |

See `deployments/xgrchain-mainnet.json` for transaction evidence and
`deployments/xgr-base-route.json` for the current route security state.

## Runtime

The off-chain runtime is pinned to Hyperlane agent `2.3.0`.

Two modes are maintained:

- **beta** — validator and relayer may share local checkpoint storage on one
  controlled host while the route remains fail-closed;
- **production** — validator checkpoints are published to public-readable remote
  storage so independent relayers can retrieve them.

Private keys, SSH credentials, cloud credentials and populated environment files
must never be committed.

## Security state

The current route remains deliberately paused. Do not treat the presence of
deployed contracts as evidence that the bridge is live.

Native-XGR Warp custody is also deferred while Hyperlane issue
[`#8589`](https://github.com/hyperlane-xyz/hyperlane-monorepo/issues/8589)
remains unresolved or until the exact pinned implementation is independently
shown not to be affected.

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
