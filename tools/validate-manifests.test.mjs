import test from "node:test";
import assert from "node:assert/strict";
import { loadCatalog, validateCatalog } from "./validate-manifests.mjs";

const copy = () => structuredClone(loadCatalog());
test("current multi-asset layout validates and preserves legacy evidence", () => {
  assert.deepEqual(validateCatalog(copy()), []);
});
test("rejects duplicate domains", () => {
  const x=copy();
  x.chains.base.domainId=1643;
  assert.ok(validateCatalog(x).some(s=>s.includes("duplicate domainId")));
});
test("rejects phantom chain destinations", () => {
  const x=copy();
  x.assets.XGR.routes.routes[0].destinationChain="unknown";
  assert.ok(validateCatalog(x).some(s=>s.includes("invalid route chain endpoints")));
});
test("pending ILN routes must not be silently activated", () => {
  const x=copy();
  x.assets.XGR.routes.routes[0].routeId="0x"+"a".repeat(64);
  assert.ok(validateCatalog(x).some(s=>s.includes("unapproved ILN route")));
});
test("rejects a forged observed ILN gateway", () => {
  const x=copy();
  x.assets.XGR.deployment.ilnV314.routes[0].gateway="0x"+"1".repeat(40);
  assert.ok(validateCatalog(x).some(s=>s.includes("must have no on-chain addresses")));
});
test("existing XGR native Warp router is immutable inventory", () => {
  const x=copy();
  x.assets.XGR.deployment.legacy.routers.xgrchain.address="0x"+"2".repeat(40);
  assert.ok(validateCatalog(x).some(s=>s.includes("legacy native Warp router mismatches")));
});
test("historic successful delivery evidence cannot drift", () => {
  const x=copy();
  x.assets.XGR.deployment.legacy.e2eEvidence.base_to_xgr.messageId="0x"+"3".repeat(64);
  assert.ok(validateCatalog(x).some(s=>s.includes("historical delivery evidence changed")));
});
test("source-chain fee must not be implied before governance", () => {
  const x=copy();
  x.assets.XGR.routes.routes[1].validatorFeeWei="123456";
  assert.ok(validateCatalog(x).some(s=>s.includes("unapproved ILN route")));
});


test("zero-decimal ERC-20 assets are valid canonical representations", () => {
  const x=copy();
  x.assets.XGR.metadata.decimals=0;
  x.assets.XGR.metadata.representations[0].representation="collateral";
  x.assets.XGR.metadata.representations[0].assetAddress="0x"+"8".repeat(40);
  x.assets.XGR.metadata.canonical.representation="collateral";
  assert.deepEqual(validateCatalog(x), []);
});
test("canonical representation cannot differ from its source chain", () => {
  const x=copy();
  x.assets.XGR.metadata.canonical.representation="collateral";
  assert.ok(validateCatalog(x).some(s=>s.includes("canonical asset representation differs")));
});
test("a verified and source-quorum-activated route is supported without changing validator", () => {
  const x=copy();
  const source=x.infrastructure.xgrchain.ilnV314;
  source.status="verified-deployed";
  source.verifiedAtBlock=100;
  source.sourceRegistry="0x"+"1".repeat(40);
  const destination=x.infrastructure.base.ilnV314;
  destination.status="verified-deployed";
  destination.verifiedAtBlock=200;
  destination.destinationRegistryV2="0x"+"2".repeat(40);
  destination.destinationIsmV2="0x"+"3".repeat(40);
  destination.blsVerifier="0x"+"4".repeat(40);
  const desired=x.assets.XGR.routes.routes[0];
  const observed=x.assets.XGR.deployment.ilnV314.routes[0];
  desired.routeId="0x"+"5".repeat(64);
  desired.validatorFeeWei="1000";
  desired.activation="quorum-activated";
  observed.routeId=desired.routeId;
  observed.validatorFeeWei=desired.validatorFeeWei;
  observed.gateway="0x"+"6".repeat(40);
  observed.feeVault="0x"+"7".repeat(40);
  observed.governanceTx="0x"+"8".repeat(64);
  x.assets.XGR.deployment.ilnV314.status="active";
  x.assets.XGR.mainnet.ilnV314Activation="governance-confirmed";
  assert.deepEqual(validateCatalog(x), []);
});
test("an active route requires a verified destination ISM and governance evidence", () => {
  const x=copy();
  x.assets.XGR.routes.routes[0].activation="quorum-activated";
  x.assets.XGR.routes.routes[0].routeId="0x"+"a".repeat(64);
  x.assets.XGR.routes.routes[0].validatorFeeWei="999";
  const errors=validateCatalog(x);
  assert.ok(errors.some(s=>s.includes("activated ILN route requires on-chain governance")));
  assert.ok(errors.some(s=>s.includes("activated route requires verified source registry")));
});
test("route IDs are unique within an identical source and destination", () => {
  const x=copy();
  const original=x.assets.XGR.routes.routes[0];
  original.routeId="0x"+"b".repeat(64);
  original.validatorFeeWei="1";
  const duplicate=structuredClone(original);
  duplicate.name="xgr_to_base_second";
  x.assets.XGR.routes.routes.push(duplicate);
  assert.ok(validateCatalog(x).some(s=>s.includes("duplicate canonical ILN route ID")));
});
