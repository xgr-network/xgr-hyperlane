// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ILNRouteRegistry} from "../contracts/ILNRouteRegistry.sol";
import {ILNGateway} from "../contracts/ILNGateway.sol";
import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";
import {MockILNWarpRouter} from "../contracts/test/MockILNWarpRouter.sol";

contract ILNGatewayTest is Test {
    ILNRouteRegistry internal routeRegistry;
    ILNGateway internal gateway;
    XGRInterchainValidatorRegistryV2 internal validatorSet;
    MockILNWarpRouter internal router;

    address internal constant MAILBOX =
        0x3333333333333333333333333333333333333333;
    address internal constant HOOK =
        0x4444444444444444444444444444444444444444;
    address internal constant DEST_ROUTER =
        0x5555555555555555555555555555555555555555;
    address internal constant USER = address(0xBEEF);

    function setUp() public {
        vm.deal(address(this), 1 ether);
        vm.deal(USER, 10 ether);

        MockXGRInterchainBLSVerifier verifier =
            new MockXGRInterchainBLSVerifier();

        address[] memory validators = new address[](3);
        bytes[] memory compressed = new bytes[](3);
        bytes[] memory eip = new bytes[](3);
        bytes[] memory proofs = new bytes[](3);

        for (uint256 i = 0; i < 3; i++) {
            validators[i] = address(uint160(0xA1 + i));
            compressed[i] = _bytes(48, uint8(i + 1));
            eip[i] = _bytes(128, uint8(i + 11));
            proofs[i] = _bytes(256, uint8(i + 21));
        }

        validatorSet =
            new XGRInterchainValidatorRegistryV2{value: 3}(
                1643,
                1643,
                address(verifier),
                2,
                1,
                1,
                validators,
                compressed,
                eip,
                proofs
            );

        routeRegistry =
            new ILNRouteRegistry(8453, address(validatorSet));
        router = new MockILNWarpRouter();
        gateway = new ILNGateway(
            address(routeRegistry),
            address(router),
            MAILBOX,
            HOOK,
            address(validatorSet)
        );

        ILNRouteRegistry.Proposal memory proposal =
            ILNRouteRegistry.Proposal({
                proposalType: routeRegistry.ROUTE_ADD(),
                destinationDomain: 1643,
                setId: 1,
                nonce: 1,
                validUntil: uint64(block.timestamp + 5 minutes),
                gateway: address(gateway),
                sourceRouter: address(router),
                mailbox: MAILBOX,
                merkleTreeHook: HOOK,
                destinationRouter: DEST_ROUTER,
                validatorFeeWei: 1000
            });

        routeRegistry.execute(
            proposal,
            hex"03",
            _bytes(256, 0x66)
        );

        router.mint(USER, 10 ether);
        vm.prank(USER);
        router.approve(address(gateway), type(uint256).max);
    }

    function testBridgeEscrowsValidatorFeeAndBindsMessageId() public {
        uint256 amount = 1 ether;
        bytes32 recipient =
            bytes32(uint256(uint160(address(0xCAFE))));

        (
            uint256 validatorFee,
            uint256 routerFee,
            uint256 total
        ) = gateway.quoteILN(1643, recipient, amount);

        assertEq(validatorFee, 1000);
        assertEq(routerFee, 0.01 ether);
        assertEq(total, validatorFee + routerFee);

        vm.prank(USER);
        bytes32 messageId = gateway.bridge{value: total}(
            1643,
            recipient,
            amount
        );

        assertTrue(messageId != bytes32(0));
        assertEq(router.balanceOf(USER), 9 ether);
        assertEq(address(gateway).balance, validatorFee);

        (
            uint64 sourceChainId,
            uint32 sourceDomain,
            uint32 destinationDomain,
            uint64 sourceBlockNumber,
            address destinationRouter,
            uint256 validatorFeeWei,
            bool settled
        ) = gateway.operations(messageId);

        assertEq(sourceChainId, uint64(block.chainid));
        assertEq(sourceDomain, 8453);
        assertEq(destinationDomain, 1643);
        assertGt(sourceBlockNumber, 0);
        assertEq(destinationRouter, DEST_ROUTER);
        assertEq(validatorFeeWei, 1000);
        assertFalse(settled);
    }

    function testSettlementCreditsActualSignersOnly() public {
        uint256 amount = 1 ether;
        bytes32 recipient =
            bytes32(uint256(uint160(address(0xCAFE))));

        (
            ,
            ,
            uint256 total
        ) = gateway.quoteILN(1643, recipient, amount);

        vm.prank(USER);
        bytes32 messageId = gateway.bridge{value: total}(
            1643,
            recipient,
            amount
        );

        gateway.settle(
            messageId,
            1,
            bytes32(uint256(0x1234)),
            7,
            hex"03",
            _bytes(256, 0x77)
        );

        assertEq(gateway.claimableWei(address(0xA1)), 500);
        assertEq(gateway.claimableWei(address(0xA2)), 500);
        assertEq(gateway.claimableWei(address(0xA3)), 0);
    }

    function _bytes(uint256 length, uint8 value)
        internal
        pure
        returns (bytes memory out)
    {
        out = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            out[i] = bytes1(value);
        }
    }
}
