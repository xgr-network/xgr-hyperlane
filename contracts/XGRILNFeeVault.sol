// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IXGRInterchainValidatorSetV2} from "./IXGRInterchainValidatorSetV2.sol";

/// @notice Native source-chain ILN fee accounting with pull withdrawals.
/// @dev A source-chain *governance quorum* approves a mirrored recipient
///      snapshot for one destination route. The snapshot is never accepted
///      from the relayer/caller alone. Distribution happens when the source
///      gateway pays its fee, NOT during destination settlement/re-attestation.
///      Governance must verify that the mirrored list corresponds to the
///      destination Interchain set before approving a proposal.
contract XGRILNFeeVault {
    uint256 internal constant MAX_RECIPIENTS = 128;
    bytes32 internal constant UPDATE_DOMAIN =
        keccak256("XGR_ILN_FEE_RECIPIENT_SNAPSHOT_V1");

    IXGRInterchainValidatorSetV2 public immutable governanceRegistry;
    address public immutable gateway;
    bytes32 public immutable routeId;
    uint32 public immutable destinationDomain;

    uint64 public recipientSetId;
    uint64 public updateNonce;
    address[] private recipients;
    mapping(address => uint256) public claimable;
    uint256 public totalAllocatedWei;
    uint256 public totalClaimedWei;
    uint256 private entered;

    error InvalidConfiguration();
    error InvalidSnapshot();
    error InvalidQuorum();
    error UnauthorizedGateway();
    error NothingToClaim();
    error TransferFailed();
    error Reentrancy();

    event RecipientSnapshotUpdated(uint64 indexed setId, uint64 indexed nonce, bytes32 recipientsHash);
    event FeeAllocated(bytes32 indexed messageId, uint64 indexed recipientSetId, uint256 amountWei);
    event Claimed(address indexed validator, uint256 amountWei);

    mapping(bytes32 => bool) public allocatedOperation;

    constructor(
        address governanceRegistry_,
        address gateway_,
        bytes32 routeId_,
        uint32 destinationDomain_
    ) {
        if (governanceRegistry_ == address(0) || gateway_ == address(0) ||
            routeId_ == bytes32(0) || destinationDomain_ == 0
        ) revert InvalidConfiguration();
        governanceRegistry = IXGRInterchainValidatorSetV2(governanceRegistry_);
        gateway = gateway_;
        routeId = routeId_;
        destinationDomain = destinationDomain_;
        entered = 1;
    }

    /// @notice Permissionless submission of a source-governance-approved,
    /// destination-scoped recipient snapshot. The source consensus quorum
    /// authenticates the allocation policy; a relayer cannot modify it.
    function updateRecipients(
        uint64 nextSetId,
        uint64 nonce,
        address[] calldata nextRecipients,
        bytes calldata bitmap,
        bytes calldata signature
    ) external {
        if (nextSetId <= recipientSetId ||
            nonce != updateNonce + 1 ||
            nextRecipients.length == 0 ||
            nextRecipients.length > MAX_RECIPIENTS
        ) revert InvalidSnapshot();

        // Require deterministic sorted unique nonzero addresses.
        for (uint256 i; i < nextRecipients.length; ++i) {
            if (nextRecipients[i] == address(0) ||
                (i != 0 && uint160(nextRecipients[i]) <= uint160(nextRecipients[i - 1]))
            ) revert InvalidSnapshot();
        }

        bytes32 recipientsHash = keccak256(abi.encode(nextRecipients));
        bytes memory message = abi.encode(
            UPDATE_DOMAIN,
            block.chainid,
            address(this),
            gateway,
            routeId,
            destinationDomain,
            nextSetId,
            nonce,
            recipientsHash
        );
        uint64 governanceSetId = governanceRegistry.setId();
        if (!governanceRegistry.verifyQuorum(
            governanceSetId, message, bitmap, signature
        )) revert InvalidQuorum();

        delete recipients;
        for (uint256 i; i < nextRecipients.length; ++i) {
            recipients.push(nextRecipients[i]);
        }
        recipientSetId = nextSetId;
        updateNonce = nonce;
        emit RecipientSnapshotUpdated(nextSetId, nonce, recipientsHash);
    }

    function recipientCount() external view returns (uint256) {
        return recipients.length;
    }

    function recipientAt(uint256 i) external view returns (address) {
        return recipients[i];
    }

    /// @notice Gateway must call this atomically with original source bridge.
    ///      Any later re-attestation does not call this method.
    function allocate(bytes32 messageId) external payable {
        if (msg.sender != gateway) revert UnauthorizedGateway();
        if (messageId == bytes32(0) || allocatedOperation[messageId] ||
            msg.value == 0 || recipientSetId == 0 || recipients.length == 0
        ) revert InvalidSnapshot();

        allocatedOperation[messageId] = true;
        uint256 n = recipients.length;
        uint256 share = msg.value / n;
        uint256 remainder = msg.value % n;
        // Assign deterministic remainder to the first recipient; no dust.
        for (uint256 i; i < n; ++i) {
            uint256 amount = share + (i == 0 ? remainder : 0);
            claimable[recipients[i]] += amount;
        }
        totalAllocatedWei += msg.value;
        emit FeeAllocated(messageId, recipientSetId, msg.value);
    }

    function claim() external {
        if (entered != 1) revert Reentrancy();
        entered = 2;
        uint256 amount = claimable[msg.sender];
        if (amount == 0) revert NothingToClaim();
        claimable[msg.sender] = 0;
        totalClaimedWei += amount;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();
        entered = 1;
        emit Claimed(msg.sender, amount);
    }
}
