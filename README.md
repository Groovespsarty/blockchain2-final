# DeFi Super-App - Blockchain Technologies 2 Final Project

Full-stack decentralized protocol for the Blockchain Technologies 2 capstone. The project implements Option A: an AMM, lending pool, ERC-4626 yield vault, Chainlink oracle integration, DAO governance, The Graph indexing, and an Arbitrum Sepolia deployment path.

## Team

- Tulegenov Alimzhan: smart contracts, AMM, vault, governance, oracles
- Askhat Amirkhanov: testing, frontend, deployment, documentation

## Protocol Components

| Component | Contract / Artifact |
|---|---|
| Governance token | `src/tokens/GovToken.sol` - ERC20Votes + ERC20Permit |
| NFT standard | `src/tokens/ProtocolBadge.sol` - ERC721 badge token |
| AMM | `src/core/AMM.sol` - x*y=k pool, 0.3% fee, slippage protection, LP token |
| Lending | `src/core/LendingPool.sol` - collateral, borrow, repay, health factor, liquidation, linear interest |
| Vault | `src/core/YieldVault.sol` - ERC4626 tokenized yield vault |
| Upgradeability | `src/core/TreasuryV1.sol` -> `src/core/TreasuryV2.sol` via UUPS proxy |
| Factory | `src/factories/AMMFactory.sol` - CREATE and CREATE2 deployment |
| Oracle | `src/oracles/PriceFeed.sol` - Chainlink adapter with staleness checks |
| Governance | `DeFiGovernor` + `DeFiTimelock`, 2-day timelock delay |
| Indexing | `subgraph/` - AMM, token, and Governor event indexing |
| Frontend | `frontend/` - MetaMask dApp with AMM, vault, and governance actions |

## Governance Parameters

- Voting delay: 1 day
- Voting period: 1 week
- Quorum: 4%
- Proposal threshold: 10,000 DGT, equal to 1% of the initial 1,000,000 DGT supply
- Timelock delay: 2 days
- Treasury owner after deployment: Timelock
- GovToken owner after deployment: Timelock

## Tests

```bash
$env:MAINNET_RPC_URL="https://ethereum-rpc.publicnode.com"
C:\Users\Alimzhan\.foundry\bin\forge.exe test
```

Latest local result:

- 129 tests passed
- Unit-style tests: 101
- Fuzz tests: 13
- Invariant tests: 7
- Fork tests: 4
- Security case-study tests: 4

Coverage report: `docs/coverage-report.md`.

## Deployment

```bash
cp .env.example .env
# Fill PRIVATE_KEY, ARBITRUM_SEPOLIA_RPC, ARBISCAN_API_KEY, CHAINLINK_USDC_USD
forge script script/Deploy.s.sol \
  --rpc-url $ARBITRUM_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

Post-deployment verification:

```bash
forge script script/VerifyDeployment.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC
```

The repository contains a previous Arbitrum Sepolia deployment in `deployments/arbitrum-sepolia.json`. Because the current implementation adds `LendingPool`, `ProtocolBadge`, and a hardened governance deployment path, a fresh deployment is required before final submission addresses are considered current.

## Frontend

```bash
cd frontend
npm install
npm run dev
```

Optional `.env.local` values:

```bash
VITE_SUBGRAPH_URL=https://api.studio.thegraph.com/query/your-subgraph
VITE_GOV_TOKEN=0x...
VITE_GOVERNOR=0x...
VITE_AMM=0x...
VITE_YIELD_VAULT=0x...
VITE_WETH=0x...
VITE_USDC=0x...
```

Frontend capabilities:

- MetaMask connection and Arbitrum Sepolia network detection
- DGT balance, voting power, delegate address
- AMM reserves and wallet balances
- Vault shares and total assets
- State-changing actions: delegate, transfer, swap, add liquidity, deposit, vote
- Proposal list and indexed swaps loaded from The Graph when `VITE_SUBGRAPH_URL` is set
- Readable errors for rejected transactions, wrong network, and insufficient balances

## Subgraph

```bash
cd subgraph
npm install
npm run codegen
npm run build
```

The subgraph indexes:

- `Swap`
- `LiquidityAdd`
- `LiquidityRemove`
- `Pool`
- `TokenTransfer`
- `DelegateChanged`
- `Proposal`
- `VoteCast`

Documented GraphQL queries are in `subgraph/queries.md`.

## CI

GitHub Actions runs on push and pull request:

- Foundry build
- Foundry tests
- Forge coverage
- `forge fmt --check`
- Solhint
- Slither, failing on Medium or higher
- Frontend `npm ci`, ESLint, Prettier, and Vite build

## Documentation

- Architecture: `docs/architecture.md`
- Security audit: `docs/audit.md`
- Coverage: `docs/coverage-report.md`
- Gas optimization: `docs/gas-optimization.md`
- Final presentation: `docs/final-presentation.pdf`
