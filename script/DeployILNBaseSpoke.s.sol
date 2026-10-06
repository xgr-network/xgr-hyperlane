// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {ILNGateway} from "../contracts/ILNGateway.sol";
import {XGRILNInterchainISM} from "../contracts/XGRILNInterchainISM.sol";
import {XGRILNInterchainISMV2} from "../contracts/XGRILNInterchainISMV2.sol";

interface IStaticAggregationIsmFactory {
    function deploy(
        address[] calldata modules,
        uint8 threshold
    ) external returns (address);
}

abstract contract ILNBaseSpokeConstants is Script {
    uint64 internal constant XGR_CHAIN_ID = 1643;
    uint32 internal constant XGR_DOMAIN = 1643;
    uint32 internal constant BASE_DOMAIN = 8453;

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
    address internal constant BASE_DESTINATION_REGISTRY_V1 =
        0x70F5752326735b31641f21D174BA035E904Db93c;

    function _launchFee()
        internal
        view
        returns (uint256 fee)
    {
        fee = vm.envUint("ILN_LAUNCH_VALIDATOR_FEE_WEI");
        require(fee > 0, "fee must be positive");
    }
}

/// @notice Deploy the immutable Base -> XGR ILN source Gateway.
/// @dev The Gateway is also the source ILN registry.
contract DeployILNBaseSource is ILNBaseSpokeConstants {
    function run()
        external
        returns (ILNGateway gateway)
    {
        require(block.chainid == 8453, "Base chain required");

        vm.startBroadcast();
        gateway = new ILNGateway(
            BASE_DOMAIN,
            XGR_DOMAIN,
            BASE_SYNTHETIC_WXGR_ROUTER,
            BASE_MAILBOX,
            BASE_MERKLE_TREE_HOOK,
            XGR_NATIVE_WARP_ROUTER,
            _launchFee(),
            false
        );
        vm.stopBroadcast();
    }
}

/// @notice Deploy the immutable XGR -> Base ILN source Gateway.
/// @dev The current native Warp quote does not include the XGR principal;
///      ILNGateway therefore adds the principal explicitly.
contract DeployILNXGRSource is ILNBaseSpokeConstants {
    function run()
        external
        returns (ILNGateway gateway)
    {
        require(block.chainid == XGR_CHAIN_ID, "XGRChain required");

        vm.startBroadcast();
        gateway = new ILNGateway(
            XGR_DOMAIN,
            BASE_DOMAIN,
            XGR_NATIVE_WARP_ROUTER,
            XGR_MAILBOX,
            XGR_MERKLE_TREE_HOOK,
            BASE_SYNTHETIC_WXGR_ROUTER,
            _launchFee(),
            false
        );
        vm.stopBroadcast();
    }
}

/// @notice Deploy Base destination message-specific ILN security using the
///         already deployed Base V1 validator registry and BLS verifier.
/// @dev The existing Base wXGR router is not modified by this script.
contract DeployILNBaseDestinationISM is ILNBaseSpokeConstants {
    function run()
        external
        returns (XGRILNInterchainISM ism)
    {
        require(block.chainid == 8453, "Base chain required");

        address xgrSourceGateway =
            vm.envAddress("XGR_ILN_GATEWAY");

        vm.startBroadcast();
        ism = new XGRILNInterchainISM(
            BASE_DESTINATION_REGISTRY_V1,
            XGR_CHAIN_ID,
            XGR_DOMAIN,
            xgrSourceGateway,
            xgrSourceGateway,
            XGR_NATIVE_WARP_ROUTER,
            XGR_MAILBOX,
            XGR_MERKLE_TREE_HOOK,
            BASE_SYNTHETIC_WXGR_ROUTER
        );
        vm.stopBroadcast();
    }
}

/// @notice Deploy XGR destination message-specific ILN security using the
///         existing XGR RegistryV2, then compose it with the existing
///         PausableISM in a fresh 2-of-2 StaticAggregationISM.
/// @dev The existing DomainRoutingISM is not modified by this script.
contract DeployILNXGRDestinationISM is ILNBaseSpokeConstants {
    function run()
        external
        returns (
            XGRILNInterchainISMV2 ism,
            address aggregation
        )
    {
        require(block.chainid == XGR_CHAIN_ID, "XGRChain required");

        address baseSourceGateway =
            vm.envAddress("BASE_ILN_GATEWAY");

        vm.startBroadcast();

        ism = new XGRILNInterchainISMV2(
            XGR_DESTINATION_REGISTRY_V2,
            8453,
            BASE_DOMAIN,
            baseSourceGateway,
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
