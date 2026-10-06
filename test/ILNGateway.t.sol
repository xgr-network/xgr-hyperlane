// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ILNGateway} from "../contracts/ILNGateway.sol";
import {MockILNWarpRouter} from "../contracts/test/MockILNWarpRouter.sol";

contract ILNGatewayTest is Test {
    ILNGateway internal gateway;
    MockILNWarpRouter internal router;

    uint32 internal constant SOURCE_DOMAIN = 8453;
    uint32 internal constant DESTINATION_DOMAIN = 1643;
    address internal constant MAILBOX =
        0x3333333333333333333333333333333333333333;
    address internal constant HOOK =
        0x4444444444444444444444444444444444444444;
    address internal constant DEST_ROUTER =
        0x5555555555555555555555555555555555555555;
    address internal constant USER = address(0xBEEF);

    function setUp() public {
        vm.deal(USER, 10 ether);

        router = new MockILNWarpRouter();
        gateway = new ILNGateway(
            SOURCE_DOMAIN,
            DESTINATION_DOMAIN,
            address(router),
            MAILBOX,
            HOOK,
            DEST_ROUTER,
            1,
            false
        );

        router.mint(USER, 10 ether);
        vm.prank(USER);
        router.approve(address(gateway), type(uint256).max);
    }

    function testGatewayIsItsOwnCanonicalRegistry() public view {
        assertEq(gateway.ilnRegistry(), address(gateway));

        (
            uint64 sourceChainId,
            uint32 sourceDomain,
            address routeGateway,
            address sourceRouter,
            address mailbox,
            address hook,
            address destinationRouter,
            uint256 fee,
            bool enabled
        ) = gateway.getRoute(DESTINATION_DOMAIN);

        assertEq(sourceChainId, uint64(block.chainid));
        assertEq(sourceDomain, SOURCE_DOMAIN);
        assertEq(routeGateway, address(gateway));
        assertEq(sourceRouter, address(router));
        assertEq(mailbox, MAILBOX);
        assertEq(hook, HOOK);
        assertEq(destinationRouter, DEST_ROUTER);
        assertEq(fee, 1);
        assertTrue(enabled);
    }

    function testSyntheticBridgeEscrowsNominalFeeWithNoTokenQuote()
        public
    {
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
        assertEq(routerNativeValue, 0.01 ether);
        assertEq(totalNative, 0.01 ether + 1);
        assertEq(totalToken, amount);

        vm.prank(USER);
        bytes32 messageId =
            gateway.bridge{value: totalNative}(
                DESTINATION_DOMAIN,
                recipient,
                amount
            );

        assertTrue(messageId != bytes32(0));
        assertEq(router.balanceOf(USER), 9 ether);
        assertEq(address(gateway).balance, validatorFee);
        assertEq(
            gateway.totalValidatorFeesEscrowedWei(),
            validatorFee
        );
    }

    function testSyntheticPrincipalEchoQuoteAccepted() public {
        uint256 amount = 1 ether;
        router.setSyntheticQuoteAmount(amount);

        bytes32 recipient =
            bytes32(uint256(uint160(address(0xCAFE))));

        (, , uint256 totalNative, uint256 totalToken) =
            gateway.quoteILN(
                DESTINATION_DOMAIN,
                recipient,
                amount
            );

        assertEq(totalToken, amount);

        vm.prank(USER);
        gateway.bridge{value: totalNative}(
            DESTINATION_DOMAIN,
            recipient,
            amount
        );

        assertEq(router.balanceOf(USER), 9 ether);
    }

    function testSyntheticExtraTokenFeeRejected() public {
        uint256 amount = 1 ether;
        router.setSyntheticQuoteAmount(amount + 1);

        bytes32 recipient =
            bytes32(uint256(uint160(address(0xCAFE))));

        vm.expectRevert(ILNGateway.UnsupportedWarpFee.selector);
        gateway.quoteILN(
            DESTINATION_DOMAIN,
            recipient,
            amount
        );
    }

    function testWrongDestinationRejected() public {
        vm.expectRevert(ILNGateway.InvalidRoute.selector);
        gateway.getRoute(1);
    }
}
