# Gas Optimization Report

## Scope

Gas review covers the production contracts in `src/`. The main optimization objective was to keep the protocol readable while demonstrating measurable improvements required by the course.

## Optimizations Applied

| Area | Before | After | Impact |
|---|---|---|---|
| Math utilities | Pure Solidity sqrt/min only | Yul assembly implementation plus Solidity comparator | Demonstrates lower-level optimization and benchmark path |
| AMM token transfers | Raw ERC20 calls considered | `SafeERC20` with CEI and one reserve update path | Safer external calls with predictable gas overhead |
| Treasury upgradeability | Transparent proxy considered | UUPS proxy | Lower per-call overhead; upgrade auth in implementation |
| Governance threshold | 1 token | 10,000 tokens | Reduces proposal spam and wasted governance gas |
| Factory deployment | CREATE only | CREATE and CREATE2 | Deterministic address option for integrations |
| Lending value math | Separate ad hoc branches | Shared scaling helpers | Reduces duplicated conversion logic |

## Benchmark Evidence

`test/unit/MathLib.t.sol` includes `test_Benchmark_Sqrt`, which measures gas for `sqrtAssembly` and `sqrtSolidity` in the same test. The exact values can vary with compiler and optimizer settings; the benchmark is included as executable evidence rather than a static claim.

Representative local run with optimizer enabled:

| Function | Observation |
|---|---|
| `sqrtAssembly` | Executes the Babylonian loop directly in Yul |
| `sqrtSolidity` | Same algorithm in Solidity |
| `minAssembly` | Single `lt` branch in Yul |
| `minSolidity` | Solidity ternary |

## L1 vs L2 Gas Cost Comparison

The project targets Arbitrum Sepolia. USD estimates are illustrative and depend on fee markets.

| Operation | Ethereum L1 estimate | Arbitrum Sepolia observed / expected |
|---|---:|---:|
| Deploy GovToken | $15-20 | <$0.01 |
| Deploy AMM pool | $25-30 | <$0.01 |
| AMM swap | $5-10 | <$0.01 |
| Add liquidity | $8-12 | <$0.01 |
| Vault deposit | $3-5 | <$0.01 |
| Governance vote | $2-5 | <$0.01 |
| Lending borrow | $5-10 | <$0.01 |
| Liquidation | $8-15 | <$0.01 |

## Remaining Tradeoffs

- `LendingPool` prioritizes explicit checks and readable accounting over hyper-optimized storage packing.
- `YieldVault` inherits OpenZeppelin ERC4626, which is standards-safe but not minimal-bytecode.
- `ProtocolBadge` uses ERC721URIStorage for demo friendliness; production could store compact metadata references.
- Governance uses the full OpenZeppelin Governor stack, which is heavier than a custom governor but materially safer.
