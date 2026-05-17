// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GovToken.sol";
import "../../src/governance/DeFiTimelock.sol";
import "../../src/governance/DeFiGovernor.sol";

contract GovernorTest is Test {
    GovToken token;
    DeFiTimelock timelock;
    DeFiGovernor governor;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(owner);
        token = new GovToken(owner);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = owner;
        executors[0] = address(0);

        timelock = new DeFiTimelock(proposers, executors, owner);
        governor = new DeFiGovernor(
            IVotes(address(token)),
            TimelockController(payable(address(timelock)))
        );

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Give alice tokens and delegate
        token.transfer(alice, 100_000e18);
        vm.stopPrank();

        vm.prank(alice);
        token.delegate(alice);

        vm.roll(block.number + 1);
    }

    function test_GovernorName() public view {
        assertEq(governor.name(), "DeFiGovernor");
    }

    function test_VotingDelay() public view {
        assertEq(governor.votingDelay(), 1 days);
    }

    function test_VotingPeriod() public view {
        assertEq(governor.votingPeriod(), 1 weeks);
    }

    function test_ProposalThreshold() public view {
        assertEq(governor.proposalThreshold(), 1e18);
    }

    function test_Quorum() public view {
        uint256 q = governor.quorum(block.number - 1);
        assertGt(q, 0);
    }

    function test_ProposeAndVote() public {
        // Give alice enough tokens for threshold
        vm.prank(owner);
        token.transfer(alice, 1e18);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(token);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("totalSupply()");

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets, values, calldatas, "Test proposal"
        );

        // Wait voting delay
        vm.roll(block.number + 1 days + 1);

        // Vote
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        // Check state is Active
        assertEq(uint256(governor.state(proposalId)), 1); // Active
    }

    function test_TokenAddress() public view {
        assertEq(address(governor.token()), address(token));
    }

    function test_TimelockAddress() public view {
        assertEq(address(governor.timelock()), address(timelock));
    }

    function test_CastVoteAgainst() public {
    vm.prank(owner);
    token.transfer(alice, 1e18);
    vm.roll(block.number + 1);

    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(token);
    values[0] = 0;
    calldatas[0] = abi.encodeWithSignature("totalSupply()");

    vm.prank(alice);
    uint256 proposalId = governor.propose(targets, values, calldatas, "Test 2");

    vm.roll(block.number + 1 days + 1);

    vm.prank(alice);
    governor.castVote(proposalId, 0); // against
}

function test_CastVoteAbstain() public {
    vm.prank(owner);
    token.transfer(alice, 1e18);
    vm.roll(block.number + 1);

    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(token);
    values[0] = 0;
    calldatas[0] = abi.encodeWithSignature("totalSupply()");

    vm.prank(alice);
    uint256 proposalId = governor.propose(targets, values, calldatas, "Test 3");

    vm.roll(block.number + 1 days + 1);

    vm.prank(alice);
    governor.castVote(proposalId, 2); // abstain
}

function test_ProposalDefeated() public {
    vm.prank(owner);
    token.transfer(alice, 1e18);
    vm.roll(block.number + 1);

    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(token);
    values[0] = 0;
    calldatas[0] = abi.encodeWithSignature("totalSupply()");

    vm.prank(alice);
    uint256 proposalId = governor.propose(targets, values, calldatas, "Test 4");

    vm.roll(block.number + 1 days + 1);
    vm.prank(alice);
    governor.castVote(proposalId, 0); // vote against

    vm.roll(block.number + 1 weeks + 1);
    assertEq(uint256(governor.state(proposalId)), 3); // Defeated
}

function test_ProposalNeedsQueuing() public {
    vm.prank(owner);
    token.transfer(alice, 1e18);
    vm.roll(block.number + 1);

    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(token);
    values[0] = 0;
    calldatas[0] = abi.encodeWithSignature("totalSupply()");

    vm.prank(alice);
    uint256 proposalId = governor.propose(targets, values, calldatas, "Test 5");

    assertTrue(governor.proposalNeedsQueuing(proposalId));
}

}