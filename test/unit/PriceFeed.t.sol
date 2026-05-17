// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/oracles/PriceFeed.sol";

contract MockAggregator {
    int256 public price;
    uint256 public updatedAt;
    uint80 public roundId;
    uint8 public dec;

    constructor(int256 _price, uint8 _decimals) {
        price = _price;
        dec = _decimals;
        updatedAt = block.timestamp;
        roundId = 1;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, price, block.timestamp, updatedAt, roundId);
    }

    function decimals() external view returns (uint8) {
        return dec;
    }
}

contract PriceFeedTest is Test {
    PriceFeed feed;
    MockAggregator aggregator;

    uint256 constant STALENESS = 1 hours;

    function setUp() public {
        aggregator = new MockAggregator(2000e8, 8);
        feed = new PriceFeed(address(aggregator), STALENESS);
    }

    function test_GetPrice() public view {
        (int256 price,) = feed.getPrice();
        assertEq(price, 2000e8);
    }

    function test_GetPrice_Stale_Reverts() public {
        vm.warp(block.timestamp + 2 hours);
        aggregator.setUpdatedAt(block.timestamp - 2 hours);
        vm.expectRevert("PriceFeed: stale price");
        feed.getPrice();
    }

    function test_GetPrice_NegativePrice_Reverts() public {
        aggregator.setPrice(-1);
        vm.expectRevert("PriceFeed: invalid price");
        feed.getPrice();
    }

    function test_GetPrice_ZeroPrice_Reverts() public {
        aggregator.setPrice(0);
        vm.expectRevert("PriceFeed: invalid price");
        feed.getPrice();
    }

    function test_Decimals() public view {
        assertEq(feed.decimals(), 8);
    }

    function test_StalenessThreshold() public view {
        assertEq(feed.stalenessThreshold(), STALENESS);
    }

    function test_Constructor_ZeroAddress_Reverts() public {
        vm.expectRevert("PriceFeed: zero address");
        new PriceFeed(address(0), STALENESS);
    }

    function test_Constructor_ZeroThreshold_Reverts() public {
        vm.expectRevert("PriceFeed: zero threshold");
        new PriceFeed(address(aggregator), 0);
    }
}
