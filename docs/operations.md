# Operations and rollout

## Agent version

Runtime images are pinned to:

`ghcr.io/hyperlane-xyz/hyperlane-agent:2.3.0`

Do not use `latest` for production.

## Closed beta

The beta runtime may run validator and relayer on the same controlled host and
share a local checkpoint volume.

This is acceptable only while:

- Base → XGR remains protected by the paused PausableIsm;
- no user-facing bridge is enabled;
- asset exposure is bounded;
- the runtime is being used for infrastructure verification.

Local checkpoint storage is not the production architecture.

## Production checkpoint publication

For the native XGR-origin path, the XGR node writes completed BLS quorum
attestations below its local `interchain/attestations/<destination>/` directory.
Before public operation, a separate untrusted publisher must mirror those files
to public-readable storage (for example S3-compatible object storage or HTTPS).

The publisher does not sign and is not trusted by the ISM. Relayers may consume
an attestation from any publisher or validator endpoint because the destination
ISM independently verifies the validator set, signer bitmap, BLS aggregate
signature and Merkle proof.

The older Hyperlane-validator checkpoint-sync configuration belongs to the
legacy/beta path and must not be treated as the native XGR-origin trust anchor.

## Secrets

Never commit:

- validator keys;
- relayer/deployer keys;
- SSH keys;
- cloud credentials;
- populated `.env` files;
- seed phrases or wallet exports.

The beta bootstrap generates validator and relayer keys on the runtime host and
prints only their public addresses.

## Deployment automation

The repository includes a manually dispatched GitHub Actions workflow with three
operations:

- `prepare` — upload runtime and generate host-local keys;
- `start` — start validator and relayer after gas wallets are funded;
- `status` — read container status and bounded logs.

The workflow requires encrypted repository secrets for host, user, SSH private
key and pinned SSH host key. No concrete production hostname or server address
is committed to this repository.

## XGR node native interchain environment

The XGR node's native interchain worker reads the origin Hyperlane deployment from environment variables. These values are deployment-specific and must never be hardcoded into the node binary.

For XGRChain mainnet:

```bash
XGR_INTERCHAIN_ORIGIN_MAILBOX_ADDR=0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79
XGR_INTERCHAIN_ORIGIN_MERKLE_TREE_HOOK_ADDR=0xeD98Af715b5a72dCD412567eb086d48225CDDACF
```

Each destination additionally uses the existing `XGR_INTERCHAIN_<NAME>_*` configuration, including chain ID, domain, registry address, RPC endpoint, deactivation reserve, confirmations and timing policy.

The origin mailbox and MerkleTreeHook are read only from the local finalized XGR state. The relayer never supplies a payload for the validator to sign.

## Launch gates

Do not unpause or expose the bridge until all of the following are evidenced:

1. validator starts on XGR domain 1643 with the pinned image;
2. validator identity is stable across restart;
3. checkpoint publication works;
4. ValidatorAnnounce contains the expected validator storage location;
5. relayer indexes XGRChain and Base without critical errors;
6. XGR and Base relayer wallets hold only bounded operational gas;
7. Base-side XGR-origin verification ISM is deployed against the actual XGR
   validator set;
8. XGRChain native and Base synthetic Warp routers are deployed;
9. route-specific rate controls are configured;
10. a minimal XGR → Base test succeeds;
11. a minimal Base → XGR test succeeds under a deliberately bounded opening;
12. pause/unpause recovery is tested;
13. the exact Warp collateral implementation has cleared the open security
    concern tracked by Hyperlane issue #8589;
14. checkpoint publication has been moved from local beta storage to the
    production remote/public model;
15. deployment manifests are updated with verified final addresses;
16. public documentation and the user-facing UI reflect the verified state.

Until every gate is complete, the bridge remains prelaunch.
