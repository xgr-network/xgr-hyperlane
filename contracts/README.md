# XGR native interchain contracts

This directory contains the destination-side trust contracts for XGR 3.0 native
interchain security.

## Components

### XGRInterchainBLSVerifier

Verifies the XGR Kryptology BLS12-381 MinPk proof-of-possession ciphersuite with
EIP-2537 public keys and aggregate signatures.

### XGRInterchainValidatorRegistry

Canonical destination-specific XGR interchain validator membership.

The registry is bootstrapped with the initial validator addresses, canonical BLS
keys, EIP-2537 keys, possession proofs and deactivation reserves. After
bootstrap there is no administrator membership override. ADD and REMOVE
transitions require the current unweighted two-thirds BLS quorum.

### XGRNativeInterchainISM

Hyperlane destination ISM for XGR-origin messages.

The ISM does not own a second validator set. It reads the current set and setId
from `XGRInterchainValidatorRegistry`, reconstructs the XGR 3.0 checkpoint
payload, verifies the signer bitmap and aggregate BLS signature, and verifies
that the delivered Hyperlane message is included in the signed Merkle root.

The relayer is untrusted and has no signing authority.

## Reserve model

An ADD transition is payable. The attached value is locked as the validator's
deactivation reserve.

A REMOVE transition is non-payable. On successful removal, the executor is
credited reimbursement from the removed validator's reserve up to
`maxExecutorReimbursementWei`; the remainder is credited to the removed
validator. Both balances are withdrawn with `claim()`.

## Deployment order

1. deploy `XGRInterchainBLSVerifier`;
2. collect bootstrap possession proofs from the initial XGR interchain
   validators;
3. deploy `XGRInterchainValidatorRegistry` with the initial set and reserves;
4. deploy `XGRNativeInterchainISM` pointing at the registry and the canonical
   XGR Mailbox / MerkleTreeHook;
5. configure the Base recipient/router to use the ISM.

Do not deploy on a destination until the required EIP-2537 precompiles have been
verified on that chain.
