// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IILNRouteRegistry} from "./IILNRouteRegistry.sol";
import {IXGRInterchainValidatorSetV2} from "./IXGRInterchainValidatorSetV2.sol";
import {IXGRInterchainBLSVerifier} from "./XGRInterchainValidatorRegistry.sol";

/// @notice Canonical source-chain ILN route registry governed by the destination
///         XGR Interchain validator quorum.
/// @dev Governance payload encoding is byte-for-byte compatible with xgr-node
///      v3.1.2 XGR_ILN_GOVERNANCE_V1.
contract ILNRouteRegistry is IILNRouteRegistry {
    bytes private constant GOVERNANCE_DOMAIN_V1 = "XGR_ILN_GOVERNANCE_V1";

    uint8 public constant FEE_UPDATE = 1;
    uint8 public constant ROUTE_ADD = 2;
    uint8 public constant ROUTE_ENABLE = 3;
    uint8 public constant ROUTE_DISABLE = 4;

    struct Route {
        address gateway;
        address sourceRouter;
        address mailbox;
        address merkleTreeHook;
        address destinationRouter;
        uint256 validatorFeeWei;
        bool enabled;
    }

    struct Proposal {
        uint8 proposalType;
        uint32 destinationDomain;
        uint64 setId;
        uint64 nonce;
        uint64 validUntil;
        address gateway;
        address sourceRouter;
        address mailbox;
        address merkleTreeHook;
        address destinationRouter;
        uint256 validatorFeeWei;
    }

    uint64 public immutable sourceChainId;
    uint32 public immutable sourceDomain;
    IXGRInterchainValidatorSetV2 public immutable validatorSet;
    IXGRInterchainBLSVerifier public immutable verifier;

    uint64 public nextNonce = 1;

    mapping(uint32 => Route) private routes;
    mapping(uint32 => bool) public routeExists;

    error InvalidConfiguration();
    error InvalidProposal();
    error InvalidNonce(uint64 expected, uint64 got);
    error ExpiredProposal();
    error StaleValidatorSet();
    error InsufficientQuorum();

    event RouteAdded(uint32 indexed destinationDomain, address indexed gateway, uint256 validatorFeeWei);
    event RouteFeeUpdated(uint32 indexed destinationDomain, uint256 validatorFeeWei);
    event RouteStateChanged(uint32 indexed destinationDomain, bool enabled);
    event GovernanceExecuted(bytes32 indexed proposalId, uint8 indexed proposalType, uint64 nonce);

    constructor(uint32 sourceDomain_, address validatorSet_) {
        if (
            sourceDomain_ == 0 ||
            validatorSet_ == address(0) ||
            block.chainid == 0 ||
            block.chainid > type(uint64).max
        ) revert InvalidConfiguration();

        IXGRInterchainValidatorSetV2 set = IXGRInterchainValidatorSetV2(validatorSet_);
        address verifierAddress = set.verifier();
        if (
            set.destinationDomain() == 0 ||
            set.originChainId() == 0 ||
            verifierAddress == address(0)
        ) revert InvalidConfiguration();

        sourceChainId = uint64(block.chainid);
        sourceDomain = sourceDomain_;
        validatorSet = set;
        verifier = IXGRInterchainBLSVerifier(verifierAddress);
    }

    function getRoute(uint32 destinationDomain)
        external
        view
        returns (
            uint64 routeSourceChainId,
            uint32 routeSourceDomain,
            address gateway,
            address sourceRouter,
            address mailbox,
            address merkleTreeHook,
            address destinationRouter,
            uint256 validatorFeeWei,
            bool enabled
        )
    {
        Route storage route = routes[destinationDomain];
        return (
            sourceChainId,
            sourceDomain,
            route.gateway,
            route.sourceRouter,
            route.mailbox,
            route.merkleTreeHook,
            route.destinationRouter,
            route.validatorFeeWei,
            route.enabled
        );
    }

    function execute(
        Proposal calldata proposal,
        bytes calldata signerBitmap,
        bytes calldata aggregateSignature
    ) external {
        if (proposal.destinationDomain == 0 || proposal.setId == 0) {
            revert InvalidProposal();
        }
        if (proposal.nonce != nextNonce) {
            revert InvalidNonce(nextNonce, proposal.nonce);
        }
        if (proposal.validUntil == 0 || block.timestamp > proposal.validUntil) {
            revert ExpiredProposal();
        }

        _validateProposalShape(proposal);

        bytes memory payload = encodeGovernancePayload(proposal);
        _verifyQuorum(proposal.setId, payload, signerBitmap, aggregateSignature);

        bytes32 proposalId = keccak256(payload);
        nextNonce = proposal.nonce + 1;

        if (proposal.proposalType == ROUTE_ADD) {
            routes[proposal.destinationDomain] = Route({
                gateway: proposal.gateway,
                sourceRouter: proposal.sourceRouter,
                mailbox: proposal.mailbox,
                merkleTreeHook: proposal.merkleTreeHook,
                destinationRouter: proposal.destinationRouter,
                validatorFeeWei: proposal.validatorFeeWei,
                enabled: true
            });
            routeExists[proposal.destinationDomain] = true;
            emit RouteAdded(
                proposal.destinationDomain,
                proposal.gateway,
                proposal.validatorFeeWei
            );
        } else if (proposal.proposalType == FEE_UPDATE) {
            routes[proposal.destinationDomain].validatorFeeWei =
                proposal.validatorFeeWei;
            emit RouteFeeUpdated(
                proposal.destinationDomain,
                proposal.validatorFeeWei
            );
        } else {
            bool enabled = proposal.proposalType == ROUTE_ENABLE;
            routes[proposal.destinationDomain].enabled = enabled;
            emit RouteStateChanged(proposal.destinationDomain, enabled);
        }

        emit GovernanceExecuted(
            proposalId,
            proposal.proposalType,
            proposal.nonce
        );
    }

    function encodeGovernancePayload(Proposal calldata proposal)
        public
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            GOVERNANCE_DOMAIN_V1,
            bytes8(sourceChainId),
            bytes4(sourceDomain),
            bytes4(proposal.destinationDomain),
            bytes20(address(this)),
            bytes8(proposal.setId),
            bytes8(proposal.nonce),
            bytes8(proposal.validUntil),
            bytes1(proposal.proposalType),
            bytes20(proposal.gateway),
            bytes20(proposal.sourceRouter),
            bytes20(proposal.mailbox),
            bytes20(proposal.merkleTreeHook),
            bytes20(proposal.destinationRouter),
            bytes32(proposal.validatorFeeWei)
        );
    }

    function _validateProposalShape(Proposal calldata proposal) private view {
        bool contractsEmpty =
            proposal.gateway == address(0) &&
            proposal.sourceRouter == address(0) &&
            proposal.mailbox == address(0) &&
            proposal.merkleTreeHook == address(0) &&
            proposal.destinationRouter == address(0);

        if (proposal.proposalType == ROUTE_ADD) {
            if (
                routeExists[proposal.destinationDomain] ||
                proposal.gateway == address(0) ||
                proposal.sourceRouter == address(0) ||
                proposal.mailbox == address(0) ||
                proposal.merkleTreeHook == address(0) ||
                proposal.destinationRouter == address(0) ||
                proposal.validatorFeeWei == 0
            ) revert InvalidProposal();
            return;
        }

        if (!routeExists[proposal.destinationDomain]) {
            revert InvalidProposal();
        }

        if (proposal.proposalType == FEE_UPDATE) {
            if (!contractsEmpty || proposal.validatorFeeWei == 0) {
                revert InvalidProposal();
            }
            return;
        }

        if (
            proposal.proposalType == ROUTE_ENABLE ||
            proposal.proposalType == ROUTE_DISABLE
        ) {
            if (!contractsEmpty || proposal.validatorFeeWei != 0) {
                revert InvalidProposal();
            }
            return;
        }

        revert InvalidProposal();
    }

    function _verifyQuorum(
        uint64 setId,
        bytes memory payload,
        bytes calldata signerBitmap,
        bytes calldata aggregateSignature
    ) private view {
        (, uint64 currentSetId) =
            validatorSet.getValidatorStatus(address(0));
        if (currentSetId != setId) revert StaleValidatorSet();

        (
            address[] memory validators,
            bytes[] memory publicKeys,
            uint64 resolvedSetId
        ) = validatorSet.getValidatorSetForVerification(setId);

        if (
            resolvedSetId != setId ||
            validators.length == 0 ||
            validators.length != publicKeys.length
        ) revert StaleValidatorSet();

        uint256 threshold = (2 * validators.length + 2) / 3;
        if (!_bitmapHasQuorum(signerBitmap, validators.length, threshold)) {
            revert InsufficientQuorum();
        }
        if (
            !verifier.verify(
                payload,
                publicKeys,
                signerBitmap,
                aggregateSignature
            )
        ) revert InsufficientQuorum();
    }

    function _bitmapHasQuorum(
        bytes calldata bitmap,
        uint256 validatorCount,
        uint256 threshold
    ) private pure returns (bool) {
        if (validatorCount == 0 || threshold == 0 || bitmap.length == 0) {
            return false;
        }
        uint256 maxBitmapLength = (validatorCount + 7) / 8;
        if (bitmap.length > maxBitmapLength || bitmap[0] == bytes1(0)) {
            return false;
        }

        uint256 count;
        for (uint256 i = 0; i < validatorCount; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (
                    uint8(bitmap[bitmap.length - 1 - byteFromEnd]) &
                    uint8(1 << bitIndex)
                ) != 0
            ) {
                count++;
            }
        }

        for (uint256 i = validatorCount; i < bitmap.length * 8; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (
                    uint8(bitmap[bitmap.length - 1 - byteFromEnd]) &
                    uint8(1 << bitIndex)
                ) != 0
            ) return false;
        }

        return count >= threshold;
    }
}
