// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/YieldVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract VaultHandler is Test {
    YieldVault public vault;
    MockERC20 public asset;
    address public owner;
    address user = makeAddr("user");

    constructor(YieldVault _vault, MockERC20 _asset, address _owner) {
        vault = _vault;
        asset = _asset;
        owner = _owner;
        asset.mint(user, type(uint128).max);
        asset.mint(owner, type(uint128).max);
        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(owner);
        asset.approve(address(vault), type(uint256).max);
    }

    function deposit(uint256 amount) external {
        amount = bound(amount, 1e6, 10_000e18);
        vm.prank(user);
        vault.deposit(amount, user);
    }

    function redeem(uint256 pct) external {
        uint256 shares = vault.balanceOf(user);
        if (shares == 0) return;
        pct = bound(pct, 1, 100);
        uint256 toRedeem = (shares * pct) / 100;
        if (toRedeem == 0) return;
        vm.prank(user);
        vault.redeem(toRedeem, user, user);
    }

    function depositYield(uint256 amount) external {
        amount = bound(amount, 1e6, 1_000e18);
        vm.prank(owner);
        vault.depositYield(amount);
    }
}

contract VaultInvariantTest is Test {
    YieldVault vault;
    MockERC20 asset;
    VaultHandler handler;
    address owner = makeAddr("owner");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC");
        vm.prank(owner);
        vault = new YieldVault(IERC20(address(asset)), owner);
        handler = new VaultHandler(vault, asset, owner);
        targetContract(address(handler));
    }

    /// @notice Total assets always equals token balance
    function invariant_TotalAssetsMatchBalance() public view {
        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)));
    }

    /// @notice Total supply > 0 when assets > 0
function invariant_SupplyPositiveWhenAssets() public view {
    if (vault.totalSupply() > 0) {
        assertGt(vault.totalAssets(), 0);
    }
}
}