# Coverage Report

Command:

```bash
forge coverage --ir-minimum --report summary
```

Latest local run:

- Test suites: 19
- Tests: 129 passed, 0 failed, 0 skipped
- Contracts source scope: `src/`
- Source-only line coverage: 90.52% (296 / 327)
- Source-only function coverage: 97.22% (70 / 72)
- Foundry raw total row: 81.59% lines (461 / 565), because it includes scripts and test helpers

Foundry's raw `Total` row includes `script/` and helper contracts in `test/`, so it is lower than the course metric. The course requirement is coverage across the production contracts directory.

| File | Lines | Statements | Functions |
|---|---:|---:|---:|
| `src/Counter.sol` | 100.00% (4/4) | 100.00% (2/2) | 100.00% (2/2) |
| `src/core/AMM.sol` | 94.55% (52/55) | 92.86% (52/56) | 100.00% (6/6) |
| `src/core/LendingPool.sol` | 92.98% (106/114) | 92.00% (115/125) | 100.00% (18/18) |
| `src/core/MathLib.sol` | 50.00% (14/28) | 35.71% (10/28) | 100.00% (7/7) |
| `src/core/TreasuryV1.sol` | 95.45% (21/22) | 93.33% (14/15) | 100.00% (7/7) |
| `src/core/TreasuryV2.sol` | 100.00% (15/15) | 100.00% (10/10) | 100.00% (5/5) |
| `src/core/YieldVault.sol` | 81.82% (9/11) | 80.00% (8/10) | 75.00% (3/4) |
| `src/factories/AMMFactory.sol` | 96.15% (25/26) | 96.00% (24/25) | 100.00% (4/4) |
| `src/governance/DeFiGovernor.sol` | 90.00% (18/20) | 89.47% (17/19) | 90.00% (9/10) |
| `src/oracles/PriceFeed.sol` | 100.00% (16/16) | 100.00% (14/14) | 100.00% (3/3) |
| `src/tokens/GovToken.sol` | 100.00% (8/8) | 100.00% (5/5) | 100.00% (4/4) |
| `src/tokens/ProtocolBadge.sol` | 100.00% (8/8) | 100.00% (6/6) | 100.00% (2/2) |

## Test Inventory

| Category | Count | Notes |
|---|---:|---|
| Unit-style tests | 101 | AMM, factory, token, governor, treasury, vault, oracle, lending, badge, counter |
| Fuzz tests | 13 | AMM swap/liquidity, vault deposit/redeem, governance voting power, counter |
| Invariant tests | 7 | AMM reserves, k non-decrease on swap, vault assets, treasury accounting |
| Fork tests | 4 | Mainnet USDC, Chainlink ETH/USD, AMM with real tokens, Uniswap V2 router |
| Security case-study tests | 4 | Reproduced/fixed reentrancy and access-control examples |

## Coverage Risk Notes

`MathLib` has low line coverage because the Yul assembly and Solidity comparison routines share equivalent paths and the coverage mapper does not always anchor optimized assembly instructions. The benchmark and equivalence tests still execute the public functions. `YieldVault` inherits most ERC-4626 behavior from OpenZeppelin; the tests cover deposit, mint, withdraw, redeem through deposit/redeem flows, yield injection, preview, and conversion behavior.
