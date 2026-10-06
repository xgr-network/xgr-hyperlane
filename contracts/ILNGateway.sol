// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

/// @notice Minimal immutable ILN v3.1.2 source gateway.
/// @dev For the Base MVP the gateway is also the canonical route registry:
///      ilnRegistry() returns address(this) and getRoute() exposes one immutable
///      route. There is no owner, route admin, validator-set mirror or mutable
///      fee state.
contract ILNGateway {
    uint64 public immutable sourceChainId;
    uint32 public immutable sourceDomain;
    uint32 public immutable destinationDomain;

    address public immutable warpRouter;
    address public immutable warpToken;
    address public immutable mailbox;
    address public immutable merkleTreeHook;
    address public immutable destinationRouter;

    uint256 public immutable validatorFeeWei;
    bool public immutable nativeQuoteIncludesPrincipal;
    uint256 public immutable activationBlock;

    uint256 public totalValidatorFeesEscrowedWei;

    uint256 private unlocked = 1;

    error InvalidConfiguration();
    error InvalidRoute();
    error InvalidAmount();
    error InvalidValue(uint256 expected, uint256 got);
    error UnsupportedWarpFee();
    error TokenTransferFailed();
    error InvalidMessageId();
    error ReentrantCall();

    event ILNOperation(
        bytes32 indexed messageId,
        uint32 indexed destinationDomain,
        uint256 validatorFeeWei
    );

    modifier nonReentrant() {
        if (unlocked != 1) revert ReentrantCall();
        unlocked = 2;
        _;
        unlocked = 1;
    }

    constructor(
        uint32 sourceDomain_,
        uint32 destinationDomain_,
        address warpRouter_,
        address mailbox_,
        address merkleTreeHook_,
        address destinationRouter_,
        uint256 validatorFeeWei_,
        bool nativeQuoteIncludesPrincipal_
    ) {
        if (
            block.chainid == 0 ||
            block.chainid > type(uint64).max ||
            sourceDomain_ == 0 ||
            destinationDomain_ == 0 ||
            sourceDomain_ == destinationDomain_ ||
            warpRouter_ == address(0) ||
            mailbox_ == address(0) ||
            merkleTreeHook_ == address(0) ||
            destinationRouter_ == address(0) ||
            validatorFeeWei_ == 0
        ) revert InvalidConfiguration();

        address token = IILNWarpRouter(warpRouter_).token();
        if (token != address(0) && token != warpRouter_) {
            revert InvalidConfiguration();
        }
        if (token != address(0) && nativeQuoteIncludesPrincipal_) {
            revert InvalidConfiguration();
        }

        sourceChainId = uint64(block.chainid);
        sourceDomain = sourceDomain_;
        destinationDomain = destinationDomain_;
        warpRouter = warpRouter_;
        warpToken = token;
        mailbox = mailbox_;
        merkleTreeHook = merkleTreeHook_;
        destinationRouter = destinationRouter_;
        validatorFeeWei = validatorFeeWei_;
        nativeQuoteIncludesPrincipal = nativeQuoteIncludesPrincipal_;
        activationBlock = block.number;
    }

    /// @notice xgr-node gateway-binding getter.
    /// @dev The immutable MVP gateway is its own canonical registry.
    function ilnRegistry() external view returns (address) {
        return address(this);
    }

    /// @notice Canonical xgr-node v3.1.2 route ABI.
    function getRoute(uint32 requestedDestinationDomain)
        external
        view
        returns (
            uint64 routeSourceChainId,
            uint32 routeSourceDomain,
            address gateway,
            address sourceRouter,
            address routeMailbox,
            address routeMerkleTreeHook,
            address routeDestinationRouter,
            uint256 routeValidatorFeeWei,
            bool enabled
        )
    {
        if (requestedDestinationDomain != destinationDomain) {
            revert InvalidRoute();
        }

        return (
            sourceChainId,
            sourceDomain,
            address(this),
            warpRouter,
            mailbox,
            merkleTreeHook,
            destinationRouter,
            validatorFeeWei,
            true
        );
    }

    function quoteILN(
        uint32 requestedDestinationDomain,
        bytes32 recipient,
        uint256 amount
    )
        external
        view
        returns (
            uint256 routeValidatorFeeWei,
            uint256 routerNativeValueWei,
            uint256 totalNativeValueWei,
            uint256 totalTokenAmount
        )
    {
        if (requestedDestinationDomain != destinationDomain) {
            revert InvalidRoute();
        }
        if (amount == 0 || recipient == bytes32(0)) {
            revert InvalidAmount();
        }

        routerNativeValueWei = _quoteRouterNative(recipient, amount);
        routeValidatorFeeWei = validatorFeeWei;
        totalNativeValueWei = validatorFeeWei + routerNativeValueWei;
        totalTokenAmount = warpToken == address(0) ? 0 : amount;
    }

    function bridge(
        uint32 requestedDestinationDomain,
        bytes32 recipient,
        uint256 amount
    ) external payable nonReentrant returns (bytes32 messageId) {
        if (requestedDestinationDomain != destinationDomain) {
            revert InvalidRoute();
        }
        if (amount == 0 || recipient == bytes32(0)) {
            revert InvalidAmount();
        }

        uint256 routerNativeValueWei =
            _quoteRouterNative(recipient, amount);
        uint256 expectedValue =
            validatorFeeWei + routerNativeValueWei;

        if (msg.value != expectedValue) {
            revert InvalidValue(expectedValue, msg.value);
        }

        if (warpToken != address(0)) {
            if (
                !IILNERC20(warpToken).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                )
            ) revert TokenTransferFailed();
        }

        messageId = IILNWarpRouter(warpRouter).transferRemote{
            value: routerNativeValueWei
        }(destinationDomain, recipient, amount);

        if (messageId == bytes32(0)) revert InvalidMessageId();

        totalValidatorFeesEscrowedWei += validatorFeeWei;

        emit ILNOperation(
            messageId,
            destinationDomain,
            validatorFeeWei
        );
    }

    function _quoteRouterNative(
        bytes32 recipient,
        uint256 amount
    ) private view returns (uint256 nativeValueWei) {
        ILNQuote[] memory quotes =
            IILNWarpRouter(warpRouter).quoteTransferRemote(
                destinationDomain,
                recipient,
                amount
            );

        uint256 tokenQuote;
        for (uint256 i = 0; i < quotes.length; i++) {
            if (quotes[i].token == address(0)) {
                nativeValueWei += quotes[i].amount;
            } else if (
                warpToken != address(0) &&
                quotes[i].token == warpToken
            ) {
                tokenQuote += quotes[i].amount;
            } else {
                revert UnsupportedWarpFee();
            }
        }

        if (warpToken == address(0)) {
            if (!nativeQuoteIncludesPrincipal) {
                nativeValueWei += amount;
            }
            return nativeValueWei;
        }

        // Supported synthetic-router variants either omit the token quote or
        // echo the exact bridged principal. Any different token-denominated
        // charge is deliberately unsupported by the Base MVP.
        if (tokenQuote != 0 && tokenQuote != amount) {
            revert UnsupportedWarpFee();
        }
    }
}
