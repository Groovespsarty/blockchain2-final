// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TreasuryV1.sol";

/// @title TreasuryV2 — upgraded treasury with emergency pause
contract TreasuryV2 is TreasuryV1 {
    using SafeERC20 for IERC20;

    bool public paused;

    event Paused(address by);
    event Unpaused(address by);

    modifier whenNotPaused() {
        require(!paused, "Treasury: paused");
        _;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function deposit(address token, uint256 amount) external override nonReentrant whenNotPaused {
        require(amount > 0, "Treasury: zero amount");
        balances[token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(token, msg.sender, amount);
    }

    function version() external pure override returns (string memory) {
        return "V2";
    }
}
