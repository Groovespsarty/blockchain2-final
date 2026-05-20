// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AggregatorV3Interface - Chainlink price feed interface
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

/// @title PriceFeed - Chainlink oracle adapter with staleness check
contract PriceFeed {
    AggregatorV3Interface public immutable feed;
    uint256 public immutable stalenessThreshold;

    event PriceRead(int256 price, uint256 updatedAt);

    constructor(address _feed, uint256 _stalenessThreshold) {
        require(_feed != address(0), "PriceFeed: zero address");
        require(_stalenessThreshold > 0, "PriceFeed: zero threshold");
        feed = AggregatorV3Interface(_feed);
        stalenessThreshold = _stalenessThreshold;
    }

    /// @notice Returns latest price, reverts if stale
    function getPrice() external view returns (int256 price, uint256 updatedAt) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 timestamp, uint80 answeredInRound) =
            feed.latestRoundData();

        require(timestamp > 0, "PriceFeed: round not complete");
        require(startedAt <= timestamp, "PriceFeed: invalid round time");
        require(block.timestamp - timestamp <= stalenessThreshold, "PriceFeed: stale price");
        require(answeredInRound >= roundId, "PriceFeed: stale round");
        require(answer > 0, "PriceFeed: invalid price");

        return (answer, timestamp);
    }

    /// @notice Returns decimals of the feed
    function decimals() external view returns (uint8) {
        return feed.decimals();
    }
}
