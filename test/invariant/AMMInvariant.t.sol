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

/// @notice Handler drives AMM state for invariant testing
contract AMMHandler is Test {
    AMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address user = makeAddr("user");

    constructor(AMM _amm, MockERC20 _tokenA, MockERC20 _tokenB) {
        amm = _amm;
        tokenA = _tokenA;
        tokenB = _tokenB;

        tokenA.mint(user, type(uint128).max);
        tokenB.mint(user, type(uint128).max);

        vm.startPrank(user);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(10_000e18, 10_000e18);
        vm.stopPrank();
    }

    function swap(uint256 amountIn, bool aForB) external {
        amountIn = bound(amountIn, 1e15, 100e18);
        vm.startPrank(user);
        if (aForB) {
            amm.swap(address(tokenA), amountIn, 0);
        } else {
            amm.swap(address(tokenB), amountIn, 0);
        }
        vm.stopPrank();
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        amountA = bound(amountA, 1e15, 1_000e18);
        amountB = bound(amountB, 1e15, 1_000e18);
        vm.startPrank(user);
        amm.addLiquidity(amountA, amountB);
        vm.stopPrank();
    }

    function removeLiquidity(uint256 sharePct) external {
        uint256 shares = amm.balanceOf(user);
        if (shares == 0) return;
        sharePct = bound(sharePct, 1, 100);
        uint256 toRemove = (shares * sharePct) / 100;
        if (toRemove == 0) return;
        vm.startPrank(user);
        amm.approve(address(amm), toRemove);
        amm.removeLiquidity(toRemove);
        vm.stopPrank();
    }
}

contract AMMInvariantTest is Test {
    AMM amm;
    MockERC20 tokenA;
    MockERC20 tokenB;
    AMMHandler handler;

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMM(address(tokenA), address(tokenB));
        handler = new AMMHandler(amm, tokenA, tokenB);

        targetContract(address(handler));
    }

    /// @notice reserveA must equal actual tokenA balance
    function invariant_ReserveMatchesBalance() public view {
        assertEq(amm.reserveA(), tokenA.balanceOf(address(amm)));
        assertEq(amm.reserveB(), tokenB.balanceOf(address(amm)));
    }

    /// @notice Total supply of LP > 0 when reserves > 0
    function invariant_LPSupplyPositiveWhenReserves() public view {
        if (amm.reserveA() > 0 && amm.reserveB() > 0) {
            assertGt(amm.totalSupply(), 0);
        }
    }

    /// @notice Reserves never go to zero while LP exists
    function invariant_ReservesNonZeroWithLP() public view {
        if (amm.totalSupply() > 0) {
            assertGt(amm.reserveA(), 0);
            assertGt(amm.reserveB(), 0);
        }
    }
}