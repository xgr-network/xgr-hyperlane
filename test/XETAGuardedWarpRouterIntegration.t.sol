// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IXGRILNRegistry} from "../contracts/IXGRILNRegistry.sol";
import {MockXGRILNRegistry} from "../contracts/test/MockXGRILNRegistry.sol";
import {XETAGuardedNativeWarpRouter} from "../contracts/XETAGuardedNativeWarpRouter.sol";
import {XETAGuardedSyntheticWarpRouter} from "../contracts/XETAGuardedSyntheticWarpRouter.sol";
import {XETAGatewayOnlyRouterGuard} from "../contracts/XETAGatewayOnlyRouterGuard.sol";

contract XETAMockMailbox {
    uint32 public localDomain;
    uint256 public dispatchCount;
    constructor(uint32 domain) { localDomain = domain; }
    function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata, address)
        external pure returns (uint256) { return 0; }
    function dispatch(uint32, bytes32, bytes calldata, bytes calldata, address)
        external payable returns (bytes32) { dispatchCount++; return keccak256(abi.encodePacked(dispatchCount)); }
}

contract XETARouterIntegrationTest is Test {
    uint32 constant DEST = 8453;
    bytes32 constant ROUTE = bytes32(uint256(11));
    address constant GATEWAY = address(0xBEEF);
    address constant RECIPIENT = address(0xCAFE);
    MockXGRILNRegistry reg;
    XETAMockMailbox box;
    XETAGuardedNativeWarpRouter nativeRouter;
    XETAGuardedSyntheticWarpRouter synthRouter;

    function setUp() public {
        reg = new MockXGRILNRegistry();
        box = new XETAMockMailbox(1643);
        // Local mock chain ID is 31337 in Forge; route source is block.chainid.
        nativeRouter = new XETAGuardedNativeWarpRouter(
            address(reg), ROUTE, DEST, address(box),
            address(box), address(box), 100000
        );
        _route(address(nativeRouter));
    }

    function _route(address router) internal {
        reg.setRoute(DEST, ROUTE, IXGRILNRegistry.RouteRecord({
            sourceChainId:uint64(block.chainid),sourceDomain:1643,
            gateway:GATEWAY,sourceRouter:router,mailbox:address(box),
            merkleTreeHook:address(box),destinationRouter:address(0x1236),
            validatorFeeWei:7,enabled:true
        }));
    }

    function testNativeGatewayOnlyAndInbound() public {
        nativeRouter.bootstrapXETARemoteRouter();
        vm.deal(address(this),1 ether);
        vm.expectRevert(XETAGatewayOnlyRouterGuard.XETAUnauthorizedGateway.selector);
        nativeRouter.transferRemote{value:0.1 ether}(DEST,bytes32(uint256(uint160(RECIPIENT))),0.1 ether);
        vm.deal(GATEWAY,1 ether);
        vm.prank(GATEWAY);
        nativeRouter.transferRemote{value:0.1 ether}(DEST,bytes32(uint256(uint160(RECIPIENT))),0.1 ether);
        assertEq(box.dispatchCount(),1);
        assertEq(address(nativeRouter).balance,0.1 ether);

        vm.prank(address(box));
        nativeRouter.handle(DEST,bytes32(uint256(uint160(address(0x1236)))),
            abi.encodePacked(bytes32(uint256(uint160(RECIPIENT))),uint256(0.04 ether)));
        assertEq(RECIPIENT.balance,0.04 ether);
        assertEq(address(nativeRouter).balance,0.06 ether);
    }

    function testSyntheticGatewayOnlyAndInbound() public {
        synthRouter = new XETAGuardedSyntheticWarpRouter(
            address(reg),ROUTE,DEST,address(box),address(box),address(box),
            100000,18,"XETA Wrapped XGR","wXGR"
        );
        _route(address(synthRouter));
        synthRouter.bootstrapXETARemoteRouter();
        assertEq(synthRouter.totalSupply(),0);
        vm.prank(address(box));
        synthRouter.handle(DEST,bytes32(uint256(uint160(address(0x1236)))),
            abi.encodePacked(bytes32(uint256(uint160(GATEWAY))),uint256(1 ether)));
        assertEq(synthRouter.balanceOf(GATEWAY),1 ether);
        vm.expectRevert(XETAGatewayOnlyRouterGuard.XETAUnauthorizedGateway.selector);
        synthRouter.transferRemote(DEST,bytes32(uint256(uint160(RECIPIENT))),0.25 ether);
        vm.prank(GATEWAY);
        synthRouter.transferRemote(DEST,bytes32(uint256(uint160(RECIPIENT))),0.25 ether);
        assertEq(synthRouter.balanceOf(GATEWAY),0.75 ether);
        assertEq(synthRouter.totalSupply(),0.75 ether);
        assertEq(box.dispatchCount(),1);
    }

    receive() external payable {}
}
