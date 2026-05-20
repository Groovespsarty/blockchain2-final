// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GovToken.sol";
import "../../src/governance/DeFiTimelock.sol";
import "../../src/governance/DeFiGovernor.sol";
import "../../src/core/TreasuryV1.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GovernanceMockERC20 is ERC20 {
    constructor() ERC20("Treasury Asset", "TAS") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract GovernorTest is Test {
    GovToken token;
    DeFiTimelock timelock;
    DeFiGovernor governor;
    TreasuryV1 treasury;
    GovernanceMockERC20 asset;

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
        governor = new DeFiGovernor(IVotes(address(token)), TimelockController(payable(address(timelock))));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        TreasuryV1 impl = new TreasuryV1();
        bytes memory initData = abi.encodeWithSelector(TreasuryV1.initialize.selector, address(timelock));
        treasury = TreasuryV1(address(new ERC1967Proxy(address(impl), initData)));
        asset = new GovernanceMockERC20();
        asset.mint(owner, 1_000e18);
        asset.approve(address(treasury), 1_000e18);
        treasury.deposit(address(asset), 1_000e18);

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
        assertEq(governor.proposalThreshold(), 10_000e18);
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
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test proposal");

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

    function test_FullLifecycle_QueueAndExecuteTreasuryWithdraw() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(TreasuryV1.withdraw.selector, address(asset), bob, 100e18);
        string memory description = "Withdraw treasury asset to bob";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        assertEq(uint256(governor.state(proposalId)), 4); // Succeeded

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), 5); // Queued

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(uint256(governor.state(proposalId)), 7); // Executed
        assertEq(asset.balanceOf(bob), 100e18);
    }
}
