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

contract VaultFuzzTest is Test {
    YieldVault vault;
    MockERC20 asset;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC");
        vm.prank(owner);
        vault = new YieldVault(IERC20(address(asset)), owner);
        asset.mint(alice, type(uint128).max);
        asset.mint(owner, type(uint128).max);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(owner);
        asset.approve(address(vault), type(uint256).max);
    }

    /// @notice Deposit then redeem returns <= deposited (no inflation)
    function testFuzz_DepositRedeem(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e18);

        uint256 balBefore = asset.balanceOf(alice);

        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);

        vm.prank(alice);
        uint256 returned = vault.redeem(shares, alice, alice);

        assertLe(returned, amount);
        assertGe(asset.balanceOf(alice), balBefore - 1);
    }

    /// @notice Total assets always >= sum of deposits
    function testFuzz_TotalAssetsGrowsWithDeposit(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000e18);

        uint256 before = vault.totalAssets();

        vm.prank(alice);
        vault.deposit(amount, alice);

        assertEq(vault.totalAssets(), before + amount);
    }

    /// @notice Shares minted always > 0 for valid deposit
    function testFuzz_SharesAlwaysPositive(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000e18);

        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);

        assertGt(shares, 0);
    }

    /// @notice Yield deposit increases convertToAssets
    function testFuzz_YieldIncreasesShareValue(uint256 deposit, uint256 yield) public {
        deposit = bound(deposit, 1e6, 100_000e18);
        yield = bound(yield, 1e6, 100_000e18);

        vm.prank(alice);
        uint256 shares = vault.deposit(deposit, alice);

        uint256 assetsBefore = vault.convertToAssets(shares);

        vm.prank(owner);
        vault.depositYield(yield);

        uint256 assetsAfter = vault.convertToAssets(shares);
        assertGe(assetsAfter, assetsBefore);
    }

    /// @notice previewDeposit matches actual shares
    function testFuzz_PreviewDepositAccurate(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000e18);

        uint256 preview = vault.previewDeposit(amount);

        vm.prank(alice);
        uint256 actual = vault.deposit(amount, alice);

        assertEq(preview, actual);
    }
}
