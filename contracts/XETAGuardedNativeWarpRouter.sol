// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenRouter} from "@hyperlane-xyz/core/contracts/token/libs/TokenRouter.sol";
import {NativeCollateral} from "@hyperlane-xyz/core/contracts/token/libs/TokenCollateral.sol";
import {XETAGatewayOnlyRouterGuard} from "./XETAGatewayOnlyRouterGuard.sol";

/// @notice Native XGR custodial Warp router, using Hyperlane's TokenRouter
///         messaging and native collateral library (without LP/vault features).
/// @dev Contract owns no privileged owner after atomic constructor initialization.
///      A governance-approved route must be bootstrapped once before transfers.
contract XETAGuardedNativeWarpRouter is TokenRouter, XETAGatewayOnlyRouterGuard {
    uint256 public immutable xetaDestinationGasLimit;

    constructor(
        address registry_,
        bytes32 routeId_,
        uint32 destinationDomain_,
        address mailbox_,
        address merkleTreeHook_,
        address destinationIsm_,
        uint256 destinationGasLimit_
    )
        TokenRouter(1, 1, mailbox_)
        XETAGatewayOnlyRouterGuard(registry_, routeId_, destinationDomain_)
    {
        if (
            destinationGasLimit_ == 0 ||
            merkleTreeHook_ == address(0) ||
            destinationIsm_ == address(0)
        ) revert XETAInvalidConfiguration();

        xetaDestinationGasLimit = destinationGasLimit_;
        _xetaInitialize(merkleTreeHook_, destinationIsm_);
    }

    // Initializer is consumed IN the constructor. No public initialize method.
    function _xetaInitialize(address hook_, address ism_) private initializer {
        _MailboxClient_initialize(hook_, ism_, address(0));
    }

    function token() public pure override returns (address) {
        return address(0);
    }

    function _transferFromSender(uint256 amount) internal override {
        NativeCollateral._transferFromSender(amount);
    }

    function _transferTo(address recipient, uint256 amount) internal override {
        NativeCollateral._transferTo(recipient, amount);
    }

    /// @dev Secures the INTERNAL token-dispatch path, including inherited
    ///      transferRemote. All lock/dispatch flows go through this override.
    function _transferRemote(uint32 destination, bytes32 recipient, uint256 amount)
        internal override onlyXETAGateway(destination)
        returns (bytes32 messageId)
    {
        return super._transferRemote(destination, recipient, amount);
    }

    function _xetaRouterState(uint32 destination)
        internal view override
        returns (uint32 localDomain_, address mailbox_, address hook_, bytes32 remote_)
    {
        return (localDomain, address(mailbox), address(hook), routers(destination));
    }

    function _xetaEnrollRemote(uint32 destination, bytes32 remote)
        internal override
    {
        _enrollRemoteRouter(destination, remote);
        _setDestinationGas(destination, xetaDestinationGasLimit);
    }

    receive() external payable {}
}
