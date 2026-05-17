// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MathLib — Yul assembly math utilities, benchmarked vs Solidity
contract MathLib {
    /// @notice Square root via Yul assembly (Babylonian method)
    function sqrtAssembly(uint256 x) external pure returns (uint256 z) {
        assembly {
            switch x
            case 0 { z := 0 }
            default {
                z := x
                let y := add(div(x, 2), 1)
                for {} lt(y, z) {} {
                    z := y
                    y := div(add(div(x, y), y), 2)
                }
            }
        }
    }

    /// @notice Square root via pure Solidity (for benchmarking)
    function sqrtSolidity(uint256 y) external pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @notice Min of two numbers via Yul assembly
    function minAssembly(uint256 a, uint256 b) external pure returns (uint256 result) {
        assembly {
            result := xor(a, mul(xor(a, b), lt(b, a)))
        }
    }

    /// @notice Min via pure Solidity (for benchmarking)
    function minSolidity(uint256 a, uint256 b) external pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Checks if address is zero via Yul assembly
    function isZeroAddress(address addr) external pure returns (bool result) {
        assembly {
            result := iszero(addr)
        }
    }

    /// @notice Pack two uint128 into one uint256 via assembly
    function pack(uint128 a, uint128 b) external pure returns (uint256 result) {
        assembly {
            result := or(shl(128, a), b)
        }
    }

    /// @notice Unpack uint256 into two uint128 via assembly
    function unpack(uint256 packed) external pure returns (uint128 a, uint128 b) {
        assembly {
            a := shr(128, packed)
            b := and(packed, 0xffffffffffffffffffffffffffffffff)
        }
    }
}
