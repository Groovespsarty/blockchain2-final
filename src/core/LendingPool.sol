// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ILendingPriceFeed {
    function getPrice() external view returns (int256 price, uint256 updatedAt);
}

/// @title LendingPool
/// @notice Over-collateralized lending pool with LTV, health factor, liquidation, and linear interest.
contract LendingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable collateralToken;
    IERC20 public immutable debtToken;
    ILendingPriceFeed public immutable collateralPriceFeed;
    ILendingPriceFeed public immutable debtPriceFeed;

    uint256 public constant BPS = 10_000;
    uint256 public constant LTV_BPS = 5_000;
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 7_500;
    uint256 public constant LIQUIDATION_BONUS_BPS = 500;
    uint256 public constant INTEREST_RATE_BPS_PER_YEAR = 500;
    uint256 public constant YEAR = 365 days;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public debtPrincipal;
    mapping(address => uint256) public lastAccruedAt;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed borrower, address indexed liquidator, uint256 repaid, uint256 collateralSeized);

    constructor(
        IERC20 _collateralToken,
        IERC20 _debtToken,
        ILendingPriceFeed _collateralPriceFeed,
        ILendingPriceFeed _debtPriceFeed
    ) {
        require(address(_collateralToken) != address(0), "Lending: zero collateral token");
        require(address(_debtToken) != address(0), "Lending: zero debt token");
        require(address(_collateralPriceFeed) != address(0), "Lending: zero collateral feed");
        require(address(_debtPriceFeed) != address(0), "Lending: zero debt feed");

        collateralToken = _collateralToken;
        debtToken = _debtToken;
        collateralPriceFeed = _collateralPriceFeed;
        debtPriceFeed = _debtPriceFeed;
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Lending: zero amount");

        collateralBalance[msg.sender] += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Lending: zero amount");
        require(collateralBalance[msg.sender] >= amount, "Lending: insufficient collateral");

        _accrue(msg.sender);
        collateralBalance[msg.sender] -= amount;
        require(_isHealthy(msg.sender), "Lending: unhealthy");

        collateralToken.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        require(amount > 0, "Lending: zero amount");
        require(debtToken.balanceOf(address(this)) >= amount, "Lending: insufficient liquidity");

        _accrue(msg.sender);
        debtPrincipal[msg.sender] += amount;
        require(_isHealthy(msg.sender), "Lending: exceeds LTV");

        debtToken.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant returns (uint256 repaid) {
        require(amount > 0, "Lending: zero amount");

        _accrue(msg.sender);
        uint256 debt = debtPrincipal[msg.sender];
        require(debt > 0, "Lending: no debt");

        repaid = amount > debt ? debt : amount;
        debtPrincipal[msg.sender] = debt - repaid;
        debtToken.safeTransferFrom(msg.sender, address(this), repaid);

        emit Repaid(msg.sender, repaid);
    }

    function liquidate(address borrower, uint256 repayAmount) external nonReentrant returns (uint256 seizedCollateral) {
        require(borrower != address(0), "Lending: zero borrower");
        require(repayAmount > 0, "Lending: zero amount");

        _accrue(borrower);
        require(healthFactor(borrower) < MIN_HEALTH_FACTOR, "Lending: healthy");

        uint256 debt = debtPrincipal[borrower];
        uint256 repaid = repayAmount > debt ? debt : repayAmount;
        uint256 repayValue = _debtAmountToValue(repaid);
        seizedCollateral = _valueToCollateralAmount((repayValue * (BPS + LIQUIDATION_BONUS_BPS)) / BPS);

        uint256 availableCollateral = collateralBalance[borrower];
        if (seizedCollateral > availableCollateral) {
            seizedCollateral = availableCollateral;
        }

        debtPrincipal[borrower] = debt - repaid;
        collateralBalance[borrower] = availableCollateral - seizedCollateral;

        debtToken.safeTransferFrom(msg.sender, address(this), repaid);
        collateralToken.safeTransfer(msg.sender, seizedCollateral);

        emit Liquidated(borrower, msg.sender, repaid, seizedCollateral);
    }

    function debtWithInterest(address user) public view returns (uint256) {
        uint256 principal = debtPrincipal[user];
        if (principal < 1) {
            return 0;
        }

        uint256 last = lastAccruedAt[user];
        if (last < 1 || block.timestamp < last + 1) {
            return principal;
        }

        uint256 elapsed = block.timestamp - last;
        return principal + ((principal * INTEREST_RATE_BPS_PER_YEAR * elapsed) / (BPS * YEAR));
    }

    function healthFactor(address user) public view returns (uint256) {
        uint256 debtValue = _debtAmountToValue(debtWithInterest(user));
        if (debtValue < 1) {
            return type(uint256).max;
        }

        uint256 collateralValue = _collateralAmountToValue(collateralBalance[user]);
        return (collateralValue * LIQUIDATION_THRESHOLD_BPS * 1e18) / (BPS * debtValue);
    }

    function maxBorrow(address user) external view returns (uint256) {
        uint256 collateralValue = _collateralAmountToValue(collateralBalance[user]);
        uint256 borrowLimitValue = (collateralValue * LTV_BPS) / BPS;
        uint256 currentDebtValue = _debtAmountToValue(debtWithInterest(user));

        if (borrowLimitValue <= currentDebtValue) {
            return 0;
        }

        return _valueToDebtAmount(borrowLimitValue - currentDebtValue);
    }

    function _accrue(address user) internal {
        debtPrincipal[user] = debtWithInterest(user);
        lastAccruedAt[user] = block.timestamp;
    }

    function _isHealthy(address user) internal view returns (bool) {
        uint256 debtValue = _debtAmountToValue(debtPrincipal[user]);
        if (debtValue < 1) {
            return true;
        }

        uint256 collateralValue = _collateralAmountToValue(collateralBalance[user]);
        return (collateralValue * LTV_BPS) / BPS >= debtValue;
    }

    function _collateralAmountToValue(uint256 amount) internal view returns (uint256) {
        return (_scaleTo18(address(collateralToken), amount) * _positivePrice(collateralPriceFeed)) / 1e8;
    }

    function _debtAmountToValue(uint256 amount) internal view returns (uint256) {
        return (_scaleTo18(address(debtToken), amount) * _positivePrice(debtPriceFeed)) / 1e8;
    }

    function _valueToCollateralAmount(uint256 value) internal view returns (uint256) {
        return _descaleFrom18(address(collateralToken), (value * 1e8) / _positivePrice(collateralPriceFeed));
    }

    function _valueToDebtAmount(uint256 value) internal view returns (uint256) {
        return _descaleFrom18(address(debtToken), (value * 1e8) / _positivePrice(debtPriceFeed));
    }

    function _positivePrice(ILendingPriceFeed feed) internal view returns (uint256) {
        (int256 price, uint256 updatedAt) = feed.getPrice();
        require(price > 0, "Lending: invalid price");
        require(updatedAt > 0, "Lending: invalid price time");
        return uint256(price);
    }

    function _scaleTo18(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        if (decimals == 18) {
            return amount;
        }
        if (decimals < 18) {
            return amount * (10 ** (18 - decimals));
        }
        return amount / (10 ** (decimals - 18));
    }

    function _descaleFrom18(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        if (decimals == 18) {
            return amount;
        }
        if (decimals < 18) {
            return amount / (10 ** (18 - decimals));
        }
        return amount * (10 ** (decimals - 18));
    }
}
