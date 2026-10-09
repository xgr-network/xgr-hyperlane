// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IXGRILNRegistry} from "./IXGRILNRegistry.sol";

/// @notice Guard MIXIN for NEW Warp routers; not a deployable Warp router.
/// @dev Apply modifier on actual outbound transferRemote only; preserve Mailbox inbound handle.
abstract contract XETAGatewayOnlyRouterGuard {
    IXGRILNRegistry public immutable xetaRegistry;
    bytes32 public immutable xetaRouteId;
    uint32 public immutable xetaDestinationDomain;
    error UnauthorizedXETAGateway();
    error InvalidXETARoute();
    constructor(address registry_, bytes32 routeId_, uint32 destinationDomain_) {
        if (registry_ == address(0) || routeId_ == bytes32(0) || destinationDomain_ == 0)
            revert InvalidXETARoute();
        xetaRegistry = IXGRILNRegistry(registry_);
        xetaRouteId = routeId_;
        xetaDestinationDomain = destinationDomain_;
    }
    modifier onlyXETAGateway(uint32 destination) {
        if (destination != xetaDestinationDomain) revert InvalidXETARoute();
        (
            uint64 sourceChainId, , address gateway, address sourceRouter,
            , , , , bool enabled
        ) = xetaRegistry.getRoute(destination, xetaRouteId);
        if (!enabled || sourceChainId != uint64(block.chainid) ||
            gateway == address(0) || gateway != msg.sender || sourceRouter != address(this))
            revert UnauthorizedXETAGateway();
        _;
    }
}
