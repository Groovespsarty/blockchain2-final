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

contract AMMTest is Test {
    AMM amm;
    MockERC20 tokenA;
    MockERC20 tokenB;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(alice, 100_000e18);
        tokenB.mint(alice, 100_000e18);
        tokenA.mint(bob, 10_000e18);
        tokenB.mint(bob, 10_000e18);
    }

    function test_AddLiquidity() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000e18);
        tokenB.approve(address(amm), 1000e18);
        uint256 shares = amm.addLiquidity(1000e18, 1000e18);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(amm.reserveA(), 1000e18);
        assertEq(amm.reserveB(), 1000e18);
    }

    function test_AddLiquidity_ZeroAmount_Reverts() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000e18);
        tokenB.approve(address(amm), 1000e18);
        vm.expectRevert("AMM: zero amount");
        amm.addLiquidity(0, 1000e18);
        vm.stopPrank();
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000e18);
        tokenB.approve(address(amm), 1000e18);
        uint256 shares = amm.addLiquidity(1000e18, 1000e18);

        amm.approve(address(amm), shares);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(shares);
        vm.stopPrank();

        assertGt(outA, 0);
        assertGt(outB, 0);
    }

    function test_RemoveLiquidity_ZeroShares_Reverts() public {
        vm.expectRevert("AMM: zero shares");
        amm.removeLiquidity(0);
    }
    function test_Swap_AforB() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 10_000e18);
        tokenB.approve(address(amm), 10_000e18);
        amm.addLiquidity(10_000e18, 10_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(amm), 100e18);
        uint256 amountOut = amm.swap(address(tokenA), 100e18, 0);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertLt(amountOut, 100e18);
    }

    function test_Swap_InvalidToken_Reverts() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 10_000e18);
        tokenB.approve(address(amm), 10_000e18);
        amm.addLiquidity(10_000e18, 10_000e18);
        vm.stopPrank();

        vm.expectRevert("AMM: invalid token");
        amm.swap(address(0x123), 100e18, 0);
    }

    function test_Swap_SlippageProtection_Reverts() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 10_000e18);
        tokenB.approve(address(amm), 10_000e18);
        amm.addLiquidity(10_000e18, 10_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(amm), 100e18);
        vm.expectRevert("AMM: slippage exceeded");
        amm.swap(address(tokenA), 100e18, 999e18);
        vm.stopPrank();
    }

    function test_Swap_ZeroInput_Reverts() public {
        vm.expectRevert("AMM: zero input");
        amm.swap(address(tokenA), 0, 0);
    }

    function test_KInvariant() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 10_000e18);
        tokenB.approve(address(amm), 10_000e18);
        amm.addLiquidity(10_000e18, 10_000e18);
        vm.stopPrank();

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(bob);
        tokenA.approve(address(amm), 100e18);
        amm.swap(address(tokenA), 100e18, 0);
        vm.stopPrank();

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore);
    }

    function test_LPTokenName() public view {
        assertEq(amm.name(), "AMM LP Token");
        assertEq(amm.symbol(), "LP");
    }
}