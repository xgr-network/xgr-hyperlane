// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IXGRILNRegistry} from "./IXGRILNRegistry.sol";

/// @notice Shared outbound authorization for XETA's pinned Hyperlane TokenRouter.
/// @dev The public TokenRouter.transferRemote delegates to _transferRemote.
///      Concrete routers MUST override _transferRemote with this guard.
///      Only the Hyperlane Mailbox may invoke Router.handle (unchanged).
///      One guarded Warp router is bound to exactly one source ILN route.
abstract contract XETAGatewayOnlyRouterGuard {
    IXGRILNRegistry public immutable xetaRegistry;
    bytes32 public immutable xetaRouteId;
    uint32 public immutable xetaDestinationDomain;
    bool public xetaRemoteRouterInitialized;

    error XETAInvalidConfiguration();
    error XETAInvalidRoute();
    error XETAUnauthorizedGateway();
    error XETAAlreadyInitialized();

    constructor(address registry_, bytes32 routeId_, uint32 destinationDomain_) {
        if (
            registry_ == address(0) ||
            registry_.code.length == 0 ||
            routeId_ == bytes32(0) ||
            destinationDomain_ == 0
        ) revert XETAInvalidConfiguration();
        xetaRegistry = IXGRILNRegistry(registry_);
        xetaRouteId = routeId_;
        xetaDestinationDomain = destinationDomain_;
    }

    // Actual Hyperlane Router state, not caller-supplied values.
    function _xetaRouterState(uint32 destination)
        internal view virtual
        returns (uint32 localDomain_, address mailbox_, address hook_, bytes32 remote_);

    function _xetaEnrollRemote(uint32 destination, bytes32 remote)
        internal virtual;

    /// @notice One-time, permissionless remote enrollment AFTER governance.
    /// @dev Solves the circular router-address deployment problem without a
    ///      company-controlled owner or a mutation of the signed route.
    function bootstrapXETARemoteRouter() external {
        if (xetaRemoteRouterInitialized) revert XETAAlreadyInitialized();

        IXGRILNRegistry.RouteRecord memory route = _xetaCanonicalRoute();
        (, , , bytes32 currentRemote) = _xetaRouterState(xetaDestinationDomain);
        if (currentRemote != bytes32(0)) revert XETAInvalidRoute();

        xetaRemoteRouterInitialized = true;
        _xetaEnrollRemote(
            xetaDestinationDomain,
            bytes32(uint256(uint160(route.destinationRouter)))
        );
    }

    modifier onlyXETAGateway(uint32 destination) {
        if (destination != xetaDestinationDomain || !xetaRemoteRouterInitialized)
            revert XETAInvalidRoute();

        IXGRILNRegistry.RouteRecord memory route = _xetaCanonicalRoute();
        (, , , bytes32 enrolledRemote) = _xetaRouterState(destination);

        if (
            msg.sender != route.gateway ||
            enrolledRemote != bytes32(uint256(uint160(route.destinationRouter)))
        ) revert XETAUnauthorizedGateway();
        _;
    }

    function _xetaCanonicalRoute() internal view
        returns (IXGRILNRegistry.RouteRecord memory route)
    {
        (
            route.sourceChainId,
            route.sourceDomain,
            route.gateway,
            route.sourceRouter,
            route.mailbox,
            route.merkleTreeHook,
            route.destinationRouter,
            route.validatorFeeWei,
            route.enabled
        ) = xetaRegistry.getRoute(xetaDestinationDomain, xetaRouteId);

        (uint32 localDomain_, address mailbox_, address hook_,) =
            _xetaRouterState(xetaDestinationDomain);

        if (
            !route.enabled ||
            route.sourceChainId != uint64(block.chainid) ||
            route.sourceDomain != localDomain_ ||
            route.gateway == address(0) ||
            route.sourceRouter != address(this) ||
            route.mailbox != mailbox_ ||
            route.merkleTreeHook != hook_ ||
            route.destinationRouter == address(0) ||
            route.validatorFeeWei == 0
        ) revert XETAInvalidRoute();
    }
}
