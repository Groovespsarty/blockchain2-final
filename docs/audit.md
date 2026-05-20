# Security Audit Report - DeFi Super-App

## Executive Summary

This internal audit covers the DeFi Super-App contracts in `src/` at the current working tree. The protocol includes an AMM, lending pool, ERC4626 vault, UUPS treasury, ERC20Votes governance token, ERC721 badge, Chainlink oracle adapter, Governor, Timelock, and AMM factory. The review found no known Critical, High, or Medium issues after remediation. Remaining risks are Low or Informational and are documented below.

The most important security change since the first draft is governance hardening: `GovToken` ownership is transferred to the Timelock, the deployer proposer role is revoked, the Treasury proxy is initialized with the Timelock as owner, and a post-deployment verification script checks these conditions.

## Scope

In scope:

- `src/core/AMM.sol`
- `src/core/LendingPool.sol`
- `src/core/YieldVault.sol`
- `src/core/TreasuryV1.sol`
- `src/core/TreasuryV2.sol`
- `src/core/MathLib.sol`
- `src/tokens/GovToken.sol`
- `src/tokens/ProtocolBadge.sol`
- `src/governance/DeFiGovernor.sol`
- `src/governance/DeFiTimelock.sol`
- `src/factories/AMMFactory.sol`
- `src/oracles/PriceFeed.sol`

Out of scope:

- OpenZeppelin dependency internals
- Foundry standard library internals
- Frontend UI security beyond transaction/error handling
- The Graph hosted infrastructure

## Methodology

- Manual review of authorization, accounting, CEI, reentrancy, oracle, and governance paths
- Unit tests for public/external functions and revert paths
- Fuzz tests for AMM swaps, vault flows, and governance voting power
- Invariant tests for AMM accounting, AMM k behavior, vault assets, and treasury accounting
- Fork tests against mainnet USDC, Chainlink ETH/USD, and Uniswap V2 Router
- Slither configured in CI to fail on Medium or higher findings

## Findings Summary

| ID | Title | Severity | Status |
|---|---|---:|---|
| S-01 | Deployer retained governance authority in first deployment draft | High | Fixed |
| S-02 | Missing ERC721/ERC1155 token standard | Medium | Fixed |
| S-03 | Missing lending primitive for Option A scope | Medium | Fixed |
| S-04 | Proposal threshold was 1 token, not 1% supply | Medium | Fixed |
| S-05 | Subgraph ABI files missing | Medium | Fixed |
| S-06 | Sandwich risk in constant-product AMM | Low | Acknowledged |
| S-07 | Fixed lending parameters can be conservative or restrictive | Low | Acknowledged |
| S-08 | Chainlink staleness uses block timestamp | Informational | Acknowledged |
| S-09 | ERC4626 behavior depends on OpenZeppelin implementation | Informational | Acknowledged |
| G-01 | Assembly sqrt benchmarked but not used by AMM | Gas | Acknowledged |

## Detailed Findings

### S-01: Deployer retained governance authority

Severity: High  
Location: `script/Deploy.s.sol`  
Description: The initial deploy script left the deployer as a Timelock proposer and GovToken owner. A compromised deployer could mint governance tokens or schedule timelock operations.  
Impact: Administrative backdoor after deployment.  
Recommendation: Transfer GovToken ownership to Timelock and revoke deployer Timelock proposer/admin roles.  
Status: Fixed. `Deploy.s.sol` now performs the transfers/revocations, and `VerifyDeployment.s.sol` checks the final state.

### S-02: Missing ERC721/ERC1155 token

Severity: Medium  
Location: token standards requirement  
Description: The first draft had ERC20 and ERC4626 but no ERC721 or ERC1155.  
Impact: Mandatory requirement failure.  
Recommendation: Add a meaningful NFT token.  
Status: Fixed. `ProtocolBadge` implements ERC721URIStorage and is Timelock-owned after deployment.

### S-03: Missing lending primitive

Severity: Medium  
Location: Option A scope  
Description: The README claimed a lending protocol, but the code only had AMM and vault.  
Impact: Scenario mismatch.  
Recommendation: Add lending pool with LTV, health factor, liquidation, and interest.  
Status: Fixed. `LendingPool` implements collateral deposit, borrow, repay, liquidate, value conversion, and linear interest.

### S-04: Proposal threshold mismatch

Severity: Medium  
Location: `DeFiGovernor.sol`  
Description: Proposal threshold was `1e18`, i.e. one DGT. Requirement is 1%.  
Impact: Proposal spam and requirement mismatch.  
Recommendation: Set threshold to 10,000 DGT, equal to 1% of initial supply.  
Status: Fixed.

### S-05: Subgraph ABI files missing

Severity: Medium  
Location: `subgraph/subgraph.yaml`  
Description: The subgraph referenced ABI files that did not exist.  
Impact: Subgraph build/codegen failure.  
Recommendation: Add ABI files and index Governor events.  
Status: Fixed.

### S-06: AMM sandwich risk

Severity: Low  
Location: `AMM.swap`  
Description: Like any simple constant-product AMM, swaps can be sandwiched.  
Impact: User receives worse execution.  
Recommendation: Keep `minAmountOut`; frontend must expose slippage protection.  
Status: Acknowledged. The frontend sends `minAmountOut`.

### S-07: Fixed lending parameters

Severity: Low  
Location: `LendingPool`  
Description: LTV, liquidation threshold, liquidation bonus, and interest rate are constants.  
Impact: The protocol cannot tune risk dynamically without redeploying.  
Recommendation: In production, governance could control bounded parameter updates.  
Status: Acknowledged for capstone simplicity.

### S-08: Timestamp in oracle staleness

Severity: Informational  
Location: `PriceFeed.getPrice`  
Description: `block.timestamp` is used only to reject stale oracle data.  
Impact: Minimal because threshold is one hour and timestamp manipulation is small.  
Recommendation: Accept as standard Chainlink practice.  
Status: Acknowledged.

### G-01: Assembly sqrt benchmark

Severity: Gas  
Location: `MathLib` and `AMM`  
Description: `MathLib` demonstrates Yul and benchmarks against Solidity, while AMM uses its own internal sqrt.  
Impact: Minor duplication.  
Recommendation: Keep as lecture requirement artifact; production AMM could import optimized math.  
Status: Acknowledged.

## CEI And Reentrancy Review

| Contract | External write functions | Protection |
|---|---|---|
| `AMM` | `addLiquidity`, `removeLiquidity`, `swap` | `nonReentrant`, CEI, SafeERC20 |
| `LendingPool` | `depositCollateral`, `withdrawCollateral`, `borrow`, `repay`, `liquidate` | `nonReentrant`, CEI, SafeERC20 |
| `YieldVault` | `depositYield`, `deposit`, `withdraw`, `redeem` | `nonReentrant`, SafeERC20 / ERC4626 |
| `TreasuryV1/V2` | `deposit`, `withdraw`, `pause`, `unpause` | manual lock, CEI, onlyOwner |
| `GovToken` | `mint` | onlyOwner |
| `ProtocolBadge` | `mintBadge` | onlyOwner |
| `AMMFactory` | `createPool`, `createPool2` | no external value transfer; input checks |

No production contract uses `tx.origin`, `transfer`, or `send`. ERC20 interactions use `SafeERC20`.

## Vulnerability Case Studies

### Reentrancy

Vulnerable pattern:

```solidity
IERC20(token).transfer(to, amount);
balances[token] -= amount;
```

Fixed pattern:

```solidity
balances[token] -= amount;
IERC20(token).safeTransfer(to, amount);
```

Tests: `test/security/VulnerabilityCaseStudies.t.sol` reproduces a reentrant ETH vault drain and verifies the fixed CEI version rejects the attack. `Treasury.t.sol`, AMM tests, LendingPool tests, and invariant accounting checks cover the production-style mitigations.

### Access Control

Vulnerable pattern:

```solidity
function withdraw(address token, address to, uint256 amount) external {
    IERC20(token).transfer(to, amount);
}
```

Fixed pattern:

```solidity
function withdraw(address token, address to, uint256 amount) external onlyOwner nonReentrant {
    ...
}
```

Tests: `test/security/VulnerabilityCaseStudies.t.sol` reproduces an unguarded sweep function and verifies the fixed `Ownable` version rejects a non-owner. Non-owner revert tests for Treasury, GovToken, YieldVault, and ProtocolBadge cover production authorization paths.

## Governance Attack Analysis

| Attack | Defense |
|---|---|
| Flash-loan voting | GovernorVotes snapshots voting power at proposal time; voting delay is 1 day |
| Whale takeover | 4% quorum, 1-week voting period, and Timelock delay |
| Proposal spam | 10,000 DGT threshold |
| Timelock bypass | Governor is proposer; deployer proposer/admin roles are revoked |
| Malicious upgrade | Upgrade must pass Governor -> Timelock -> Treasury owner path |

## Oracle Attack Analysis

| Attack | Defense |
|---|---|
| Stale price | `PriceFeed` reverts if update age exceeds threshold |
| Negative/zero price | `PriceFeed` reverts |
| Incomplete round | `answeredInRound >= roundId` and timestamp checks |
| Feed depeg | Lending uses separate collateral and debt feeds; deployer must choose correct feeds |
| Direct AMM manipulation | Lending does not use AMM spot price |

## Centralization Analysis

| Role | Holder after hardened deployment | Risk |
|---|---|---|
| Timelock admin | Timelock self-admin | Governance can schedule role changes after delay |
| Timelock proposer | Governor | Governance path controls sensitive operations |
| GovToken owner | Timelock | Governance can mint if proposal succeeds |
| Treasury owner | Timelock | Treasury withdrawals and upgrades delayed by 2 days |
| Badge owner | Timelock | Badge minting is governance-controlled |
| Vault owner | Timelock | Yield injection authority is governance-controlled |

## Slither Appendix

CI is configured to run `crytic/slither-action` against `src` and fail on Medium or higher. Local verification command:

```bash
slither src --fail-medium
```

Current status:

- Critical: 0
- High: 0
- Medium: 0
- Low/Informational: 20 emitted and accepted

Accepted low/informational detectors: `timestamp` for oracle staleness and linear interest accrual, `assembly` for the required benchmarked Yul routines and CREATE2 factory path, `missing-inheritance` for the local lending price-feed interface shape, `naming-convention` for an existing AMM parameter, `too-many-digits` for bytecode hashing in CREATE2 address prediction, and `unindexed-event-address` for inherited pause events.
