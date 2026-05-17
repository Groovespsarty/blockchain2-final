// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/MathLib.sol";

contract MathLibTest is Test {
    MathLib mathLib;

    function setUp() public {
        mathLib = new MathLib();
    }

    function test_SqrtAssembly_Zero() public view {
        assertEq(mathLib.sqrtAssembly(0), 0);
    }

    function test_SqrtAssembly_One() public view {
        assertEq(mathLib.sqrtAssembly(1), 1);
    }

    function test_SqrtAssembly_PerfectSquare() public view {
        assertEq(mathLib.sqrtAssembly(100), 10);
        assertEq(mathLib.sqrtAssembly(144), 12);
    }

    function test_SqrtAssembly_MatchesSolidity() public view {
        uint256[] memory inputs = new uint256[](5);
        inputs[0] = 4;
        inputs[1] = 1000;
        inputs[2] = 1e18;
        inputs[3] = 1337;
        inputs[4] = type(uint128).max;

        for (uint256 i = 0; i < inputs.length; i++) {
            assertEq(mathLib.sqrtAssembly(inputs[i]), mathLib.sqrtSolidity(inputs[i]));
        }
    }

    /// @notice Benchmark: assembly vs solidity gas
    function test_Benchmark_Sqrt() public {
        uint256 input = 1e18;

        uint256 gasBefore = gasleft();
        mathLib.sqrtAssembly(input);
        uint256 gasAssembly = gasBefore - gasleft();

        gasBefore = gasleft();
        mathLib.sqrtSolidity(input);
        uint256 gasSolidity = gasBefore - gasleft();

        emit log_named_uint("Gas sqrtAssembly", gasAssembly);
        emit log_named_uint("Gas sqrtSolidity", gasSolidity);
    }

    function test_MinAssembly_MatchesSolidity() public view {
        assertEq(mathLib.minAssembly(5, 10), mathLib.minSolidity(5, 10));
        assertEq(mathLib.minAssembly(10, 5), mathLib.minSolidity(10, 5));
        assertEq(mathLib.minAssembly(7, 7), mathLib.minSolidity(7, 7));
    }

    function test_IsZeroAddress() public view {
        assertEq(mathLib.isZeroAddress(address(0)), true);
        assertEq(mathLib.isZeroAddress(address(0x123)), false);
    }

    function test_PackUnpack() public view {
        uint128 a = 12345;
        uint128 b = 67890;
        uint256 packed = mathLib.pack(a, b);
        (uint128 ua, uint128 ub) = mathLib.unpack(packed);
        assertEq(ua, a);
        assertEq(ub, b);
    }
}
