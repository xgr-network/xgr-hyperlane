// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {IXGRILNRegistry} from "../contracts/IXGRILNRegistry.sol";
import {MockXGRILNRegistry} from "../contracts/test/MockXGRILNRegistry.sol";
import {XETAGatewayOnlyRouterGuard} from "../contracts/XETAGatewayOnlyRouterGuard.sol";

contract GuardedRouterHarness is XETAGatewayOnlyRouterGuard {
    uint256 public sends;
    constructor(address reg, bytes32 id, uint32 domain)
        XETAGatewayOnlyRouterGuard(reg,id,domain) {}
    function transferRemote(uint32 destination, bytes32, uint256)
        external onlyXETAGateway(destination) { sends++; }
}
contract XETAGatewayOnlyRouterGuardTest is Test {
    bytes32 constant ROUTE = bytes32(uint256(7));
    uint32 constant DEST = 8453;
    address constant GATEWAY = address(0xCAFE);
    MockXGRILNRegistry registry;
    GuardedRouterHarness router;
    function setUp() public {
        registry = new MockXGRILNRegistry();
        router = new GuardedRouterHarness(address(registry),ROUTE,DEST);
        registry.setRoute(DEST, ROUTE, IXGRILNRegistry.RouteRecord({
            sourceChainId:uint64(block.chainid),sourceDomain:1643,gateway:GATEWAY,
            sourceRouter:address(router),mailbox:address(0x1234),merkleTreeHook:address(0x1235),
            destinationRouter:address(0x1236),validatorFeeWei:17,enabled:true
        }));
    }
    function testDirectRouterTransferRejected() public {
        vm.expectRevert(XETAGatewayOnlyRouterGuard.UnauthorizedXETAGateway.selector);
        router.transferRemote(DEST, bytes32(uint256(1)), 10);
    }
    function testCanonicalGatewayAccepted() public {
        vm.prank(GATEWAY);
        router.transferRemote(DEST, bytes32(uint256(1)), 10);
        assertEq(router.sends(),1);
    }
    function testWrongDestinationRejected() public {
        vm.prank(GATEWAY);
        vm.expectRevert(XETAGatewayOnlyRouterGuard.InvalidXETARoute.selector);
        router.transferRemote(137,bytes32(uint256(1)),10);
    }
    function testDisabledRouteRejectsGateway() public {
        registry.setRoute(DEST, ROUTE, IXGRILNRegistry.RouteRecord({
            sourceChainId:uint64(block.chainid),sourceDomain:1643,gateway:GATEWAY,
            sourceRouter:address(router),mailbox:address(0x1234),merkleTreeHook:address(0x1235),
            destinationRouter:address(0x1236),validatorFeeWei:17,enabled:false
        }));
        vm.prank(GATEWAY);
        vm.expectRevert(XETAGatewayOnlyRouterGuard.UnauthorizedXETAGateway.selector);
        router.transferRemote(DEST,bytes32(uint256(1)),10);
    }
}
