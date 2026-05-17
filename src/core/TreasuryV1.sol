// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TreasuryV1 — UUPS upgradeable treasury controlled by Timelock
contract TreasuryV1 is UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public balances;
    bool private _locked;

    event Deposited(address indexed token, address indexed from, uint256 amount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);

    modifier nonReentrant() {
        require(!_locked, "Treasury: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    function deposit(address token, uint256 amount) external virtual nonReentrant {
        require(amount > 0, "Treasury: zero amount");
        balances[token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(token, msg.sender, amount);
    }

    function withdraw(address token, address to, uint256 amount)
        external onlyOwner nonReentrant
    {
        require(amount > 0, "Treasury: zero amount");
        require(balances[token] >= amount, "Treasury: insufficient balance");
        balances[token] -= amount;
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawn(token, to, amount);
    }

    function version() external pure virtual returns (string memory) {
        return "V1";
    }

    function _authorizeUpgrade(address newImplementation)
        internal override onlyOwner {}
}