// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HypERC20} from "@hyperlane-xyz/core/contracts/token/HypERC20.sol";
import {XETAGatewayOnlyRouterGuard} from "./XETAGatewayOnlyRouterGuard.sol";

/// @notice New Hyperlane synthetic ERC-20 Warp router (wXGR and future XETA assets).
/// @dev Uses the upstream HypERC20 mint/burn and Mailbox handling unchanged.
///      Synthetic initial supply is ALWAYS zero; minted only on valid inbound
///      Mailbox deliveries. Initialized atomically during constructor execution.
contract XETAGuardedSyntheticWarpRouter is HypERC20, XETAGatewayOnlyRouterGuard {
    uint256 public immutable xetaDestinationGasLimit;

    constructor(
        address registry_,
        bytes32 routeId_,
        uint32 destinationDomain_,
        address mailbox_,
        address merkleTreeHook_,
        address destinationIsm_,
        uint256 destinationGasLimit_,
        uint8 decimals_,
        string memory name_,
        string memory symbol_
    )
        HypERC20(decimals_, 1, 1, mailbox_)
        XETAGatewayOnlyRouterGuard(registry_, routeId_, destinationDomain_)
    {
        if (
            destinationGasLimit_ == 0 ||
            merkleTreeHook_ == address(0) ||
            destinationIsm_ == address(0) ||
            bytes(name_).length == 0 ||
            bytes(symbol_).length == 0
        ) revert XETAInvalidConfiguration();

        xetaDestinationGasLimit = destinationGasLimit_;
        // HypERC20.initialize is public, but its initializer is permanently
        // consumed before deployment completes. Owner is renounced.
        initialize(
            0,
            name_,
            symbol_,
            merkleTreeHook_,
            destinationIsm_,
            address(0)
        );
    }

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
}
