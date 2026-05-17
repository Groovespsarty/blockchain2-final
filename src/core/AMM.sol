// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// @title AMM — Constant product AMM (x*y=k) with 0.3% fee
contract AMM is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1000;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 shares);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB)
        ERC20("AMM LP Token", "LP")
    {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /// @notice Add liquidity and receive LP tokens
    function addLiquidity(uint256 amountA, uint256 amountB)
        external nonReentrant returns (uint256 shares)
    {
        // Checks
        require(amountA > 0 && amountB > 0, "AMM: zero amount");

        // Effects
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            shares = _sqrt(amountA * amountB);
        } else {
            shares = _min(
                (amountA * totalSupply_) / reserveA,
                (amountB * totalSupply_) / reserveB
            );
        }
        require(shares > 0, "AMM: zero shares");

        reserveA += amountA;
        reserveB += amountB;
        _mint(msg.sender, shares);

        // Interactions
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        emit LiquidityAdded(msg.sender, amountA, amountB, shares);
    }

    /// @notice Remove liquidity by burning LP tokens
    function removeLiquidity(uint256 shares)
        external nonReentrant returns (uint256 amountA, uint256 amountB)
    {
        // Checks
        require(shares > 0, "AMM: zero shares");
        uint256 totalSupply_ = totalSupply();

        // Effects
        amountA = (shares * reserveA) / totalSupply_;
        amountB = (shares * reserveB) / totalSupply_;
        require(amountA > 0 && amountB > 0, "AMM: insufficient liquidity");

        reserveA -= amountA;
        reserveB -= amountB;
        _burn(msg.sender, shares);

        // Interactions
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, shares);
    }

    /// @notice Swap tokenA for tokenB or vice versa
    function swap(address _tokenIn, uint256 amountIn, uint256 minAmountOut)
        external nonReentrant returns (uint256 amountOut)
    {
        // Checks
        require(_tokenIn == address(tokenA) || _tokenIn == address(tokenB), "AMM: invalid token");
        require(amountIn > 0, "AMM: zero input");

        bool isTokenA = _tokenIn == address(tokenA);
        (uint256 reserveIn, uint256 reserveOut) = isTokenA
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        // Effects — apply 0.3% fee
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        amountOut = (amountInWithFee * reserveOut) /
            (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        require(amountOut >= minAmountOut, "AMM: slippage exceeded");

        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Interactions
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        (isTokenA ? tokenB : tokenA).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, _tokenIn, amountIn, amountOut);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) { z = x; x = (y / x + x) / 2; }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}