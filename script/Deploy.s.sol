// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/tokens/GovToken.sol";
import "../src/governance/DeFiTimelock.sol";
import "../src/governance/DeFiGovernor.sol";
import "../src/core/AMM.sol";
import "../src/core/YieldVault.sol";
import "../src/core/TreasuryV1.sol";
import "../src/core/MathLib.sol";
import "../src/factories/AMMFactory.sol";
import "../src/oracles/PriceFeed.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    address constant CHAINLINK_ETH_USD = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
    address constant USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        address govToken = _deployGovernance(deployer);
        _deployCore(govToken);

        vm.stopBroadcast();
    }

    function _deployGovernance(address deployer) internal returns (address) {
        GovToken govToken = new GovToken(deployer);
        console.log("GovToken:", address(govToken));

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = deployer;
        executors[0] = address(0);

        DeFiTimelock timelock = new DeFiTimelock(proposers, executors, deployer);
        console.log("Timelock:", address(timelock));

        DeFiGovernor governor =
            new DeFiGovernor(IVotes(address(govToken)), TimelockController(payable(address(timelock))));
        console.log("Governor:", address(governor));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        TreasuryV1 impl = new TreasuryV1();
        bytes memory initData = abi.encodeWithSelector(TreasuryV1.initialize.selector, address(timelock));
        address treasury = address(new ERC1967Proxy(address(impl), initData));
        console.log("Treasury:", treasury);

        return address(govToken);
    }

    function _deployCore(address) internal {
        AMMFactory factory = new AMMFactory();
        console.log("AMMFactory:", address(factory));

        address pool = factory.createPool(WETH, USDC);
        console.log("WETH/USDC Pool:", pool);

        YieldVault vault = new YieldVault(IERC20(USDC), msg.sender);
        console.log("YieldVault:", address(vault));

        PriceFeed priceFeed = new PriceFeed(CHAINLINK_ETH_USD, 1 hours);
        console.log("PriceFeed:", address(priceFeed));

        MathLib mathLib = new MathLib();
        console.log("MathLib:", address(mathLib));
    }
}
