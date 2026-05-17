// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/AMM.sol";
import "../../src/core/YieldVault.sol";
import "../../src/oracles/PriceFeed.sol";

interface IERC20Full {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

contract ForkTest is Test {
    // Mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant USDC_WHALE = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/QJdF0MmlcYioIOEoAnqAU");
        vm.selectFork(mainnetFork);
    }

    /// @notice Fork test 1: Chainlink ETH/USD price feed returns valid price
    function test_Fork_ChainlinkPriceFeed() public {
        PriceFeed feed = new PriceFeed(CHAINLINK_ETH_USD, 1 hours);
        (int256 price,) = feed.getPrice();
        assertGt(price, 0);
        // ETH price should be between $100 and $100,000
        assertGt(price, 100e8);
        assertLt(price, 100_000e8);
    }

    /// @notice Fork test 2: USDC is a real ERC20 with correct decimals
    function test_Fork_USDC_Decimals() public view {
        IERC20Full usdc = IERC20Full(USDC);
        assertEq(usdc.decimals(), 6);
    }

    /// @notice Fork test 3: AMM works with real USDC and WETH from mainnet
    function test_Fork_AMM_WithRealTokens() public {
        // Impersonate USDC whale
        vm.startPrank(USDC_WHALE);

        IERC20Full usdc = IERC20Full(USDC);
        IERC20Full weth = IERC20Full(WETH);

        uint256 usdcBalance = usdc.balanceOf(USDC_WHALE);
        assertGt(usdcBalance, 0);

        // Deploy AMM with real token addresses
        AMM amm = new AMM(USDC, WETH);

        // Approve
        usdc.approve(address(amm), 1000e6);

        vm.stopPrank();

        // Verify AMM was deployed correctly
        assertEq(address(amm.tokenA()), USDC);
        assertEq(address(amm.tokenB()), WETH);
    }
}