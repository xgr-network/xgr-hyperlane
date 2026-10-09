# Repository structure and legacy boundary

Active v3.1.4 Solidity: contracts/; active Forge tests: test/; active asset declarations: config/; immutable on-chain inventories: deployments/mainnet/.

Historical V1 verifier/ISM/source tests and the reverse deployment script are preserved verbatim as TXT under docs/legacy/source/. Old v3.1.2 and v3.1.3 deployment/plan docs moved to docs/legacy/. They are neither build inputs nor production instructions. Generic v3.1.4 contracts are not deleted or renamed. The historical v3.1.1 relayer start/stop scripts remain available ONLY to safely retire the service; remove these after on-server decommissioning, not before.

New guarded router implementation and live mainnet precompile / custody E2E tests remain activation blockers. Current XETAGatewayOnlyRouterGuard is a reusable mixin, NOT a functioning WarpRouter.
