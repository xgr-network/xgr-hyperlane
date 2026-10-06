// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {ILNRouteRegistry} from "../contracts/ILNRouteRegistry.sol";
import {ILNGateway} from "../contracts/ILNGateway.sol";
import {XGRILNInterchainISMV2} from "../contracts/XGRILNInterchainISMV2.sol";

interface IStaticAggregationIsmFactory {
    function deploy(address[] calldata modules, uint8 threshold)
        external
        returns (address);
}

abstract contract ILNBaseSpokeConstants is Script {
    uint64 internal constant XGR_CHAIN_ID = 1643;
    uint32 internal constant XGR_DOMAIN = 1643;
    uint32 internal constant BASE_DOMAIN = 8453;

    address internal constant XGR_NATIVE_BLS_VERIFIER =
        0x0000000000000000000000000000000000002040;
    address internal constant BASE_BLS_VERIFIER =
        0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93;

    uint8 internal constant VERIFIER_FORMAT_COMPRESSED = 1;
    uint8 internal constant VERIFIER_FORMAT_EIP2537 = 2;

    address internal constant XGR_MAILBOX =
        0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79;
    address internal constant XGR_MERKLE_TREE_HOOK =
        0xeD98Af715b5a72dCD412567eb086d48225CDDACF;
    address internal constant XGR_NATIVE_WARP_ROUTER =
        0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93;
    address internal constant XGR_DESTINATION_REGISTRY_V2 =
        0x013F2F2f7dB897F941b19C4ab71C5395a48A0292;
    address internal constant XGR_PAUSABLE_ISM =
        0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA;
    address internal constant XGR_STATIC_AGGREGATION_ISM_FACTORY =
        0xFEBEa0a947349E0aC857F9b7b248f1027804438e;

    address internal constant BASE_MAILBOX =
        0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D;
    address internal constant BASE_MERKLE_TREE_HOOK =
        0x19dc38aeae620380430C200a6E990D5Af5480117;
    address internal constant BASE_SYNTHETIC_WXGR_ROUTER =
        0x3b83687d77170D42feDDFe221629cc21e771e021;

    function _validatorMaterial()
        internal
        pure
        returns (
            address[] memory validators,
            bytes[] memory compressedKeys,
            bytes[] memory eip2537Keys
        )
    {
        validators = new address[](3);
        compressedKeys = new bytes[](3);
        eip2537Keys = new bytes[](3);

        // Canonical Interchain order: 98F8, 7E8f, 7913.
        validators[0] =
            0x98F8bC086454B8386788244eee9A43d5D0b4E63E;
        compressedKeys[0] =
            hex"a65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1";
        eip2537Keys[0] =
            hex"00000000000000000000000000000000065579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d10000000000000000000000000000000016ff663f783f1724010ed4271eb717536eef96f97a7fbc69593e9c2b841b12012945b436bf9055d99e2712411f66d2ab";

        validators[1] =
            0x7E8f8Fd2A198F77dF298041b48D79b0df4c8B1fa;
        compressedKeys[1] =
            hex"a32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71";
        eip2537Keys[1] =
            hex"00000000000000000000000000000000032a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71000000000000000000000000000000000e07952cb4fa21c27354f2f8efdbc81a0f5e248641125b3c0a713079ebe780889aed234ac226c3d892b2acf3210eeb7c";

        validators[2] =
            0x7913fDAe82C678F42B98Ca8076Fe7D13b3EdFF15;
        compressedKeys[2] =
            hex"b56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88";
        eip2537Keys[2] =
            hex"00000000000000000000000000000000156b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88000000000000000000000000000000000ff4b97c544a6915099d22d4b5abb6b35a3290cba39def4a1a8b902df5d94d9bc6bd98fe2f183e24fa16e41072de97fc";
    }

    function _proofs(
        string memory p0,
        string memory p1,
        string memory p2
    ) internal view returns (bytes[] memory proofs) {
        proofs = new bytes[](3);
        proofs[0] = vm.envBytes(p0);
        proofs[1] = vm.envBytes(p1);
        proofs[2] = vm.envBytes(p2);
    }
}

/// @notice Base-chain bootstrap. Deploys:
///  1) the new Base-destination RegistryV2 used by XGR -> Base ILN delivery;
///  2) a mirror of the XGR-destination validator set used by Base source
///     governance and validator-fe settlement.
///
/// This script does not activate any route and does not modify the existing
/// Base Warp router.
contract DeployILNBaseRegistries is ILNBaseSpokeConstants {
    function run()
        external
        returns (
            XGRInterchainValidatorRegistryV2 baseDestinationRegistry,
            XGRInterchainValidatorRegistryV2 xgrDestinationMirror
        )
    {
        require(block.chainid == 8453, "Base chain required");

        (
            address[] memory validators,
            bytes[] memory compressedKeys,
            bytes[] memory eip2537Keys
        ) = _validatorMaterial();

        bytes[] memory baseDestinationProofs = _proofs(
            "BASE_DESTINATION_BOOTSTRAP_PROOF_0",
            "BASE_DESTINATION_BOOTSTRAP_PROOF_1",
            "BASE_DESTINATION_BOOTSTRAP_PROOF_2"
        );
        bytes[] memory xgrMirrorProofs = _proofs(
            "XGR_DESTINATION_MIRROR_BOOTSTRAP_PROOF_0",
            "XGR_DESTINATION_MIRROR_BOOTSTRAP_PROOF_1",
            "XGR_DESTINATION_MIRROR_BOOTSTRAP_PROOF_2"
        );

        uint256 baseMinimumReserve =
            vm.envUint("BASE_DESTINATION_MINIMUM_RESERVE_WEI");
        uint256 baseMaxReimbursement =
            vm.envUint("BASE_DESTINATION_MAX_REIMBURSEMENT_WEI");
        uint256 baseReservePerValidator =
            vm.envUint("BASE_DESTINATION_BOOTSTRAP_RESERVE_PER_VALIDATOR_WEI");

        uint256 mirrorMinimumReserve =
            vm.envUint("ILN_MIRROR_MINIMUM_RESERVE_WEI");
        uint256 mirrorMaxReimbursement =
            vm.envUint("ILN_MIRROR_MAX_REIMBURSEMENT_WEI");
        uint256 mirrorReservePerValidator =
            vm.envUint("ILN_MIRROR_BOOTSTRAP_RESERVE_PER_VALIDATOR_WEI");

        require(
            baseReservePerValidator >= baseMinimumReserve &&
            mirrorReservePerValidator >= mirrorMinimumReserve,
            "bootstrap reserve below minimum"
        );

        vm.startBroadcast();

        baseDestinationRegistry =
            new XGRInterchainValidatorRegistryV2{
                value: baseReservePerValidator * validators.length
            }(
                XGR_CHAIN_ID,
                BASE_DOMAIN,
                BASE_BLS_VERIFIER,
                VERIFIER_FORMAT_EIP2537,
                baseMinimumReserve,
                baseMaxReimbursement,
                validators,
                compressedKeys,
                eip2537Keys,
                baseDestinationProofs
            );

        xgrDestinationMirror =
            new XGRInterchainValidatorRegistryV2{
                value: mirrorReservePerValidator * validators.length
            }(
                XGR_CHAIN_ID,
                XGR_DOMAIN,
                BASE_BLS_VERIFIER,
                VERIFIER_FORMAT_EIP2537,
                mirrorMinimumReserve,
                mirrorMaxReimbursement,
                validators,
                compressedKeys,
                eip2537Keys,
                xgrMirrorProofs
            );

        vm.stopBroadcast();
    }
}

/// @notice XGRChain bootstrap mirror of the Base-destination validator set.
/// @dev The exact same membership payloads can later be executed on this mirror
///      and the Base destination RegistryV2 because both share
///      originChainId=1643 and destinationDomain=8453.
contract DeployILNXGRBaseDestinationMirror is ILNBaseSpokeConstants {
    function run()
        external
        returns (XGRInterchainValidatorRegistryV2 baseDestinationMirror)
    {
        require(block.chainid == XGR_CHAIN_ID, "XGRChain required");

        (
            address[] memory validators,
            bytes[] memory compressedKeys,
            bytes[] memory eip2537Keys
        ) = _validatorMaterial();

        bytes[] memory proofs = _proofs(
            "BASE_DESTINATION_MIRROR_BOOTSTRAP_PROOF_0",
            "BASE_DESTINATION_MIRROR_BOOTSTRAP_PROOF_1",
            "BASE_DESTINATION_MIRROR_BOOTSTRAP_PROOF_2"
        );

        uint256 minimumReserve =
            vm.envUint("ILN_MIRROR_MINIMUM_RESERVE_WEI");
        uint256 maxReimbursement =
            vm.envUint("ILN_MIRROR_MAX_REIMBURSEMENT_WEI");
        uint256 reservePerValidator =
            vm.envUint("ILN_MIRROR_BOOTSTRAP_RESERVE_PER_VALIDATOR_WEI");

        require(
            reservePerValidator >= minimumReserve,
            "bootstrap reserve below minimum"
        );

        vm.startBroadcast();
        baseDestinationMirror =
            new XGRInterchainValidatorRegistryV2{
                value: reservePerValidator * validators.length
            }(
                XGR_CHAIN_ID,
                BASE_DOMAIN,
                XGR_NATIVE_BLS_VERIFIER,
                VERIFIER_FORMAT_COMPRESSED,
                minimumReserve,
                maxReimbursement,
                validators,
                compressedKeys,
                eip2537Keys,
                proofs
            );
        vm.stopBroadcast();
    }
}

/// @notice Deploys the Base source ILN registry and synthetic-wXGR gateway.
/// @dev No route is inserted. ROUTE_ADD remains validator-quorum governance.
contract DeployILNBaseSource is ILNBaseSpokeConstants {
    function run()
        external
        returns (
            ILNRouteRegistry routeRegistry,
            ILNGateway gateway
        )
    {
        require(block.chainid == 8453, "Base chain required");

        address xgrDestinationMirror =
            vm.envAddress("XGR_DESTINATION_MIRROR_V2");

        vm.startBroadcast();
        routeRegistry =
            new ILNRouteRegistry(BASE_DOMAIN, xgrDestinationMirror);
        gateway = new ILNGateway(
            address(routeRegistry),
            BASE_SYNTHETIC_WXGR_ROUTER,
            BASE_MAILBOX,
            BASE_MERKLE_TREE_HOOK,
            xgrDestinationMirror,
            false
        );
        vm.stopBroadcast();
    }
}

/// @notice Deploys the XGRChain source ILN registry and native-XGR gateway.
/// @dev The quote-principal flag is explicit because it is part of the deployed
///      Warp router's fee semantics, not an ILN heuristic.
contract DeployILNXGRSource is ILNBaseSpokeConstants {
    function run()
        external
        returns (
            ILNRouteRegistry routeRegistry,
            ILNGateway gateway
        )
    {
        require(block.chainid == XGR_CHAIN_ID, "XGRChain required");

        address baseDestinationMirror =
            vm.envAddress("BASE_DESTINATION_MIRROR_V2");
        bool quoteIncludesPrincipal =
            vm.envBool("XGR_NATIVE_QUOTE_INCLUDES_PRINCIPAL");

        vm.startBroadcast();
        routeRegistry =
            new ILNRouteRegistry(XGR_DOMAIN, baseDestinationMirror);
        gateway = new ILNGateway(
            address(routeRegistry),
            XGR_NATIVE_WARP_ROUTER,
            XGR_MAILBOX,
            XGR_MERKLE_TREE_HOOK,
            baseDestinationMirror,
            quoteIncludesPrincipal
        );
        vm.stopBroadcast();
    }
}

/// @notice Deploys the Base destination message-specific ILN ISM.
/// @dev The existing Base wXGR router is not modified by this script.
contract DeployILNBaseDestinationISM is ILNBaseSpokeConstants {
    function run()
        external
        returns (XGRILNInterchainISMV2 ism)
    {
        require(block.chainid == 8453, "Base chain required");

        address baseDestinationRegistry =
            vm.envAddress("BASE_DESTINATION_REGISTRY_V2");
        address xgrSourceRegistry =
            vm.envAddress("XGR_ILN_REGISTRY");
        address xgrSourceGateway =
            vm.envAddress("XGR_ILN_GATEWAY");

        vm.startBroadcast();
        ism = new XGRILNInterchainISMV2(
            baseDestinationRegistry,
            XGR_CHAIN_ID,
            XGR_DOMAIN,
            xgrSourceRegistry,
            xgrSourceGateway,
            XGR_NATIVE_WARP_ROUTER,
            XGR_MAILBOX,
            XGR_MERKLE_TREE_HOOK,
            BASE_SYNTHETIC_WXGR_ROUTER
        );
        vm.stopBroadcast();
    }
}

/// @notice Deploys the XGR destination ILN ISM and a fresh 2-of-2 static
///         aggregation with the existing PausableISM.
/// @dev The existing DomainRoutingISM is NOT updated by this script.
contract DeployILNXGRDestinationISM is ILNBaseSpokeConstants {
    function run()
        external
        returns (
            XGRILNInterchainISMV2 ism,
            address aggregation
        )
    {
        require(block.chainid == XGR_CHAIN_ID, "XGRChain required");

        address baseSourceRegistry =
            vm.envAddress("BASE_ILN_REGISTRY");
        address baseSourceGateway =
            vm.envAddress("BASE_ILN_GATEWAY");

        vm.startBroadcast();

        ism = new XGRILNInterchainISMV2(
            XGR_DESTINATION_REGISTRY_V2,
            8453,
            BASE_DOMAIN,
            baseSourceRegistry,
            baseSourceGateway,
            BASE_SYNTHETIC_WXGR_ROUTER,
            BASE_MAILBOX,
            BASE_MERKLE_TREE_HOOK,
            XGR_NATIVE_WARP_ROUTER
        );

        address[] memory modules = new address[](2);
        modules[0] = XGR_PAUSABLE_ISM;
        modules[1] = address(ism);

        aggregation = IStaticAggregationIsmFactory(
            XGR_STATIC_AGGREGATION_ISM_FACTORY
        ).deploy(modules, 2);

        vm.stopBroadcast();
    }
}
