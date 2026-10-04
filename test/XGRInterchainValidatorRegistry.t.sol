// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XGRInterchainValidatorRegistry} from "../contracts/XGRInterchainValidatorRegistry.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract XGRInterchainValidatorRegistryTest is Test {
    MockXGRInterchainBLSVerifier internal verifier;
    XGRInterchainValidatorRegistry internal registry;

    address internal constant A = address(0xA1);
    address internal constant B = address(0xB2);
    address internal constant C = address(0xC3);
    address internal constant D = address(0xD4);

    bytes internal BLS_A;
    bytes internal BLS_B;
    bytes internal BLS_C;
    bytes internal BLS_D;
    bytes internal EIP_A;
    bytes internal EIP_B;
    bytes internal EIP_C;
    bytes internal EIP_D;
    uint64 internal deadline;

    uint256 internal constant MIN_RESERVE = 1 ether;
    uint256 internal constant MAX_REIMBURSEMENT = 0.1 ether;

    function setUp() public {
        vm.deal(address(this), 100 ether);
        verifier = new MockXGRInterchainBLSVerifier();
        BLS_A = _key(0xA1);
        BLS_B = _key(0xB2);
        BLS_C = _key(0xC3);
        BLS_D = _key(0xD4);
        EIP_A = _eipKey(0xA1);
        EIP_B = _eipKey(0xB2);
        EIP_C = _eipKey(0xC3);
        EIP_D = _eipKey(0xD4);
        deadline = uint64(block.timestamp + 5 minutes);
        vm.txGasPrice(1 gwei);

        address[] memory validators = new address[](3);
        validators[0] = A;
        validators[1] = B;
        validators[2] = C;

        bytes[] memory keys = new bytes[](3);
        keys[0] = BLS_A;
        keys[1] = BLS_B;
        keys[2] = BLS_C;

        bytes[] memory eipKeys = new bytes[](3);
        eipKeys[0] = EIP_A;
        eipKeys[1] = EIP_B;
        eipKeys[2] = EIP_C;

        bytes[] memory proofs = new bytes[](3);
        proofs[0] = hex"01";
        proofs[1] = hex"02";
        proofs[2] = hex"03";

        registry = new XGRInterchainValidatorRegistry{value: 3 * MIN_RESERVE}(
            1643,
            8453,
            address(verifier),
            MIN_RESERVE,
            MAX_REIMBURSEMENT,
            validators,
            keys,
            eipKeys,
            proofs
        );
    }

    function testCanonicalMembershipPayloadVector() public view {
        bytes memory compressed = hex"a695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c68759";
        bytes memory eip = hex"000000000000000000000000000000000695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590000000000000000000000000000000010ea7912ef7a227c01298a7c7a96b1851b23021741c71938f39638b1d368aaa621452426b5d8199773a2cb5b2743a5da";
        bytes memory expected = hex"5847525f494e544552434841494e5f5632000000000000066b000021050000000000000007000000006553f1000111111111111111111111111111111111111111110030a695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590080000000000000000000000000000000000695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590000000000000000000000000000000010ea7912ef7a227c01298a7c7a96b1851b23021741c71938f39638b1d368aaa621452426b5d8199773a2cb5b2743a5da";
        assertEq(
            registry.encodeMembershipPayload(1643, 8453, 7, 1700000000, 1, address(0x1111111111111111111111111111111111111111), compressed, eip),
            expected
        );
    }

    function testCanonicalBootstrapPayloadVector() public view {
        bytes memory compressed = hex"a695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c68759";
        bytes memory eip = hex"000000000000000000000000000000000695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590000000000000000000000000000000010ea7912ef7a227c01298a7c7a96b1851b23021741c71938f39638b1d368aaa621452426b5d8199773a2cb5b2743a5da";
        bytes memory expected = hex"5847525f494e544552434841494e5f424f4f5453545241505f5631000000000000066b0000210511111111111111111111111111111111111111110030a695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590080000000000000000000000000000000000695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590000000000000000000000000000000010ea7912ef7a227c01298a7c7a96b1851b23021741c71938f39638b1d368aaa621452426b5d8199773a2cb5b2743a5da";
        assertEq(
            registry.encodeBootstrapPayload(1643, 8453, address(0x1111111111111111111111111111111111111111), compressed, eip),
            expected
        );
    }

    function testBootstrapState() public view {
        (address[] memory validators, bytes[] memory keys, uint64 setId) = registry.getValidatorSet();
        assertEq(validators.length, 3);
        assertEq(keys.length, 3);
        assertEq(setId, 1);
        assertEq(registry.quorumThreshold(), 2);

        (bool active,, uint256 reserve) = registry.getValidator(A);
        assertTrue(active);
        assertEq(reserve, MIN_RESERVE);
    }

    function testInitialValidatorSetCommitmentMatchesPublishedSet() public view {
        (address[] memory validators, bytes[] memory keys, uint64 currentSetId) = registry.getValidatorSetEIP2537();
        bytes32 expected = registry.computeValidatorSetCommitment(validators, keys);
        assertEq(registry.validatorSetCommitment(currentSetId), expected);
    }

    function testHistoricalValidatorSetCommitmentSurvivesTransition() public {
        bytes32 set1 = registry.validatorSetCommitment(1);

        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );

        (address[] memory validators, bytes[] memory keys, uint64 currentSetId) = registry.getValidatorSetEIP2537();
        assertEq(currentSetId, 2);
        assertEq(registry.validatorSetCommitment(1), set1);
        assertEq(
            registry.validatorSetCommitment(2),
            registry.computeValidatorSetCommitment(validators, keys)
        );
        assertTrue(registry.validatorSetCommitment(2) != set1);
    }

    function testEIP2537ValidatorSetView() public view {
        (address[] memory validators, bytes[] memory keys, uint64 setId) = registry.getValidatorSetEIP2537();
        assertEq(validators.length, 3);
        assertEq(keys.length, 3);
        assertEq(validators[0], A);
        assertEq(keys[0], EIP_A);
        assertEq(validators[1], B);
        assertEq(keys[1], EIP_B);
        assertEq(validators[2], C);
        assertEq(keys[2], EIP_C);
        assertEq(setId, 1);
    }

    function testAddRequiresQuorumAndLocksReserve() public {
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );

        (bool active, bytes memory key, uint256 reserve) = registry.getValidator(D);
        assertTrue(active);
        assertEq(key, BLS_D);
        assertEq(reserve, MIN_RESERVE);
        (, uint64 setId) = registry.getValidatorStatus(D);
        assertEq(setId, 2);
    }

    function testOneOfThreeCannotAdd() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"01",
            hex"1234"
        );
    }

    function testBitmapOutsideCurrentSetCannotIncreaseQuorum() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"83",
            hex"1234"
        );
    }

    function testNonCanonicalPaddedBitmapCannotIncreaseWork() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"0003",
            hex"1234"
        );
    }

    function testVerifierFailureRejectsTransition() public {
        verifier.setResult(false);
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );
    }

    function testAddRejectsReserveBelowFloor() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                XGRInterchainValidatorRegistry.InsufficientReserve.selector,
                MIN_RESERVE,
                MIN_RESERVE - 1
            )
        );
        registry.applyMembership{value: MIN_RESERVE - 1}(
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );
    }

    function testRemoveCreditsExecutorAndValidatorWithoutExternalCalls() public {
        uint256 beforeBalance = address(registry).balance;

        registry.applyMembership(
            _transition(2, A, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );

        (bool active,, uint256 reserve) = registry.getValidator(A);
        assertFalse(active);
        assertEq(reserve, 0);
        uint256 reimbursement = registry.claimableWei(address(this));
        assertGt(reimbursement, 0);
        assertLe(reimbursement, MAX_REIMBURSEMENT);
        assertEq(registry.claimableWei(A), MIN_RESERVE - reimbursement);
        assertEq(address(registry).balance, beforeBalance);

        (, uint64 setId) = registry.getValidatorStatus(A);
        assertEq(setId, 2);
    }

    function testExecutorCanClaimReimbursementAfterRemoval() public {
        registry.applyMembership(
            _transition(2, A, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );

        uint256 reimbursement = registry.claimableWei(address(this));
        uint256 before = address(this).balance;
        registry.claim();
        assertEq(address(this).balance, before + reimbursement);
        assertEq(registry.claimableWei(address(this)), 0);
    }

    function testStaleSetIdCannotReplay() public {
        registry.applyMembership(
            _transition(2, A, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                XGRInterchainValidatorRegistry.StaleSetId.selector,
                uint64(2),
                uint64(1)
            )
        );
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );
    }

    function testConstructorRejectsReserveFloorBelowReimbursementCap() public {
        address[] memory validators = new address[](1);
        validators[0] = A;
        bytes[] memory keys = new bytes[](1);
        keys[0] = BLS_A;
        bytes[] memory eipKeys = new bytes[](1);
        eipKeys[0] = EIP_A;
        bytes[] memory proofs = new bytes[](1);
        proofs[0] = hex"01";

        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidBootstrap.selector);
        new XGRInterchainValidatorRegistry{value: MIN_RESERVE}(
            1643,
            8453,
            address(verifier),
            0.01 ether,
            0.1 ether,
            validators,
            keys,
            eipKeys,
            proofs
        );
    }

    function testAddRejectsDuplicateBLSKey() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidTransition.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );
    }

    function testExpiredProofCannotExecute() public {
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidTransition.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );
    }

    function testProofLifetimeCannotBeUnbounded() public {
        XGRInterchainValidatorRegistry.MembershipTransition memory transition =
            _transition(1, D, BLS_D, EIP_D);
        transition.validUntil = uint64(block.timestamp + 11 minutes);

        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidTransition.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            transition,
            hex"03",
            hex"1234"
        );
    }

    function testCannotRemoveFinalValidator() public {
        registry.applyMembership(
            _transition(2, A, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );

        XGRInterchainValidatorRegistry.MembershipTransition memory removeB =
            XGRInterchainValidatorRegistry.MembershipTransition({
                expectedSetId: 2,
                validUntil: deadline,
                action: 2,
                validator: B,
                blsPublicKey: BLS_B,
                blsPublicKeyEIP2537: EIP_B
            });
        registry.applyMembership(removeB, hex"03", hex"1234");

        XGRInterchainValidatorRegistry.MembershipTransition memory removeC =
            XGRInterchainValidatorRegistry.MembershipTransition({
                expectedSetId: 3,
                validUntil: deadline,
                action: 2,
                validator: C,
                blsPublicKey: BLS_C,
                blsPublicKeyEIP2537: EIP_C
            });

        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidTransition.selector);
        registry.applyMembership(removeC, hex"01", hex"1234");
    }

    function _transition(
        uint8 action,
        address validator,
        bytes memory blsKey,
        bytes memory eipKey
    ) internal view returns (XGRInterchainValidatorRegistry.MembershipTransition memory) {
        return XGRInterchainValidatorRegistry.MembershipTransition({
            expectedSetId: 1,
            validUntil: deadline,
            action: action,
            validator: validator,
            blsPublicKey: blsKey,
            blsPublicKeyEIP2537: eipKey
        });
    }

    function _key(uint8 seed) internal pure returns (bytes memory out) {
        out = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            out[i] = bytes1(seed);
        }
    }

    function _eipKey(uint8 seed) internal pure returns (bytes memory out) {
        out = new bytes(128);
        for (uint256 i = 0; i < 128; i++) {
            out[i] = bytes1(seed);
        }
    }

    receive() external payable {}
}
