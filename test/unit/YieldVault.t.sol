// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/YieldVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldVaultTest is Test {
    YieldVault vault;
    MockERC20 asset;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC");
        vm.prank(owner);
        vault = new YieldVault(IERC20(address(asset)), owner);

        asset.mint(alice, 10_000e18);
        asset.mint(bob, 10_000e18);
        asset.mint(owner, 10_000e18);
    }

    function test_Deposit() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000e18);
        uint256 shares = vault.deposit(1000e18, alice);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        uint256 shares = vault.balanceOf(alice);
        vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
    }

    function test_DepositYield_IncreasesSharePrice() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        uint256 assetsBefore = vault.totalAssets();

        vm.startPrank(owner);
        asset.approve(address(vault), 500e18);
        vault.depositYield(500e18);
        vm.stopPrank();

        assertGt(vault.totalAssets(), assetsBefore);
    }

    function test_DepositYield_NonOwner_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.depositYield(100e18);
    }

    function test_DepositYield_ZeroAmount_Reverts() public {
        vm.prank(owner);
        vm.expectRevert("Vault: zero amount");
        vault.depositYield(0);
    }

    function test_SharePriceIncreasesAfterYield() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 assetsBefore = vault.convertToAssets(sharesBefore);

        vm.startPrank(owner);
        asset.approve(address(vault), 1000e18);
        vault.depositYield(1000e18);
        vm.stopPrank();

        uint256 assetsAfter = vault.convertToAssets(sharesBefore);
        assertGt(assetsAfter, assetsBefore);
    }

    function test_MultipleDepositors() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        asset.approve(address(vault), 1000e18);
        vault.deposit(1000e18, bob);
        vm.stopPrank();

        assertGt(vault.balanceOf(alice), 0);
        assertGt(vault.balanceOf(bob), 0);
        assertEq(vault.totalAssets(), 2000e18);
    }

    function test_VaultNameAndSymbol() public view {
        assertEq(vault.name(), "DeFi Vault Share");
        assertEq(vault.symbol(), "dvSHARE");
    }

    function test_TotalYieldDistributed() public {
        vm.startPrank(owner);
        asset.approve(address(vault), 500e18);
        vault.depositYield(500e18);
        vm.stopPrank();

        assertEq(vault.totalYieldDistributed(), 500e18);
    }
}
