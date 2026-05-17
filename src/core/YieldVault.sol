// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title YieldVault — ERC-4626 tokenized yield vault
contract YieldVault is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public totalYieldDistributed;

    event YieldDeposited(uint256 amount);

    constructor(
        IERC20 _asset,
        address _owner
    )
        ERC4626(_asset)
        ERC20("DeFi Vault Share", "dvSHARE")
        Ownable(_owner)
    {}

    /// @notice Owner deposits yield into the vault (increases share price)
    function depositYield(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Vault: zero amount");

        // Effects
        totalYieldDistributed += amount;

        // Interactions
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);

        emit YieldDeposited(amount);
    }

    /// @notice Override deposit with reentrancy guard
    function deposit(uint256 assets, address receiver)
        public override nonReentrant returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    /// @notice Override withdraw with reentrancy guard
    function withdraw(uint256 assets, address receiver, address owner_)
        public override nonReentrant returns (uint256)
    {
        return super.withdraw(assets, receiver, owner_);
    }

    /// @notice Override redeem with reentrancy guard
    function redeem(uint256 shares, address receiver, address owner_)
        public override nonReentrant returns (uint256)
    {
        return super.redeem(shares, receiver, owner_);
    }
}