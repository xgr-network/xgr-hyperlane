#!/usr/bin/env node
// Non-mutating validator for the desired chain/asset configuration and the
// separately observed mainnet deployment manifests.
import { readFileSync, readdirSync } from "node:fs";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const isAddress = (v) => typeof v === "string" && /^0x[0-9a-fA-F]{40}$/.test(v) && !/^0x0{40}$/.test(v);
const isHash = (v) => typeof v === "string" && /^0x[0-9a-fA-F]{64}$/.test(v) && !/^0x0{64}$/.test(v);
const isCount = (v) => Number.isSafeInteger(v) && v > 0;
const positiveWei = (v) => typeof v === "string" && /^[1-9]\d*$/.test(v);
const same = (a, b) => typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();

function readJSON(root, relative) {
  try {
    return JSON.parse(readFileSync(join(root, relative), "utf8"));
  } catch (error) {
    throw new Error(relative + ": " + error.message, { cause: error });
  }
}

function jsonFiles(root, relative) {
  return readdirSync(join(root, relative), { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.endsWith(".json"))
    .map((e) => e.name).sort();
}

export function loadCatalog(root = ROOT) {
  const chains = {};
  for (const name of jsonFiles(root, "config/chains")) {
    const id = name.slice(0, -5);
    chains[id] = readJSON(root, "config/chains/" + name);
  }
  const assets = {};
  const directories = readdirSync(join(root, "config/assets"), { withFileTypes: true })
    .filter((e) => e.isDirectory()).map((e) => e.name).sort();
  for (const id of directories) {
    assets[id] = {
      metadata: readJSON(root, "config/assets/" + id + "/asset.json"),
      routes: readJSON(root, "config/assets/" + id + "/routes.json"),
      mainnet: readJSON(root, "config/assets/" + id + "/mainnet.json"),
      deployment: readJSON(root, "deployments/mainnet/assets/" + id + ".json"),
    };
  }
  const infrastructure = {};
  for (const chain of Object.keys(chains)) {
    infrastructure[chain] = readJSON(root, "deployments/mainnet/infrastructure/" + chain + ".json");
  }
  return {
    chains, assets, infrastructure,
    legacyXgrRoute: readJSON(root, "deployments/xgr-base-route.json"),
    legacyXgrChain: readJSON(root, "deployments/xgrchain-mainnet.json"),
  };
}

export function validateCatalog(catalog) {
  const errors = [];
  const check = (condition, message) => { if (!condition) errors.push(message); };
  const { chains, assets, infrastructure, legacyXgrRoute: legacy, legacyXgrChain: original } = catalog;
  const occupiedChainIDs = new Map(), occupiedDomains = new Map();
  check(Object.keys(chains).length >= 2, "expected at least two configured chains");
  for (const [name, chain] of Object.entries(chains)) {
    const prefix = "config/chains/" + name;
    check(chain.schemaVersion === 1 && chain.kind === "chain-config", prefix + ": invalid schema");
    check(chain.name === name && chain.environment === "mainnet", prefix + ": invalid identity");
    check(isCount(chain.chainId) && isCount(chain.domainId), prefix + ": chainId/domainId must be positive integers");
    if (occupiedChainIDs.has(chain.chainId)) errors.push(prefix + ": duplicate chainId with " + occupiedChainIDs.get(chain.chainId));
    if (occupiedDomains.has(chain.domainId)) errors.push(prefix + ": duplicate domainId with " + occupiedDomains.get(chain.domainId));
    occupiedChainIDs.set(chain.chainId, name);
    occupiedDomains.set(chain.domainId, name);
    check(Array.isArray(chain.rpcUrls) && chain.rpcUrls.length > 0 &&
      chain.rpcUrls.every((x) => typeof x === "string" && x.startsWith("https://")),
      prefix + ": production RPC must be HTTPS");
    check(Number.isSafeInteger(chain.confirmations) && chain.confirmations >= 1, prefix + ": invalid confirmations");
    check(["compressed", "eip2537"].includes(chain.blsVerifierFormat), prefix + ": invalid BLS verifier format");
    check(chain.nativeCurrency && typeof chain.nativeCurrency.symbol === "string" &&
      Number.isInteger(chain.nativeCurrency.decimals) && chain.nativeCurrency.decimals >= 0,
      prefix + ": invalid native currency");

    const observed = infrastructure[name];
    check(!!observed, prefix + ": missing infrastructure deployment inventory");
    if (!observed) continue;
    check(observed.schemaVersion === 1 && observed.kind === "infrastructure-deployment", prefix + ": invalid infrastructure schema");
    check(observed.network === "mainnet" && observed.chain === name &&
      observed.chainId === chain.chainId && observed.domainId === chain.domainId,
      prefix + ": inconsistent observed infrastructure identity");
    check(chain.observedInfrastructure === "deployments/mainnet/infrastructure/" + name + ".json",
      prefix + ": wrong observedInfrastructure path");
    check(observed.hyperlaneCore && isAddress(observed.hyperlaneCore.mailbox) &&
      isAddress(observed.hyperlaneCore.merkleTreeHook), prefix + ": missing observed Mailbox/MerkleTreeHook");
    const iln = observed.ilnV314;
    check(iln && ["unverified-not-activated", "verified-deployed"].includes(iln.status),
      prefix + ": unknown ILN infrastructure verification status");
    if (iln?.status === "unverified-not-activated") {
      check(iln.sourceRegistry === null && iln.destinationRegistryV2 === null &&
        iln.destinationIsmV2 === null && iln.blsVerifier === null,
        prefix + ": do not claim unverified ILN v3.1.4 infrastructure as deployed");
    } else if (iln?.status === "verified-deployed") {
      check(isCount(iln.verifiedAtBlock), prefix + ": verified infrastructure requires block evidence");
      for (const key of ["sourceRegistry","destinationRegistryV2","destinationIsmV2","blsVerifier"]) {
        check(iln[key] === null || isAddress(iln[key]), prefix + ": invalid verified " + key);
      }
      check(isAddress(iln.sourceRegistry) || isAddress(iln.destinationIsmV2),
        prefix + ": verified infrastructure requires a deployed source registry or destination ISM");
      if (isAddress(iln.destinationIsmV2)) {
        check(isAddress(iln.destinationRegistryV2) && isAddress(iln.blsVerifier),
          prefix + ": destination ISM requires verified registry and verifier");
      }
    }
  }
  const names = new Set();
  check(Object.keys(assets).length > 0, "no asset configurations");
  for (const [id, asset] of Object.entries(assets)) {
    const p = "config/assets/" + id;
    const { metadata, routes, mainnet, deployment } = asset;
    check(metadata.kind === "asset-config" && metadata.schemaVersion === 1 && metadata.asset === id,
      p + ": invalid metadata schema/identity");
    check(metadata.symbol && Number.isSafeInteger(metadata.decimals) && metadata.decimals >= 0 && metadata.decimals <= 36, p + ": invalid decimals or symbol");
    check(metadata.canonical && chains[metadata.canonical.chain], p + ": unknown canonical chain");
    check(Array.isArray(metadata.representations) && metadata.representations.length >= 2,
      p + ": missing representations");
    const repChains = new Set();
    for (const representation of metadata.representations || []) {
      check(!!chains[representation.chain], p + ": unknown representation chain " + representation.chain);
      check(!repChains.has(representation.chain), p + ": duplicated representation on " + representation.chain);
      repChains.add(representation.chain);
      check(["native", "synthetic", "collateral"].includes(representation.representation),
        p + ": unsupported representation type");
      // Canonical ERC-20 contract address is an asset identity, not a claim
      // that this route's gateway/ISM has been deployed.
      check(representation.representation === "native"
        ? representation.assetAddress === null
        : representation.assetAddress === null || isAddress(representation.assetAddress),
        p + ": representation address must be a valid ERC-20 or null for native");
    }
    check(routes.schemaVersion === 1 && routes.kind === "asset-routes" &&
      routes.asset === id && routes.network === "mainnet" && routes.protocol === "ILN-v3.1.4",
      p + ": invalid routes manifest");
    check(Array.isArray(routes.routes) && routes.routes.length > 0, p + ": routes are required");
    for (const route of routes.routes || []) {
      check(typeof route.name === "string" && /^[a-z0-9_]+$/.test(route.name),
        p + ": invalid route name");
      check(!names.has(id + ":" + route.name), p + ": duplicate route " + route.name);
      names.add(id + ":" + route.name);
      check(!!chains[route.sourceChain] && !!chains[route.destinationChain] &&
        route.sourceChain !== route.destinationChain &&
        repChains.has(route.sourceChain) && repChains.has(route.destinationChain),
        p + ": invalid route chain endpoints " + route.name);
      check(["pending-governance", "quorum-activated"].includes(route.activation),
        p + ": unknown route activation " + route.name);
      // Before deployment a route may be fully unspecified. Once proposed,
      // route ID and fee are an inseparable, explicit pair. Governance alone
      // can activate it; JSON cannot.
      if (route.activation === "pending-governance") {
        check((route.routeId === null && route.validatorFeeWei === null) ||
          (isHash(route.routeId) && positiveWei(route.validatorFeeWei)),
          p + ": unapproved ILN route requires null fields or a complete route ID and fee: " + route.name);
      } else {
        check(isHash(route.routeId) && positiveWei(route.validatorFeeWei),
          p + ": activated ILN route must have verified nonzero route ID and source-native fee");
      }
    }
    check(mainnet.kind === "asset-network-config" && mainnet.schemaVersion === 1 &&
      mainnet.asset === id && mainnet.network === "mainnet" &&
      mainnet.routeManifest === p + "/routes.json" &&
      mainnet.deploymentManifest === "deployments/mainnet/assets/" + id + ".json",
      p + ": mainnet config references wrong manifests");
    check(["not-authorized", "governance-confirmed"].includes(mainnet.ilnV314Activation),
      p + ": unknown mainnet ILN authorization status");
    check(deployment.kind === "asset-deployment" && deployment.schemaVersion === 1 &&
      deployment.asset === id && deployment.network === "mainnet",
      p + ": missing observed asset deployment");
    check(deployment.ilnV314 && ["unverified-not-activated",
      "deployed-pending-governance", "active"].includes(deployment.ilnV314.status),
      p + ": unknown ILN v3.1.4 asset deployment state");
    const observedRoutes = deployment.ilnV314?.routes || [];
    for (const route of routes.routes || []) {
      const observed = observedRoutes.find((item) => item.name === route.name);
      check(observed && observed.sourceChain === route.sourceChain &&
        observed.destinationChain === route.destinationChain, p + ": missing observed route shell " + route.name);
      if (!observed) continue;
      const empty = observed.routeId === null && observed.gateway === null &&
        observed.feeVault === null && observed.validatorFeeWei === null &&
        observed.governanceTx === null;
      const deployed = isHash(observed.routeId) && isAddress(observed.gateway) &&
        isAddress(observed.feeVault) && positiveWei(observed.validatorFeeWei);
      if (route.routeId === null) {
        check(empty, p + ": unverified ILN route must have no on-chain addresses/route IDs");
      } else {
        check(deployed && same(observed.routeId, route.routeId) &&
          observed.validatorFeeWei === route.validatorFeeWei,
          p + ": deployed ILN route must match its route ID, gateway, vault and fee");
      }
      if (route.activation === "pending-governance") {
        check(observed.governanceTx === null,
          p + ": pending route must not claim governance activation");
      } else {
        check(deployed && isHash(observed.governanceTx),
          p + ": activated ILN route requires on-chain governance transaction evidence");
        const origin= infrastructure[route.sourceChain]?.ilnV314;
        const target= infrastructure[route.destinationChain]?.ilnV314;
        check(origin?.status === "verified-deployed" && isAddress(origin.sourceRegistry) &&
          target?.status === "verified-deployed" && isAddress(target.destinationIsmV2),
          p + ": activated route requires verified source registry and destination ISM");
      }
    }
    check(observedRoutes.length === (routes.routes || []).length, p + ": desired and observed routes differ");
    const allUnconfigured = (routes.routes || []).every((r) => r.routeId === null);
    const anyActive = (routes.routes || []).some((r) => r.activation === "quorum-activated");
    check(mainnet.ilnV314Activation === (anyActive ? "governance-confirmed" : "not-authorized"),
      p + ": activation summary does not match route governance state");
    check(deployment.ilnV314?.status ===
      (anyActive ? "active" : allUnconfigured ? "unverified-not-activated" : "deployed-pending-governance"),
      p + ": deployment state does not match observed route readiness");
  }
  // Preserve the actual v3.1.1 XGRChain/Base mainnet inventory; never fabricate
  // v3.1.4 contract addresses from these older deployed Warp routers.
  const xgr = assets.XGR?.deployment;
  const xgrChain = infrastructure.xgrchain;
  const base = infrastructure.base;
  check(!!xgr && !!xgrChain && !!base, "XGR legacy baseline missing");
  if (xgr && xgrChain && base) {
    check(xgr.inventorySource === "deployments/xgr-base-route.json", "XGR legacy evidence path changed");
    check(same(xgr.legacy?.routers?.xgrchain?.address, legacy.warp.xgrNativeRouter.address),
      "XGR legacy native Warp router mismatches canonical inventory");
    check(same(xgr.legacy?.routers?.base?.address, legacy.warp.baseSyntheticRouter.address),
      "XGR legacy Base synthetic router mismatches canonical inventory");
    check(same(xgr.legacy?.routers?.xgrchain?.deploymentTx, legacy.warp.xgrNativeRouter.deploymentTx),
      "XGR legacy native router transaction mismatches canonical inventory");
    check(xgr.legacy?.routers?.base?.deploymentTx === legacy.warp.baseSyntheticRouter.deploymentTx,
      "XGR legacy Base router transaction record changed");
    check(same(xgrChain.hyperlaneCore?.mailbox, original.contracts.mailbox) &&
      same(xgrChain.hyperlaneCore?.merkleTreeHook, original.contracts.merkleTreeHook) &&
      same(xgrChain.legacySecurity?.destinationRegistryV2, original.contracts.reverseValidatorRegistryV2),
      "XGRChain infrastructure mismatches legacy inventory");
    check(same(base.hyperlaneCore?.mailbox, legacy.base.mailbox) &&
      same(base.hyperlaneCore?.merkleTreeHook, legacy.base.merkleTreeHook) &&
      same(base.legacySecurity?.destinationRegistryV1, legacy.base.forwardSecurity.validatorRegistry.address),
      "Base infrastructure mismatches legacy inventory");
    for (const [routeName, proof] of Object.entries({
      xgr_to_base:legacy.e2eEvidence.xgrToBase,
      base_to_xgr:legacy.e2eEvidence.baseToXgr,
    })) {
      const target=xgr.legacy?.e2eEvidence?.[routeName];
      check(same(target?.messageId,proof.messageId) &&
        same(target?.sourceTx,proof.originTransaction) &&
        same(target?.destinationTx,proof.destinationTransaction),
        "XGR historical delivery evidence changed: " + routeName);
    }
  }
  return errors;
}

export function validateRepository(root = ROOT) {
  return validateCatalog(loadCatalog(root));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const errors=validateRepository();
    if (errors.length) {
      for (const error of errors) console.error("INVALID: " + error);
      process.exitCode=1;
    } else console.log("PASS: multi-chain, per-asset and legacy deployment manifests are internally consistent.");
  } catch (error) {
    console.error("INVALID: " + error.message);
    process.exitCode=1;
  }
}
