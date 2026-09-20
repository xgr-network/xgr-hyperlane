# XGR native interchain contracts

This directory contains the destination-side contracts for XGR native interchain membership.

The registry is deliberately separate from Hyperlane transport. Membership changes are authorized by the current XGR interchain validator quorum and use destination-chain native gas.

## Reserve model

An ADD transition is payable. The attached value is locked as the validator's deactivation reserve.

A REMOVE transition is non-payable. On successful removal, the executor is reimbursed from the removed validator's reserve up to `maxExecutorReimbursementWei`; the remainder is returned to the validator address.

The registry has no post-bootstrap administrator membership override.

## BLS verifier

`XGRInterchainValidatorRegistry` depends on `IXGRInterchainBLSVerifier`. The production verifier must be compatible with the exact Kryptology BLS12-381 serialization and ciphersuite used by XGR validators. It must be validated against deterministic vectors produced by the Go implementation before deployment.

Do not deploy the registry with an unvalidated verifier.
