// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/TreasuryV1.sol";
import "../../src/core/TreasuryV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TreasuryTest is Test {
    TreasuryV1 treasury;
    MockERC20 token;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    function setUp() public {
        token = new MockERC20("USD Coin", "USDC");

        // Deploy via UUPS proxy
        TreasuryV1 impl = new TreasuryV1();
        bytes memory initData = abi.encodeWithSelector(TreasuryV1.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        treasury = TreasuryV1(address(proxy));

        token.mint(alice, 10_000e18);
        token.mint(owner, 10_000e18);
    }

    function test_Initialize() public view {
        assertEq(treasury.owner(), owner);
        assertEq(treasury.version(), "V1");
    }

    function test_Deposit() public {
        vm.startPrank(alice);
        token.approve(address(treasury), 1000e18);
        treasury.deposit(address(token), 1000e18);
        vm.stopPrank();

        assertEq(treasury.balances(address(token)), 1000e18);
    }

    function test_Deposit_ZeroAmount_Reverts() public {
        vm.prank(alice);
        vm.expectRevert("Treasury: zero amount");
        treasury.deposit(address(token), 0);
    }

    function test_Withdraw_ByOwner() public {
        vm.startPrank(alice);
        token.approve(address(treasury), 1000e18);
        treasury.deposit(address(token), 1000e18);
        vm.stopPrank();

        uint256 balBefore = token.balanceOf(alice);
        vm.prank(owner);
        treasury.withdraw(address(token), alice, 500e18);

        assertEq(token.balanceOf(alice), balBefore + 500e18);
        assertEq(treasury.balances(address(token)), 500e18);
    }

    function test_Withdraw_NonOwner_Reverts() public {
        vm.startPrank(alice);
        token.approve(address(treasury), 1000e18);
        treasury.deposit(address(token), 1000e18);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert();
        treasury.withdraw(address(token), alice, 500e18);
    }

    function test_Withdraw_InsufficientBalance_Reverts() public {
        vm.prank(owner);
        vm.expectRevert("Treasury: insufficient balance");
        treasury.withdraw(address(token), alice, 500e18);
    }

    function test_UpgradeToV2() public {
        TreasuryV2 implV2 = new TreasuryV2();

        vm.prank(owner);
        treasury.upgradeToAndCall(address(implV2), "");

        TreasuryV2 treasuryV2 = TreasuryV2(address(treasury));
        assertEq(treasuryV2.version(), "V2");
    }

    function test_V2_Pause() public {
        TreasuryV2 implV2 = new TreasuryV2();
        vm.prank(owner);
        treasury.upgradeToAndCall(address(implV2), "");
        TreasuryV2 treasuryV2 = TreasuryV2(address(treasury));

        vm.prank(owner);
        treasuryV2.pause();
        assertEq(treasuryV2.paused(), true);
    }

    function test_V2_DepositWhenPaused_Reverts() public {
        TreasuryV2 implV2 = new TreasuryV2();
        vm.prank(owner);
        treasury.upgradeToAndCall(address(implV2), "");
        TreasuryV2 treasuryV2 = TreasuryV2(address(treasury));

        vm.prank(owner);
        treasuryV2.pause();

        vm.startPrank(alice);
        token.approve(address(treasuryV2), 1000e18);
        vm.expectRevert("Treasury: paused");
        treasuryV2.deposit(address(token), 1000e18);
        vm.stopPrank();
    }

    function test_Withdraw_ZeroAmount_Reverts() public {
        vm.prank(owner);
        vm.expectRevert("Treasury: zero amount");
        treasury.withdraw(address(token), alice, 0);
    }

    function test_V2_Unpause() public {
    TreasuryV2 implV2 = new TreasuryV2();
    vm.prank(owner);
    treasury.upgradeToAndCall(address(implV2), "");
    TreasuryV2 treasuryV2 = TreasuryV2(address(treasury));

    vm.startPrank(owner);
    treasuryV2.pause();
    treasuryV2.unpause();
    vm.stopPrank();

    assertEq(treasuryV2.paused(), false);
}

function test_V2_DepositAfterUnpause() public {
    TreasuryV2 implV2 = new TreasuryV2();
    vm.prank(owner);
    treasury.upgradeToAndCall(address(implV2), "");
    TreasuryV2 treasuryV2 = TreasuryV2(address(treasury));

    vm.prank(owner);
    treasuryV2.pause();

    vm.prank(owner);
    treasuryV2.unpause();

    vm.startPrank(alice);
    token.approve(address(treasuryV2), 1000e18);
    treasuryV2.deposit(address(token), 1000e18);
    vm.stopPrank();

    assertEq(treasuryV2.balances(address(token)), 1000e18);
}

function test_V2_Version() public {
    TreasuryV2 implV2 = new TreasuryV2();
    vm.prank(owner);
    treasury.upgradeToAndCall(address(implV2), "");
    TreasuryV2 treasuryV2 = TreasuryV2(address(treasury));
    assertEq(treasuryV2.version(), "V2");
}

}
