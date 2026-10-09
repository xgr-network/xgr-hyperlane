# XETA web product — architecture plan
Status: planned, not implemented. Destination: **xeta.xgr.network** under the future public **xgr-interchain** repository, independent of XGR_Web.

- /: Explained network overview, verified route count, bridged assets and volume, validator/quorum security, native fees and live-vs-planned state.
- /markets: searchable, sortable token rankings. Market cap and trading volume come from timestamped price/DEX sources, while XETA moved volume and bridged value come from indexed authenticated transfers; never double count locked collateral and wrapped supply.
- /bridge: standalone universal Bridge widget and Wallet/RPC status.
- /token/:id: discoverable canonical token identity, chain/contract verification, price/liquidity information, **embedded operational Bridge widget** preselected to that token, quote, allowance, signing, delivery progress and recovery.
- /join: free Alliance application through website or GitHub PR producing the same manifest proposal. Signed token/project ownership proof and review; quorum-only route activation.
- /routes: future cross-chain graph router with DEX edge quotes + XETA bridge edges. Non-atomic multi-step execution needs slippage control and compensating/recovery flows. Do not promise gasless hub transfers without the separate XGR hop sponsor.

Use one shared bridge SDK and UI component for /bridge and token pages. Bridge MUST call ILNGateway.quoteILN and bridge, never public Warp transferRemote. Status derives from real source receipts, signed attestations and destination Mailbox.delivered. A partner's premium subdomain must not be able to inject executable wallet/bridge code.

Proposed directories: apps/web, services/indexer, services/market-data, services/onboarding, packages/sdk. Route visibility must never disable the onchain withdrawal path.
