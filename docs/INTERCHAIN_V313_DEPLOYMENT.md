# XGR Interchain v3.1.3 deployment

This runbook describes the generic Foundry deployment flow implemented in
`script/DeployV313.s.sol`.

## Security boundary

Deployment does **not** create or enable ILN routes.

The script may deploy:

- the EIP-2537 BLS verifier on chains that need the Solidity verifier;
- the local destination-scoped `XGRInterchainValidatorRegistryV2`;
- the local source `XGRILNRegistry`;
- the generic destination `XGRILNInterchainISMV2`;
- one route-specific `ILNGateway`.

A route becomes canonical only after a v3.1.3 quorum-approved `ROUTE_ADD`
governance operation is submitted to the source-chain `XGRILNRegistry`.

## Per-chain deployment order

### XGRChain

1. Reuse the native compressed BLS verifier at `0x0000000000000000000000000000000000002040`.
2. Deploy `DeployV313RegistryV2` with verifier format `1`.
3. Deploy `DeployV313ILNRegistry` if XGRChain is a source chain.
4. Deploy `DeployV313ISM` if XGRChain is a destination chain.
5. Deploy one `DeployV313Gateway` per source route.
6. Add each route through v3.1.3 ILN governance.

### EIP-2537 destination/source chain

1. Deploy `DeployV313EIP2537Verifier`.
2. Deploy `DeployV313RegistryV2` with verifier format `2`.
3. Deploy `DeployV313ILNRegistry` if the chain is a source.
4. Deploy `DeployV313ISM` if the chain is a destination.
5. Deploy one `DeployV313Gateway` per source route.
6. Add each route through v3.1.3 ILN governance.

## Common environment

```text
LOCAL_CHAIN_ID=
LOCAL_DOMAIN=
```

Every deployment checks `block.chainid == LOCAL_CHAIN_ID` before broadcasting.

## RegistryV2 environment

```text
MEMBERSHIP_ORIGIN_CHAIN_ID=
BLS_VERIFIER=
BLS_VERIFIER_FORMAT=
MINIMUM_DEACTIVATION_RESERVE_WEI=
MAX_EXECUTOR_REIMBURSEMENT_WEI=
INITIAL_RESERVE_WEI=
VALIDATOR_COUNT=

VALIDATOR_0_ADDRESS=
VALIDATOR_0_BLS_COMPRESSED=
VALIDATOR_0_BLS_EIP2537=
VALIDATOR_0_POSSESSION_PROOF=

VALIDATOR_1_ADDRESS=
VALIDATOR_1_BLS_COMPRESSED=
VALIDATOR_1_BLS_EIP2537=
VALIDATOR_1_POSSESSION_PROOF=
...
```

`INITIAL_RESERVE_WEI` is per bootstrap validator. The registry deployment sends
exactly `INITIAL_RESERVE_WEI * VALIDATOR_COUNT` native currency.

## ILN Registry environment

```text
LOCAL_REGISTRY_V2=
```

The registry constructor requires this to be the RegistryV2 on the same physical
chain and requires its destination domain to equal `LOCAL_DOMAIN`.

## ISM environment

```text
LOCAL_REGISTRY_V2=
```

One v3.1.3 ISM can verify all canonical routes terminating at that destination.

## Gateway environment

```text
ILN_REGISTRY=
ROUTE_ID=
DESTINATION_DOMAIN=
WARP_ROUTER=
NATIVE_QUOTE_INCLUDES_PRINCIPAL=false
```

The Gateway is route-specific and remains unusable until the matching route is
created in the source ILN Registry by governance.

## Foundry examples

Use the appropriate RPC and a Foundry account/keystore. Do not put a private key
in the repository.

```bash
forge script script/DeployV313.s.sol:DeployV313RegistryV2 \
  --rpc-url "$RPC_URL" \
  --account "$FOUNDRY_ACCOUNT" \
  --broadcast

forge script script/DeployV313.s.sol:DeployV313ILNRegistry \
  --rpc-url "$RPC_URL" \
  --account "$FOUNDRY_ACCOUNT" \
  --broadcast

forge script script/DeployV313.s.sol:DeployV313ISM \
  --rpc-url "$RPC_URL" \
  --account "$FOUNDRY_ACCOUNT" \
  --broadcast

forge script script/DeployV313.s.sol:DeployV313Gateway \
  --rpc-url "$RPC_URL" \
  --account "$FOUNDRY_ACCOUNT" \
  --broadcast
```

On an EIP-2537 chain, deploy the verifier first:

```bash
forge script script/DeployV313.s.sol:DeployV313EIP2537Verifier \
  --rpc-url "$RPC_URL" \
  --account "$FOUNDRY_ACCOUNT" \
  --broadcast
```

## Release gate before any deployment

```bash
forge build
forge test -vvv
```

Do not deploy if either command fails.


## Multi-asset repository and automation convention

The v3.1.3 deployment model is intentionally optimized for many assets.

### Shared once per chain

The following infrastructure is expected to be deployed once per physical chain and reused:

```text
Hyperlane Core / Mailbox
MerkleTreeHook
BLS verifier
XGRInterchainValidatorRegistryV2
XGRILNRegistry
generic XGRILNInterchainISMV2
```

Do not redeploy this stack for every new token unless a protocol upgrade explicitly requires a new generation.

### Incremental per asset / route

A new asset normally adds only:

```text
Warp Router / Token Adapter
ILNGateway per source route
routeId registration
governance state
```

### Recommended repository layout

```text
config/
├─ chains/
│  ├─ xgrchain.json
│  ├─ base.json
│  └─ ...
└─ assets/
   ├─ XGR/
   │  ├─ asset.json
   │  └─ routes.json
   └─ <ASSET>/
      ├─ asset.json
      └─ routes.json

deployments/
└─ mainnet/
   ├─ infrastructure/
   │  ├─ xgrchain.json
   │  └─ base.json
   └─ assets/
      ├─ XGR.json
      └─ <ASSET>.json
```

Desired configuration and observed deployment state must remain separate.

`asset.json` should contain stable asset metadata and canonical representation information. `routes.json` should contain desired route topology. `deployments/.../*.json` should contain generated on-chain addresses, transaction hashes, route IDs and verified observed state.

### Idempotent deployment target

The intended automation target is conceptually:

```bash
./xgr-interchain deploy-asset \
  --asset config/assets/ABC/asset.json \
  --network mainnet
```

The deployer should:

1. load chain configuration;
2. verify existing shared infrastructure;
3. reuse matching existing contracts;
4. deploy only missing asset-specific routers/adapters;
5. deploy only missing gateways;
6. derive and verify route IDs;
7. persist deployment records;
8. verify deployed code and bindings;
9. generate governance proposals;
10. leave route activation pending until quorum-approved governance is submitted.

Re-running the same deployment should be safe. Correct existing infrastructure should be reported as already present rather than redeployed.

### Existing asset/router reuse during upgrades

Existing Warp Router / token contracts may be retained during a protocol security upgrade when their deployed code and route bindings are understood, the current owner/admin can perform the required security-module transition, token supply and canonical representation remain unchanged, and the new security path is validated before cutover.

Legacy security modules may remain deployed on-chain as historical contracts, but after cutover they must no longer be referenced by the active route.

### Bootstrap possession proofs

Validator bootstrap possession proofs are destination-domain-specific because the signed bootstrap payload includes the destination domain.

Therefore, a proof generated for one RegistryV2 destination must not be reused for another destination. New destination registries require fresh possession proofs from the same validator BLS keys.
