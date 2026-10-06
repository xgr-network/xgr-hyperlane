// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IILNRouteRegistry} from "./IILNRouteRegistry.sol";
import {IXGRInterchainValidatorSetV2} from "./IXGRInterchainValidatorSetV2.sol";
import {IXGRInterchainBLSVerifier} from "./XGRInterchainValidatorRegistry.sol";

struct ILNQuote {
    address token;
    uint256 amount;
}

interface IILNWarpRouter {
    function token() external view returns (address);

    function quoteTransferRemote(
        uint32 destination,
        bytes32 recipient,
        uint256 amount
    ) external view returns (ILNQuote[] memory quotes);

    function transferRemote(
        uint32 destination,
        bytes32 recipient,
        uint256 amount
    ) external payable returns (bytes32 messageId);
}

interface IILNERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

/// @notice Base-side fee-qualified entry point for synthetic wXGR -> XGR ILN transfers.
/// @dev The deployed Warp router remains the Hyperlane sender. The Gateway pulls wXGR
///      from the user, calls the canonical router, receives the real messageId and emits
///      the exact ILNOperation event consumed by xgr-node v3.1.2.
contract ILNGateway {
    bytes private constant CHECKPOINT_DOMAIN_V1 = "XGR_ILN_CHECKPOINT_V1";

    IILNRouteRegistry public immutable ilnRegistry;
    address public immutable warpRouter;
    address public immutable mailbox;
    address public immutable merkleTreeHook;
    IXGRInterchainValidatorSetV2 public immutable validatorSetMirror;
    IXGRInterchainBLSVerifier public immutable verifier;
    uint256 public immutable activationBlock;

    struct Operation {
        uint64 sourceChainId;
        uint32 sourceDomain;
        uint32 destinationDomain;
        uint64 sourceBlockNumber;
        address destinationRouter;
        uint256 validatorFeeWei;
        bool settled;
    }

    mapping(bytes32 => Operation) public operations;
    mapping(address => uint256) public claimableWei;

    uint256 private unlocked = 1;

    error InvalidConfiguration();
    error InvalidRoute();
    error InvalidAmount();
    error InvalidValue(uint256 expected, uint256 got);
    error UnsupportedWarpFee();
    error TokenTransferFailed();
    error InvalidMessageId();
    error OperationAlreadyExists();
    error UnknownOperation();
    error AlreadySettled();
    error InvalidAttestation();
    error InsufficientQuorum();
    error NothingToClaim();
    error TransferFailed();
    error ReentrantCall();

    event ILNOperation(
        bytes32 indexed messageId,
        uint32 indexed destinationDomain,
        uint256 validatorFeeWei
    );
    event ILNFeeSettled(
        bytes32 indexed messageId,
        uint64 indexed setId,
        uint256 signerCount,
        uint256 validatorFeeWei
    );
    event ILNFeeClaimed(address indexed validator, uint256 amountWei);

    modifier nonReentrant() {
        if (unlocked != 1) revert ReentrantCall();
        unlocked = 2;
        _;
        unlocked = 1;
    }

    constructor(
        address registry_,
        address warpRouter_,
        address mailbox_,
        address merkleTreeHook_,
        address validatorSetMirror_
    ) {
        if (
            registry_ == address(0) ||
            warpRouter_ == address(0) ||
            mailbox_ == address(0) ||
            merkleTreeHook_ == address(0) ||
            validatorSetMirror_ == address(0)
        ) revert InvalidConfiguration();

        if (IILNWarpRouter(warpRouter_).token() != warpRouter_) {
            revert InvalidConfiguration();
        }

        IXGRInterchainValidatorSetV2 set =
            IXGRInterchainValidatorSetV2(validatorSetMirror_);
        address verifierAddress = set.verifier();
        if (verifierAddress == address(0)) revert InvalidConfiguration();

        ilnRegistry = IILNRouteRegistry(registry_);
        warpRouter = warpRouter_;
        mailbox = mailbox_;
        merkleTreeHook = merkleTreeHook_;
        validatorSetMirror = set;
        verifier = IXGRInterchainBLSVerifier(verifierAddress);
        activationBlock = block.number;
    }

    function quoteILN(
        uint32 destinationDomain,
        bytes32 recipient,
        uint256 amount
    )
        external
        view
        returns (
            uint256 validatorFeeWei,
            uint256 routerNativeFeeWei,
            uint256 totalNativeValueWei
        )
    {
        if (amount == 0 || recipient == bytes32(0)) revert InvalidAmount();

        (
            ,
            ,
            address routeGateway,
            address routeSourceRouter,
            address routeMailbox,
            address routeHook,
            address destinationRouter,
            uint256 routeValidatorFee,
            bool enabled
        ) = ilnRegistry.getRoute(destinationDomain);

        _validateRoute(
            routeGateway,
            routeSourceRouter,
            routeMailbox,
            routeHook,
            destinationRouter,
            routeValidatorFee,
            enabled
        );

        routerNativeFeeWei = _quoteRouterNative(
            destinationDomain,
            recipient,
            amount
        );
        validatorFeeWei = routeValidatorFee;
        totalNativeValueWei = routeValidatorFee + routerNativeFeeWei;
    }

    function bridge(
        uint32 destinationDomain,
        bytes32 recipient,
        uint256 amount
    ) external payable nonReentrant returns (bytes32 messageId) {
        if (amount == 0 || recipient == bytes32(0)) revert InvalidAmount();

        (
            uint64 sourceChainId,
            uint32 sourceDomain,
            address routeGateway,
            address routeSourceRouter,
            address routeMailbox,
            address routeHook,
            address destinationRouter,
            uint256 validatorFeeWei,
            bool enabled
        ) = ilnRegistry.getRoute(destinationDomain);

        _validateRoute(
            routeGateway,
            routeSourceRouter,
            routeMailbox,
            routeHook,
            destinationRouter,
            validatorFeeWei,
            enabled
        );
        if (
            sourceChainId != uint64(block.chainid) ||
            sourceDomain == 0
        ) revert InvalidRoute();

        uint256 routerNativeFeeWei =
            _quoteRouterNative(destinationDomain, recipient, amount);
        uint256 expectedValue = validatorFeeWei + routerNativeFeeWei;
        if (msg.value != expectedValue) {
            revert InvalidValue(expectedValue, msg.value);
        }

        if (
            !IILNERC20(warpRouter).transferFrom(
                msg.sender,
                address(this),
                amount
            )
        ) revert TokenTransferFailed();

        messageId = IILNWarpRouter(warpRouter).transferRemote{
            value: routerNativeFeeWei
        }(destinationDomain, recipient, amount);

        if (messageId == bytes32(0)) revert InvalidMessageId();
        if (operations[messageId].sourceBlockNumber != 0) {
            revert OperationAlreadyExists();
        }
        if (block.number > type(uint64).max) revert InvalidConfiguration();

        operations[messageId] = Operation({
            sourceChainId: sourceChainId,
            sourceDomain: sourceDomain,
            destinationDomain: destinationDomain,
            sourceBlockNumber: uint64(block.number),
            destinationRouter: destinationRouter,
            validatorFeeWei: validatorFeeWei,
            settled: false
        });

        emit ILNOperation(
            messageId,
            destinationDomain,
            validatorFeeWei
        );
    }

    function settle(
        bytes32 messageId,
        uint64 setId,
        bytes32 root,
        uint32 checkpointIndex,
        bytes calldata signerBitmap,
        bytes calldata aggregateSignature
    ) external nonReentrant {
        Operation storage operation = operations[messageId];
        if (operation.sourceBlockNumber == 0) revert UnknownOperation();
        if (operation.settled) revert AlreadySettled();
        if (setId == 0 || root == bytes32(0)) revert InvalidAttestation();

        (
            address[] memory validators,
            bytes[] memory publicKeys,
            uint64 resolvedSetId
        ) = validatorSetMirror.getValidatorSetForVerification(setId);

        if (
            resolvedSetId != setId ||
            validators.length == 0 ||
            validators.length != publicKeys.length
        ) revert InvalidAttestation();

        uint256 threshold = (2 * validators.length + 2) / 3;
        uint256 signerCount =
            _bitmapSignerCount(signerBitmap, validators.length);
        if (signerCount < threshold) revert InsufficientQuorum();

        bytes memory payload = _encodeCheckpointPayload(
            operation,
            messageId,
            setId,
            root,
            checkpointIndex
        );

        if (
            !verifier.verify(
                payload,
                publicKeys,
                signerBitmap,
                aggregateSignature
            )
        ) revert InsufficientQuorum();

        operation.settled = true;

        uint256 share = operation.validatorFeeWei / signerCount;
        uint256 remainder = operation.validatorFeeWei % signerCount;
        bool remainderAssigned;

        for (uint256 i = 0; i < validators.length; i++) {
            if (!_bitmapContains(signerBitmap, i)) continue;
            uint256 amount = share;
            if (!remainderAssigned) {
                amount += remainder;
                remainderAssigned = true;
            }
            if (amount != 0) {
                claimableWei[validators[i]] += amount;
            }
        }

        emit ILNFeeSettled(
            messageId,
            setId,
            signerCount,
            operation.validatorFeeWei
        );
    }

    function claim() external nonReentrant {
        uint256 amount = claimableWei[msg.sender];
        if (amount == 0) revert NothingToClaim();

        claimableWei[msg.sender] = 0;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) {
            claimableWei[msg.sender] = amount;
            revert TransferFailed();
        }

        emit ILNFeeClaimed(msg.sender, amount);
    }

    function encodeCheckpointPayload(
        bytes32 messageId,
        uint64 setId,
        bytes32 root,
        uint32 checkpointIndex
    ) external view returns (bytes memory) {
        Operation storage operation = operations[messageId];
        if (operation.sourceBlockNumber == 0) revert UnknownOperation();
        return _encodeCheckpointPayload(
            operation,
            messageId,
            setId,
            root,
            checkpointIndex
        );
    }

    function _encodeCheckpointPayload(
        Operation storage operation,
        bytes32 messageId,
        uint64 setId,
        bytes32 root,
        uint32 checkpointIndex
    ) private view returns (bytes memory) {
        return abi.encodePacked(
            CHECKPOINT_DOMAIN_V1,
            bytes8(operation.sourceChainId),
            bytes4(operation.sourceDomain),
            bytes4(operation.destinationDomain),
            bytes8(setId),
            bytes8(operation.sourceBlockNumber),
            bytes20(address(ilnRegistry)),
            bytes20(address(this)),
            bytes20(warpRouter),
            bytes20(mailbox),
            bytes20(merkleTreeHook),
            bytes20(operation.destinationRouter),
            bytes32(operation.validatorFeeWei),
            messageId,
            root,
            bytes4(checkpointIndex)
        );
    }

    function _validateRoute(
        address routeGateway,
        address routeSourceRouter,
        address routeMailbox,
        address routeHook,
        address destinationRouter,
        uint256 validatorFeeWei,
        bool enabled
    ) private view {
        if (
            !enabled ||
            routeGateway != address(this) ||
            routeSourceRouter != warpRouter ||
            routeMailbox != mailbox ||
            routeHook != merkleTreeHook ||
            destinationRouter == address(0) ||
            validatorFeeWei == 0
        ) revert InvalidRoute();
    }

    function _quoteRouterNative(
        uint32 destinationDomain,
        bytes32 recipient,
        uint256 amount
    ) private view returns (uint256 nativeFeeWei) {
        ILNQuote[] memory quotes =
            IILNWarpRouter(warpRouter).quoteTransferRemote(
                destinationDomain,
                recipient,
                amount
            );

        uint256 tokenQuoted;
        for (uint256 i = 0; i < quotes.length; i++) {
            if (quotes[i].token == address(0)) {
                nativeFeeWei += quotes[i].amount;
            } else if (quotes[i].token == warpRouter) {
                tokenQuoted += quotes[i].amount;
            } else {
                revert UnsupportedWarpFee();
            }
        }

        // Hyperlane versions in the supported deployment family either omit the
        // synthetic principal from token-denominated quotes or include the exact
        // principal amount. Any extra token-denominated fee is intentionally
        // rejected for the Base MVP rather than guessed.
        if (tokenQuoted != 0 && tokenQuoted != amount) {
            revert UnsupportedWarpFee();
        }
    }

    function _bitmapSignerCount(
        bytes calldata bitmap,
        uint256 validatorCount
    ) private pure returns (uint256 count) {
        if (validatorCount == 0 || bitmap.length == 0) {
            revert InvalidAttestation();
        }
        uint256 maxBitmapLength = (validatorCount + 7) / 8;
        if (bitmap.length > maxBitmapLength || bitmap[0] == bytes1(0)) {
            revert InvalidAttestation();
        }

        for (uint256 i = 0; i < validatorCount; i++) {
            if (_bitmapContains(bitmap, i)) count++;
        }

        for (uint256 i = validatorCount; i < bitmap.length * 8; i++) {
            if (_bitmapContains(bitmap, i)) revert InvalidAttestation();
        }
    }

    function _bitmapContains(
        bytes calldata bitmap,
        uint256 index
    ) private pure returns (bool) {
        uint256 byteFromEnd = index >> 3;
        if (byteFromEnd >= bitmap.length) return false;
        uint256 bitIndex = index & 7;
        return (
            uint8(bitmap[bitmap.length - 1 - byteFromEnd]) &
            uint8(1 << bitIndex)
        ) != 0;
    }
}
