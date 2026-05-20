// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GovToken.sol";

contract GovernanceFuzzTest is Test {
    GovToken token;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.prank(owner);
        token = new GovToken(owner);
    }

    function testFuzz_VotingPowerTracksDelegatedBalance(uint256 amount) public {
        amount = bound(amount, 1, 100_000e18);

        vm.prank(owner);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.delegate(alice);

        vm.roll(block.number + 1);
        assertEq(token.getVotes(alice), amount);
    }

    function testFuzz_VotingPowerMovesAfterTransfer(uint256 initialAmount, uint256 transferAmount) public {
        initialAmount = bound(initialAmount, 2, 100_000e18);
        transferAmount = bound(transferAmount, 1, initialAmount - 1);

        vm.prank(owner);
        token.transfer(alice, initialAmount);

        vm.prank(alice);
        token.delegate(alice);

        vm.prank(bob);
        token.delegate(bob);

        vm.roll(block.number + 1);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.getVotes(alice), initialAmount - transferAmount);
        assertEq(token.getVotes(bob), transferAmount);
    }
}
