# DeFi Super-App — Blockchain Technologies 2 Final Project

## Overview
A production-grade decentralized protocol implementing an AMM + Lending Protocol + Tokenized Yield Vault, governed by a DAO, deployed on Arbitrum Sepolia.

## Team
- Member 1: Smart Contracts (AMM, Vault, Governance)
- Member 2: Testing, Frontend, Deployment

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Verified |
|----------|---------|---------|
| GovToken | [0x518f029A4E7BE8B9CE5bDd7188E80eA71B404b63](https://sepolia.arbiscan.io/address/0x518f029A4E7BE8B9CE5bDd7188E80eA71B404b63) | ✅ |
| Timelock | [0x3a56Af5D7F6c768A052a348840bBe182C139Cbf7](https://sepolia.arbiscan.io/address/0x3a56Af5D7F6c768A052a348840bBe182C139Cbf7) | ✅ |
| Governor | [0x7309A96DE45c3e1f70b59c4FE205786Bf50DE8ac](https://sepolia.arbiscan.io/address/0x7309A96DE45c3e1f70b59c4FE205786Bf50DE8ac) | ✅ |
| Treasury (Proxy) | [0xfcf24222be9a73de841F4Fd93460361439CF38Fa](https://sepolia.arbiscan.io/address/0xfcf24222be9a73de841F4Fd93460361439CF38Fa) | ✅ |
| AMMFactory | [0x01128Fd657aa77A08E5FDc0FB36BA9C8669438b5](https://sepolia.arbiscan.io/address/0x01128Fd657aa77A08E5FDc0FB36BA9C8669438b5) | ✅ |
| WETH/USDC Pool | [0x8F5856FF91503BcE897712952D9152cd424EFB24](https://sepolia.arbiscan.io/address/0x8F5856FF91503BcE897712952D9152cd424EFB24) | ✅ |
| YieldVault | [0x207Cb0DD0567f8F861b4F16785fc9034E1e2CF9F](https://sepolia.arbiscan.io/address/0x207Cb0DD0567f8F861b4F16785fc9034E1e2CF9F) | ✅ |
| PriceFeed | [0xF692D60C6F99Cff9012EA9794A72dfb98F66B27F](https://sepolia.arbiscan.io/address/0xF692D60C6F99Cff9012EA9794A72dfb98F66B27F) | ✅ |
| MathLib | [0xF9B7f7Eeeb159061a2C0C4B1a3F7033d150187ad](https://sepolia.arbiscan.io/address/0xF9B7f7Eeeb159061a2C0C4B1a3F7033d150187ad) | ✅ |

## Architecture

### Smart Contracts
- GovToken — ERC20Votes + ERC20Permit governance token
- DeFiTimelock — 2-day delay TimelockController
- DeFiGovernor — OpenZeppelin Governor (1 day voting delay, 1 week period, 4% quorum)
- AMM — Constant product AMM (x*y=k) with 0.3% fee, LP tokens
- YieldVault — ERC-4626 tokenized yield vault
- TreasuryV1/V2 — UUPS upgradeable treasury (V1→V2 upgrade path demonstrated)
- AMMFactory — Factory using CREATE and CREATE2
- PriceFeed — Chainlink oracle adapter with staleness check
- MathLib — Yul assembly math utilities

### Design Patterns Used
1. Factory (AMMFactory — CREATE and CREATE2)
2. Proxy / UUPS (TreasuryV1 → TreasuryV2)
3. Checks-Effects-Interactions (AMM, YieldVault, Treasury)
4. Access Control / Role-based (OpenZeppelin Ownable, AccessControl)
5. Timelock (DeFiTimelock — 2-day governance delay)
6. Reentrancy Guard (AMM, YieldVault)
7. Oracle adapter (PriceFeed — Chainlink abstraction)

## Testing

forge test


- 88 tests total: 56 unit, 10 fuzz, 5 invariant, 3 fork
- Coverage: run forge coverage
- All tests pass in CI

## Deployment

cp .env.example .env
# Fill in PRIVATE_KEY and ARBITRUM_SEPOLIA_RPC
source .env
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast


## Frontend

cd frontend
npm install
npm run dev


Open http://localhost:5173

## CI
GitHub Actions runs on every push: compile → test → coverage → format check.

## Gas Comparison (L1 vs L2)

| Operation | L1 Ethereum (est.) | Arbitrum Sepolia |
|-----------|-------------------|-----------------|
| Deploy GovToken | ~$15-20 | $0.00078 |
| Deploy AMM | ~$25-30 | $0.00046 |
| Swap | ~$5-10 | $0.00002 |
| Add Liquidity | ~$8-12 | $0.00004 |
| Deposit Vault | ~$3-5 | $0.00002 |
| Transfer Token | ~$1-2 | $0.000005 |