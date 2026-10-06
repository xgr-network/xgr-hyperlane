// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Read-only canonical ILN route registry interface consumed by validators and gateways.
/// @dev The tuple shape is intentionally identical to xgr-node v3.1.2's getRoute ABI.
interface IILNRouteRegistry {
    function getRoute(uint32 destinationDomain)
        external
        view
        returns (
            uint64 sourceChainId,
            uint32 sourceDomain,
            address gateway,
            address sourceRouter,
            address mailbox,
            address merkleTreeHook,
            address destinationRouter,
            uint256 validatorFeeWei,
            bool enabled
        );
}
