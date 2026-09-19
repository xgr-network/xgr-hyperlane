# Security Policy

## Reporting a vulnerability

Please report security issues privately to **info@xgr.network**.

Do not disclose private keys, seed phrases, credentials, exploit material that
would place live funds at immediate risk, or other sensitive infrastructure
details in a public GitHub issue.

## Scope

This repository contains deployment metadata and runtime configuration for the
XGRChain Hyperlane integration. Security reports may concern:

- deployed Hyperlane contracts referenced by this repository;
- validator or relayer configuration;
- checkpoint publication and retrieval;
- route verification configuration;
- deployment automation;
- bridge UI assumptions documented here.

The XGRChain node implementation itself is maintained separately in
`xgr-network/xgr-node`.

## Current launch posture

The XGRChain ↔ Base route is currently fail-closed and must remain unavailable
to users until the rollout checklist in `docs/operations.md` is complete.
