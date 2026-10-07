// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Verifies a completed XGR Interchain governance quorum without
///         becoming an independent validator-membership authority.
/// @dev The concrete implementation must anchor membership to the canonical
///      destination-specific validator registry / validator-set commitment.
interface IXGRILNGovernanceVerifier {
    function verifyGovernanceQuorum(
        uint32 destinationDomain,
        uint64 setId,
        bytes calldata payload,
        bytes calldata signerBitmap,
        bytes calldata aggregateSignature,
        bytes calldata membershipProof
    ) external view returns (bool);
}
