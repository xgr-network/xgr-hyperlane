// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ILNGateway} from "../contracts/ILNGateway.sol";
import {MockILNNativeWarpRouter} from "../contracts/test/MockILNNativeWarpRouter.sol";

contract ILNGatewayNativeTest is Test {
    uint32 internal constant SOURCE_DOMAIN = 1643;
    uint32 internal constant DESTINATION_DOMAIN = 8453;
    address internal constant MAILBOX =
        0x3333333333333333333333333333333333333333;
    address internal constant HOOK =
        0x4444444444444444444444444444444444444444;
    address internal constant DEST_ROUTER =
        0x5555555555555555555555555555555555555555;
    address internal constant USER = address(0xBEEF);

    function testNativeGatewayForwardsPrincipalAndKeepsNominalFee()
        public
    {
        vm.deal(USER, 10 ether);

        MockILNNativeWarpRouter router =
            new MockILNNativeWarpRouter();

        ILNGateway gateway = new ILNGateway(
            SOURCE_DOMAIN,
            DESTINATION_DOMAIN,
            address(router),
            MAILBOX,
            HOOK,
            DEST_ROUTER,
            1,
            false
        );

        uint256 amount = 1 ether;
        bytes32 recipient =
            bytes32(uint256(uint160(address(0xCAFE))));

        (
            uint256 validatorFee,
            uint256 routerNativeValue,
            uint256 totalNative,
            uint256 totalToken
        ) = gateway.quoteILN(
            DESTINATION_DOMAIN,
            recipient,
            amount
        );

        assertEq(validatorFee, 1);
        assertEq(
            routerNativeValue,
            amount + 0.01 ether
        );
        assertEq(
            totalNative,
            amount + 0.01 ether + 1
        );
        assertEq(totalToken, 0);

        vm.prank(USER);
        bytes32 messageId =
            gateway.bridge{value: totalNative}(
                DESTINATION_DOMAIN,
                recipient,
                amount
            );

        assertTrue(messageId != bytes32(0));
        assertEq(router.lockedWei(), amount);
        assertEq(address(gateway).balance, validatorFee);
    }
}
