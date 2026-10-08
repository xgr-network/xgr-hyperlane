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
