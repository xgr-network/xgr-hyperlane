# XGR ILN Base MVP

**Status:** implementation / deployment preparation  
**Node baseline:** xgr-node v3.1.2  
**External spoke:** Base only  
**Liquidity:** Base USDC / wXGR  
**XDC:** deferred

## 1. MVP boundary

The first ILN deployment is intentionally one external spoke:

~~~text
Base
USDC <-> wXGR
          |
          | XGR Interchain
          v
XGRChain
native XGR
~~~

Both bridge directions are required:

~~~text
XGRChain -> Base
native XGR -> wXGR

Base -> XGRChain
wXGR -> native XGR
~~~

The existing Warp routers, Mailboxes, MerkleTreeHooks and Interchain
validator registries are retained.

The Base USDC/wXGR pool is an ordinary DEX pool and is not implemented by
the ILN contracts.

The initial pool may be small, approximately 500 USDC on the USDC side.
This stage proves the route and early market demand; it is not a
high-capacity liquidity product.

## 2. What changes from v3.1.1

The BLS quorum itself is not replaced.

v3.1.1 authorized a complete Hyperlane checkpoint root. v3.1.2 narrows the
authorization to one fee-qualified canonical message:

~~~text
canonical Gateway
      +
exact Hyperlane messageId
      +
exact source block
      +
canonical route context
      +
Merkle inclusion in signed root
      +
existing XGR validator BLS quorum
~~~

The existing Warp router remains the Hyperlane message sender.

## 3. Minimal Base-MVP architecture

The Base MVP does not deploy validator-set mirrors or a mutable
quorum-governed ILN route registry.

Instead, each source chain gets one immutable ILNGateway.

The Gateway also implements the exact getRoute(uint32) ABI expected by
xgr-node v3.1.2 and returns itself as the canonical gateway.

Therefore:

~~~text
ILN_REGISTRY_ADDR == ILN_GATEWAY
~~~

All route-critical values are constructor immutables:

- source domain,
- destination domain,
- source Warp router,
- Mailbox,
- MerkleTreeHook,
- destination Warp router,
- launch validator fee.

There is no owner, admin key, route mutation, fee mutation,
validator-set mirror, or cross-chain governance dependency.

Changing a route later means deploying a new Gateway and explicitly
changing node/bootstrap and destination-security configuration.

For the small Base MVP this is simpler and safer than introducing dynamic
cross-chain governance before it is needed.

## 4. Existing security contracts retained

### Base destination: XGR -> Base

The existing Base production validator registry remains canonical:

0x70F5752326735b31641f21D174BA035E904Db93c

The new XGRILNInterchainISM uses that existing V1 registry and its
EIP-2537 BLS verifier.

This preserves the same validator-set semantics already used by the
v3.1.1 XGR -> Base route while adding message-specific v3.1.2
authorization.

Because the V1 registry exposes only the current validator set, an
attestation created immediately before a membership change must be
delivered before that set changes or be re-created under the new set.
This is a liveness limitation inherited from the existing V1 Base
registry, not a new authorization weakness.

### XGR destination: Base -> XGR

The existing XGR RegistryV2 remains canonical:

0x013F2F2f7dB897F941b19C4ab71C5395a48A0292

XGRILNInterchainISMV2 uses its historical validator-set support and the
native compressed BLS verifier.

No new validator registry is required on either chain for the Base MVP.

## 5. Launch validator fee

xgr-node v3.1.2 intentionally rejects a zero validator fee.

For the first Base MVP deployment the recommended value is:

~~~text
1 wei
~~~

This is economically equivalent to zero for users while preserving the
strict positive-fee invariant.

The static Gateway escrows this nominal fee. The Base MVP deliberately
does not add a second cross-chain validator-set synchronization mechanism
just to distribute 1 wei.

Before a materially non-zero validator fee is introduced, signer-based
fee settlement must be added as a separately reviewed upgrade.

## 6. New contracts

### Base

Only two new ILN contracts are required:

1. ILNGateway
   - Base -> XGR source Gateway;
   - also acts as the immutable Base ILN registry.

2. XGRILNInterchainISM
   - XGR -> Base destination verifier;
   - uses the existing Base V1 validator registry.

Existing Base Mailbox, MerkleTreeHook, wXGR Warp router/token, BLS verifier
and validator registry remain unchanged.

### XGRChain

Only two new ILN security components are required:

1. ILNGateway
   - XGR -> Base source Gateway;
   - also acts as the immutable XGR ILN registry.

2. XGRILNInterchainISMV2
   - Base -> XGR destination verifier;
   - uses the existing XGR RegistryV2.

The existing PausableISM is composed with the new ILN ISM in a fresh
2-of-2 StaticAggregationISM.

No existing Warp router is replaced.

## 7. Deployment sequence

### Phase A - node software

1. Complete and release xgr-node v3.1.2.
2. Upgrade all Interchain validators.
3. Do not configure the two ILN routes yet.

Chain consensus remains independent of the ILN worker.

### Phase B - passive contracts

Deploy:

1. Base source ILNGateway.
2. XGR source ILNGateway.
3. Base destination XGRILNInterchainISM.
4. XGR destination XGRILNInterchainISMV2.
5. Fresh XGR PausableISM + ILN-ISM 2-of-2 aggregation.

script/DeployILNBaseSpoke.s.sol performs only deployment. It does not:

- modify the Base wXGR router,
- modify XGR DomainRoutingISM,
- start relayers,
- alter the existing validator registries.

### Phase C - node configuration

Set:

~~~text
XGR_INTERCHAIN_BASE_ILN_REGISTRY_ADDR=<BASE_ILN_GATEWAY>
XGR_INTERCHAIN_XGR_ILN_REGISTRY_ADDR=<XGR_ILN_GATEWAY>
~~~

Then declare the two explicit routes.

### Phase D - destination-security cutover

Base:

- change the existing Base wXGR router's ISM to the new
  XGRILNInterchainISM.

XGRChain:

- change the Base-origin DomainRoutingISM entry to the fresh
  PausableISM + XGRILNInterchainISMV2 aggregation.

These are the first state changes that alter message acceptance.

### Phase E - observe-only relayers

Use:

- runtime/.env.relayer.iln.base-to-xgr.example
- runtime/.env.relayer.iln.xgr-to-base.example

Keep:

~~~text
RELAYER_SUBMIT=false
~~~

Start each ILN relayer explicitly. The all target intentionally does not
start ILN relayers.

The relayer must pass Mailbox.process.staticCall before a route is
considered ready.

### Phase F - controlled E2E

Test tiny amounts in both directions and require:

- Gateway ILNOperation from the exact source Gateway,
- exact messageId attestation,
- expected source block and 1-wei fee,
- correct Merkle inclusion proof,
- successful destination static validation,
- successful destination processing,
- correct XGR lock/unlock and wXGR mint/burn.

Only after both directions pass should continuous submission be enabled.

### Phase G - Base pool

Seed the small Base USDC/wXGR pool.

The UI must display live AMM output/slippage and must not imply that bridge
capacity equals useful trade size.

## 8. Why this remains extensible

The simplification is MVP-specific, not Base-hardcoded.

ILNGateway is configured by constructor with source/destination domains,
routers, Mailbox and hook.

A future XDC spoke can therefore deploy another Gateway instance and the
appropriate destination ISM without changing the Base contracts.

If ILN later needs non-trivial validator fees, mutable route parameters,
many destinations per source Gateway, or fully quorum-governed route
updates, those can be introduced as a later registry/gateway generation
without changing the v3.1.2 message-specific authorization model.

## 9. Deferred scope

Not part of this Base MVP:

- XDC,
- Polygon / Arbitrum,
- validator-set mirrors,
- dynamic route governance,
- signer-based fee distribution for the nominal 1-wei launch fee,
- large-transfer liquidity targets,
- automatic cross-chain swap orchestration.

The next expansion decision should follow actual Base-spoke usage.
