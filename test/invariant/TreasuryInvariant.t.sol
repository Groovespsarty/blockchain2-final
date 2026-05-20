// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/TreasuryV1.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TreasuryInvariantToken is ERC20 {
    constructor() ERC20("Treasury Invariant Token", "TIT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TreasuryHandler is Test {
    TreasuryV1 public treasury;
    TreasuryInvariantToken public token;
    address public owner;
    address public user = makeAddr("treasury-user");

    constructor(TreasuryV1 _treasury, TreasuryInvariantToken _token, address _owner) {
        treasury = _treasury;
        token = _token;
        owner = _owner;

        token.mint(user, type(uint128).max);
        vm.prank(user);
        token.approve(address(treasury), type(uint256).max);
    }

    function deposit(uint256 amount) external {
        amount = bound(amount, 1, 10_000e18);
        vm.prank(user);
        treasury.deposit(address(token), amount);
    }

    function withdraw(uint256 pct) external {
        uint256 balance = treasury.balances(address(token));
        if (balance == 0) return;

        pct = bound(pct, 1, 100);
        uint256 amount = (balance * pct) / 100;
        if (amount == 0) return;

        vm.prank(owner);
        treasury.withdraw(address(token), owner, amount);
    }
}

contract TreasuryInvariantTest is Test {
    TreasuryV1 treasury;
    TreasuryInvariantToken token;
    TreasuryHandler handler;

    address owner = makeAddr("treasury-owner");

    function setUp() public {
        TreasuryV1 impl = new TreasuryV1();
        bytes memory initData = abi.encodeWithSelector(TreasuryV1.initialize.selector, owner);
        treasury = TreasuryV1(address(new ERC1967Proxy(address(impl), initData)));
        token = new TreasuryInvariantToken();
        handler = new TreasuryHandler(treasury, token, owner);

        targetContract(address(handler));
    }

    function invariant_TreasuryAccountingMatchesTokenBalance() public view {
        assertEq(treasury.balances(address(token)), token.balanceOf(address(treasury)));
    }
}
