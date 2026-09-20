// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IXGRInterchainBLSVerifier} from "./XGRInterchainValidatorRegistry.sol";

/// @notice EIP-2537 verifier for XGR's BLS12-381 MinPk proof-of-possession signature scheme.
/// @dev Public keys are 128-byte uncompressed EIP-2537 G1 points and signatures are
///      256-byte uncompressed EIP-2537 G2 points. The signed message is hashed to G2
///      with BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_.
contract XGRInterchainBLSVerifier is IXGRInterchainBLSVerifier {
    bytes private constant BLS_SIGNATURE_DST = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_";

    uint256 private constant G1_LENGTH = 128;
    uint256 private constant G2_LENGTH = 256;

    address private constant MODEXP = address(0x05);
    address private constant BLS12_G1ADD = address(0x0b);
    address private constant BLS12_G2ADD = address(0x0d);
    address private constant BLS12_PAIRING = address(0x0f);
    address private constant BLS12_MAP_FP2_TO_G2 = address(0x11);

    bytes private constant BLS_PRIME =
        hex"000000000000000000000000000000001a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab";

    // -G1 generator in EIP-2537 wire format:
    // pad16(x) || x || pad16(-y) || -y.
    bytes private constant NEGATED_G1_GENERATOR =
        hex"0000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb00000000000000000000000000000000114d1d6855d545a8aa7d76c8cf2e21f267816aef1db507c96655b9d5caac42364e6f38ba0ecb751bad54dcd6b939c2ca";

    function verify(
        bytes calldata message,
        bytes[] calldata publicKeys,
        bytes calldata signerBitmap,
        bytes calldata aggregateSignature
    ) external view returns (bool) {
        if (aggregateSignature.length != G2_LENGTH || publicKeys.length == 0 || signerBitmap.length == 0) {
            return false;
        }

        bytes memory aggregatePublicKey;
        bool haveSigner;

        for (uint256 i = 0; i < publicKeys.length; i++) {
            if (publicKeys[i].length != G1_LENGTH) return false;
            if (!_bitmapContains(signerBitmap, i)) continue;

            if (!haveSigner) {
                aggregatePublicKey = publicKeys[i];
                haveSigner = true;
            } else {
                (bool addOK, bytes memory sum) =
                    BLS12_G1ADD.staticcall(bytes.concat(aggregatePublicKey, publicKeys[i]));
                if (!addOK || sum.length != G1_LENGTH) return false;
                aggregatePublicKey = sum;
            }
        }

        if (!haveSigner) return false;

        (bool hashOK, bytes memory messagePoint) = _hashToG2(message);
        if (!hashOK) return false;

        bytes memory pairingInput =
            bytes.concat(aggregatePublicKey, messagePoint, NEGATED_G1_GENERATOR, aggregateSignature);
        (bool pairingOK, bytes memory pairingResult) = BLS12_PAIRING.staticcall(pairingInput);
        return pairingOK && pairingResult.length == 32 && uint256(bytes32(pairingResult)) == 1;
    }

    function _bitmapContains(bytes calldata bitmap, uint256 index) internal pure returns (bool) {
        uint256 byteFromEnd = index >> 3;
        if (byteFromEnd >= bitmap.length) return false;
        uint256 bitIndex = index & 7;
        return (uint8(bitmap[bitmap.length - 1 - byteFromEnd]) & uint8(1 << bitIndex)) != 0;
    }

    function _hashToG2(bytes calldata message) internal view returns (bool, bytes memory) {
        bytes memory uniform = _expandMessageXmd(message);

        (bool ok0, bytes memory u00) = _modP(uniform, 0);
        if (!ok0) return (false, bytes(""));
        (bool ok1, bytes memory u01) = _modP(uniform, 64);
        if (!ok1) return (false, bytes(""));
        (bool ok2, bytes memory u10) = _modP(uniform, 128);
        if (!ok2) return (false, bytes(""));
        (bool ok3, bytes memory u11) = _modP(uniform, 192);
        if (!ok3) return (false, bytes(""));

        (bool map0OK, bytes memory q0) = BLS12_MAP_FP2_TO_G2.staticcall(bytes.concat(u00, u01));
        if (!map0OK || q0.length != G2_LENGTH) return (false, bytes(""));
        (bool map1OK, bytes memory q1) = BLS12_MAP_FP2_TO_G2.staticcall(bytes.concat(u10, u11));
        if (!map1OK || q1.length != G2_LENGTH) return (false, bytes(""));

        (bool addOK, bytes memory sum) = BLS12_G2ADD.staticcall(bytes.concat(q0, q1));
        if (!addOK || sum.length != G2_LENGTH) return (false, bytes(""));
        return (true, sum);
    }

    function _expandMessageXmd(bytes calldata message) internal pure returns (bytes memory uniform) {
        bytes memory dstPrime = abi.encodePacked(BLS_SIGNATURE_DST, uint8(BLS_SIGNATURE_DST.length));
        bytes32 b0 = sha256(
            abi.encodePacked(new bytes(64), message, uint16(256), uint8(0), dstPrime)
        );
        bytes32 bi = sha256(abi.encodePacked(b0, uint8(1), dstPrime));

        uniform = abi.encodePacked(bi);
        for (uint8 i = 2; i <= 8; i++) {
            bi = sha256(abi.encodePacked(b0 ^ bi, i, dstPrime));
            uniform = bytes.concat(uniform, abi.encodePacked(bi));
        }
    }

    function _modP(bytes memory uniform, uint256 offset) internal view returns (bool, bytes memory) {
        if (offset + 64 > uniform.length) return (false, bytes(""));

        bytes memory base = new bytes(64);
        for (uint256 i = 0; i < 64; i++) {
            base[i] = uniform[offset + i];
        }

        bytes memory input =
            abi.encodePacked(uint256(64), uint256(32), uint256(64), base, uint256(1), BLS_PRIME);
        (bool ok, bytes memory out) = MODEXP.staticcall(input);
        if (!ok || out.length != 64) return (false, bytes(""));
        return (true, out);
    }
}
