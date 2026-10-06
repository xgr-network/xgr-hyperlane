# XGR ILN Base MVP

**Status:** implementation / deployment preparation  
**Node baseline:** xgr-node v3.1.2  
**External spoke:** Base only  
**Liquidity:** Base USDC / wXGR  
**XDC:** deferred

## 1. MVP boundary

The first ILN deployment is intentionally limited to one external spoke:

```text
Base
USDC <-> wXGR
          |
          | XGR Interchain
          v
XGRChain
native XGR
```

Both bridge directions are required:

```text
XGRChain -> Base
native XGR -> wXGR

Base -> XGRChain
wXGR -> native XGR
```

No XDC, Polygon, Arbitrum, additional DEX integration, or generic
cross-chain asset routing belongs to this MVP.

The Base USDC/wXGR pool is an ordinary DEX pool. It is not implemented by
the ILN contracts.

Initial liquidity may be small (approximately 500 USDC on the USDC side).
The purpose of this stage is therefore technical and market validation, not
high-capacity execution.

## 2. Launch fee

xgr-node v3.1.2 deliberately rejects a zero validator fee.

The launch fee should therefore be economically negligible but strictly
positive. With the initial three-validator set, **6 wei** is a useful launch
value because it is divisible by both a two-signer quorum and a three-signer
quorum.

This is not a permanent pricing commitment. FEE_UPDATE remains quorum
governed.

## 3. Base-spoke contract map

### Base

Existing contracts retained:

- Mailbox: `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D`
- MerkleTreeHook: `0x19dc38aeae620380430C200a6E990D5Af5480117`
- BLS verifier: `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93`
- synthetic wXGR Warp router/token:
  `0x3b83687d77170D42feDDFe221629cc21e771e021`

New deployment:

1. Base-destination `XGRInterchainValidatorRegistryV2`
   - destinationDomain = 8453
   - verifier format = EIP-2537
   - used by the Base destination ILN ISM.
2. XGR-destination RegistryV2 mirror
   - destinationDomain = 1643
   - verifier format = EIP-2537
   - used by the Base source ILN registry/gateway for governance and fee
     settlement.
3. `ILNRouteRegistry`
   - sourceDomain = 8453
   - governed only by the XGR-destination mirror.
4. `ILNGateway`
   - wraps the existing Base synthetic wXGR Warp router.
5. `XGRILNInterchainISMV2`
   - verifies message-specific XGR-origin ILN attestations on Base.

### XGRChain

Existing contracts retained:

- Mailbox: `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79`
- MerkleTreeHook: `0xeD98Af715b5a72dCD412567eb086d48225CDDACF`
- native XGR Warp router:
  `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93`
- XGR-destination RegistryV2:
  `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292`
- native compressed BLS verifier: `0x0000000000000000000000000000000000002040`
- PausableISM: `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA`

New deployment:

1. Base-destination RegistryV2 mirror
   - destinationDomain = 8453
   - verifier format = compressed
   - used by the XGR source ILN registry/gateway.
2. `ILNRouteRegistry`
   - sourceDomain = 1643
   - governed only by the Base-destination mirror.
3. `ILNGateway`
   - wraps the existing native XGR Warp router.
4. `XGRILNInterchainISMV2`
   - verifies message-specific Base-origin ILN attestations.
5. fresh 2-of-2 StaticAggregationISM
   - existing PausableISM
   - new XGRILNInterchainISMV2.

## 4. Validator-set mirrors

ILN governance is destination-set governed.

Therefore a source chain must be able to verify the validator set that
secures its destination.

For the Base spoke this produces two mirrored pairs:

```text
destination XGR set
  canonical: XGRChain
  mirror:    Base

destination Base set
  canonical: Base
  mirror:    XGRChain
```

A membership transition has the same signed payload on both copies because
the payload binds:

- originChainId = 1643
- destinationDomain
- expectedSetId
- validity
- action
- validator identity
- BLS public keys.

The transaction sender and attached reserve are not part of the signed
membership payload, so execution remains permissionless and each chain may
use its locally appropriate reserve amount.

A mirror must never be treated as an independent membership authority.

## 5. Bootstrap proofs

The deployment scripts intentionally do not invent or embed missing
possession proofs.

Required inputs are supplied through environment variables.

For the Base-destination RegistryV2 (destination 8453):

- `BASE_DESTINATION_BOOTSTRAP_PROOF_0`
- `BASE_DESTINATION_BOOTSTRAP_PROOF_1`
- `BASE_DESTINATION_BOOTSTRAP_PROOF_2`

These are EIP-2537 signatures.

For the XGR-destination mirror on Base (destination 1643):

- `XGR_DESTINATION_MIRROR_BOOTSTRAP_PROOF_0`
- `XGR_DESTINATION_MIRROR_BOOTSTRAP_PROOF_1`
- `XGR_DESTINATION_MIRROR_BOOTSTRAP_PROOF_2`

These are EIP-2537 signatures. Existing compressed destination-1643
bootstrap signatures may be converted to EIP-2537 representation without
re-signing.

For the Base-destination mirror on XGRChain:

- `BASE_DESTINATION_MIRROR_BOOTSTRAP_PROOF_0`
- `BASE_DESTINATION_MIRROR_BOOTSTRAP_PROOF_1`
- `BASE_DESTINATION_MIRROR_BOOTSTRAP_PROOF_2`

These are compressed BLS signatures.

## 6. Safe deployment sequence

### Phase A - software

1. Build and publish xgr-node v3.1.2.
2. Upgrade all Interchain validators.
3. Do not configure any ILN route yet.
4. Existing chain block production must remain unaffected.

### Phase B - passive contract deployment

Run the contracts in `script/DeployILNBaseSpoke.s.sol`.

Deploy:

1. Base destination RegistryV2.
2. XGR-destination mirror on Base.
3. Base-destination mirror on XGRChain.
4. Base source ILN registry + Gateway.
5. XGR source ILN registry + Gateway.
6. Base destination ILN ISM.
7. XGR destination ILN ISM + fresh Pausable/ILN aggregation.

At the end of this phase **nothing is active**.

The scripts do not:

- execute ROUTE_ADD,
- call DomainRoutingISM.set,
- change the Base wXGR router ISM,
- start ILN relayers.

### Phase C - node bootstrap config

Configure the network-level values from
`runtime/xgr-node-interchain-mainnet.env.example`:

- Base RegistryV2
- Base ILN registry
- XGR existing RegistryV2
- XGR ILN registry
- RPC/domain/confirmation policies.

Do not add route ENV declarations until destination security is ready if an
operator wants a fully inert worker.

### Phase D - quorum-governed route records

Create two ROUTE_ADD proposals through xgr-node v3.1.2:

```text
base -> xgr
xgr  -> base
```

Use a launch `validatorFeeWei` such as 6 wei.

Validators inspect and explicitly approve each proposal.

After two-thirds quorum, execute each proposal on its source-chain
`ILNRouteRegistry`.

There is no owner/admin bypass.

### Phase E - destination security cutover

Base:

- configure the existing Base wXGR router to use the new Base destination
  `XGRILNInterchainISMV2`.

XGRChain:

- update the Base origin entry in the existing DomainRoutingISM to the fresh
  2-of-2 aggregation:
  - PausableISM
  - XGRILNInterchainISMV2.

These are the first steps that change message acceptance.

They must be performed only after all validators run v3.1.2 and the route
records have been verified.

### Phase F - observe-only ILN relayers

Create local non-tracked env files from:

- `runtime/.env.relayer.iln.base-to-xgr.example`
- `runtime/.env.relayer.iln.xgr-to-base.example`

Keep:

```text
RELAYER_SUBMIT=false
```

Start explicitly:

```bash
./manage-relayers.sh start iln-base-to-xgr
./manage-relayers.sh start iln-xgr-to-base
```

The ILN relayer calls the exact destination `Mailbox.process` path with
`staticCall` before reporting readiness.

The generic `all` target intentionally does not start ILN relayers.

### Phase G - controlled E2E

Test tiny amounts in both directions.

Required evidence:

- canonical Gateway `ILNOperation`,
- exact messageId,
- completed v3.1.2 attestation by messageId,
- correct Merkle proof,
- destination static validation,
- successful destination processing,
- expected wXGR burn/mint and XGR lock/unlock.

Only after both directions pass should `RELAYER_SUBMIT=true` be considered
for continuous operation.

### Phase H - Base pool

Seed the Base USDC/wXGR pool with the intentionally small initial liquidity.

The UI must quote live output and slippage. It must not advertise a fixed
maximum transaction size merely because the bridge itself can move a larger
amount.

## 7. Security boundaries

The MVP keeps these invariants:

- The existing Warp routers remain the Hyperlane message senders.
- Direct Warp calls do not generate a canonical `ILNOperation`.
- Validators authorize one exact messageId, not an entire Merkle root.
- A destination ISM verifies both the authorized messageId and Merkle
  inclusion.
- Route changes require destination-validator BLS quorum.
- Relayers remain replaceable and non-authoritative.
- Validator fee settlement uses the accepted signer bitmap.
- ILN failure cannot stop XGRChain IBFT block production.

## 8. Deferred scope

Not part of this MVP:

- XDC integration,
- Polygon / Arbitrum spokes,
- additional external liquidity pools,
- automatic cross-chain swap orchestration,
- large-transfer liquidity targets,
- percentage protocol fees,
- a separate ILN token.

The next expansion decision should follow actual Base-spoke usage and
liquidity evidence.
