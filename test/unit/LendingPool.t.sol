// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/LendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LendingMockERC20 is ERC20 {
    uint8 private immutable _customDecimals;

    constructor(string memory name, string memory symbol, uint8 customDecimals) ERC20(name, symbol) {
        _customDecimals = customDecimals;
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LendingMockPriceFeed {
    int256 private _price;

    constructor(int256 initialPrice) {
        _price = initialPrice;
    }

    function setPrice(int256 newPrice) external {
        _price = newPrice;
    }

    function getPrice() external view returns (int256 price, uint256 updatedAt) {
        return (_price, block.timestamp);
    }
}

contract LendingPoolTest is Test {
    LendingPool pool;
    LendingMockERC20 collateral;
    LendingMockERC20 debt;
    LendingMockPriceFeed collateralFeed;
    LendingMockPriceFeed debtFeed;

    address alice = makeAddr("alice");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        collateral = new LendingMockERC20("Wrapped Ether", "WETH", 18);
        debt = new LendingMockERC20("USD Coin", "USDC", 6);
        collateralFeed = new LendingMockPriceFeed(2_000e8);
        debtFeed = new LendingMockPriceFeed(1e8);
        pool = new LendingPool(
            IERC20(collateral),
            IERC20(debt),
            ILendingPriceFeed(address(collateralFeed)),
            ILendingPriceFeed(address(debtFeed))
        );

        collateral.mint(alice, 10e18);
        debt.mint(address(pool), 100_000e6);
        debt.mint(alice, 10_000e6);
        debt.mint(liquidator, 10_000e6);
    }

    function test_DepositCollateral() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 2e18);
        pool.depositCollateral(2e18);
        vm.stopPrank();

        assertEq(pool.collateralBalance(alice), 2e18);
        assertEq(collateral.balanceOf(address(pool)), 2e18);
    }

    function test_BorrowWithinLtv() public {
        _depositCollateral(alice, 5e18);

        vm.prank(alice);
        pool.borrow(4_000e6);

        assertEq(pool.debtPrincipal(alice), 4_000e6);
        assertEq(debt.balanceOf(alice), 14_000e6);
        assertGt(pool.healthFactor(alice), pool.MIN_HEALTH_FACTOR());
    }

    function test_BorrowAboveLtv_Reverts() public {
        _depositCollateral(alice, 5e18);

        vm.prank(alice);
        vm.expectRevert("Lending: exceeds LTV");
        pool.borrow(5_001e6);
    }

    function test_RepayAccruedDebt() public {
        _depositCollateral(alice, 5e18);

        vm.prank(alice);
        pool.borrow(1_000e6);

        vm.warp(block.timestamp + 30 days);

        vm.startPrank(alice);
        debt.approve(address(pool), type(uint256).max);
        uint256 repaid = pool.repay(2_000e6);
        vm.stopPrank();

        assertGt(repaid, 1_000e6);
        assertEq(pool.debtPrincipal(alice), 0);
    }

    function test_WithdrawWouldBreakHealth_Reverts() public {
        _depositCollateral(alice, 5e18);

        vm.prank(alice);
        pool.borrow(4_000e6);

        vm.prank(alice);
        vm.expectRevert("Lending: unhealthy");
        pool.withdrawCollateral(3e18);
    }

    function test_LiquidateUnhealthyPosition() public {
        _depositCollateral(alice, 5e18);

        vm.prank(alice);
        pool.borrow(4_000e6);

        collateralFeed.setPrice(1_000e8);

        vm.startPrank(liquidator);
        debt.approve(address(pool), 2_000e6);
        uint256 seized = pool.liquidate(alice, 2_000e6);
        vm.stopPrank();

        assertGt(seized, 0);
        assertLt(pool.collateralBalance(alice), 5e18);
        assertEq(pool.debtPrincipal(alice), 2_000e6);
        assertEq(collateral.balanceOf(liquidator), seized);
    }

    function test_MaxBorrow() public {
        _depositCollateral(alice, 2e18);

        uint256 maxBorrow = pool.maxBorrow(alice);
        assertEq(maxBorrow, 2_000e6);
    }

    function test_HealthyPositionCannotBeLiquidated() public {
        _depositCollateral(alice, 5e18);

        vm.prank(alice);
        pool.borrow(1_000e6);

        vm.startPrank(liquidator);
        debt.approve(address(pool), 1_000e6);
        vm.expectRevert("Lending: healthy");
        pool.liquidate(alice, 1_000e6);
        vm.stopPrank();
    }

    function _depositCollateral(address user, uint256 amount) internal {
        vm.startPrank(user);
        collateral.approve(address(pool), amount);
        pool.depositCollateral(amount);
        vm.stopPrank();
    }
}
