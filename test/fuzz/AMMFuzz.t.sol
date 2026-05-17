// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/AMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AMMFuzzTest is Test {
    AMM amm;
    MockERC20 tokenA;
    MockERC20 tokenB;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(alice, type(uint128).max);
        tokenB.mint(alice, type(uint128).max);
        tokenA.mint(bob, type(uint128).max);
        tokenB.mint(bob, type(uint128).max);
    }

    /// @notice K never decreases after swap
    function testFuzz_KInvariant(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e15, 1_000e18);

        vm.startPrank(alice);
        tokenA.approve(address(amm), 100_000e18);
        tokenB.approve(address(amm), 100_000e18);
        amm.addLiquidity(100_000e18, 100_000e18);
        vm.stopPrank();

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(bob);
        tokenA.approve(address(amm), amountIn);
        amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore);
    }

    /// @notice Output always less than reserve
    function testFuzz_SwapOutputLessThanReserve(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e15, 1_000e18);

        vm.startPrank(alice);
        tokenA.approve(address(amm), 100_000e18);
        tokenB.approve(address(amm), 100_000e18);
        amm.addLiquidity(100_000e18, 100_000e18);
        vm.stopPrank();

        uint256 reserveBBefore = amm.reserveB();

        vm.startPrank(bob);
        tokenA.approve(address(amm), amountIn);
        uint256 amountOut = amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();

        assertLt(amountOut, reserveBBefore);
    }

    /// @notice LP shares always proportional
    function testFuzz_AddLiquidityShares(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1e15, 10_000e18);
        amountB = bound(amountB, 1e15, 10_000e18);

        vm.startPrank(alice);
        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);
        uint256 shares = amm.addLiquidity(amountA, amountB);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(amm.balanceOf(alice), shares);
    }

    /// @notice Remove liquidity returns correct amounts
    function testFuzz_RemoveLiquidity(uint256 amount) public {
        amount = bound(amount, 1e15, 10_000e18);

        vm.startPrank(alice);
        tokenA.approve(address(amm), amount);
        tokenB.approve(address(amm), amount);
        uint256 shares = amm.addLiquidity(amount, amount);

        amm.approve(address(amm), shares);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(shares);
        vm.stopPrank();

        assertGt(outA, 0);
        assertGt(outB, 0);
    }

    /// @notice Vault deposit/withdraw roundtrip
    function testFuzz_SwapBothDirections(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e15, 1_000e18);

        vm.startPrank(alice);
        tokenA.approve(address(amm), 100_000e18);
        tokenB.approve(address(amm), 100_000e18);
        amm.addLiquidity(100_000e18, 100_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenB.approve(address(amm), amountIn);
        uint256 outA = amm.swap(address(tokenB), amountIn, 0);
        vm.stopPrank();

        assertGt(outA, 0);
        assertLt(outA, amm.reserveA() + outA);
    }
}