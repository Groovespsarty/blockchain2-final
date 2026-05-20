// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/tokens/GovToken.sol";
import "../src/governance/DeFiTimelock.sol";
import "../src/governance/DeFiGovernor.sol";
import "../src/core/TreasuryV1.sol";

contract VerifyDeployment is Script {
    function run() external view {
        GovToken govToken = GovToken(vm.envAddress("GOV_TOKEN"));
        DeFiTimelock timelock = DeFiTimelock(payable(vm.envAddress("TIMELOCK")));
        DeFiGovernor governor = DeFiGovernor(payable(vm.envAddress("GOVERNOR")));
        TreasuryV1 treasury = TreasuryV1(vm.envAddress("TREASURY"));
        address deployer = vm.envAddress("DEPLOYER");

        require(govToken.owner() == address(timelock), "GovToken owner is not Timelock");
        require(treasury.owner() == address(timelock), "Treasury owner is not Timelock");
        require(timelock.getMinDelay() == 2 days, "Timelock delay mismatch");
        require(governor.votingDelay() == 1 days, "Governor voting delay mismatch");
        require(governor.votingPeriod() == 1 weeks, "Governor voting period mismatch");
        require(governor.proposalThreshold() == 10_000e18, "Governor proposal threshold mismatch");
        require(governor.quorum(block.number - 1) > 0, "Governor quorum unavailable");
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)), "Governor missing proposer role");
        require(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)), "Governor missing canceller role");
        require(!timelock.hasRole(timelock.PROPOSER_ROLE(), deployer), "Deployer still has proposer role");
        require(!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), deployer), "Deployer still has admin role");

        console.log("Deployment verification passed");
    }
}
