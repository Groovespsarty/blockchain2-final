# Documented GraphQL Queries

## 1. Latest swaps

```graphql
query LatestSwaps {
  swaps(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    user
    tokenIn
    amountIn
    amountOut
    timestamp
  }
}
```

## 2. Liquidity added by provider

```graphql
query LiquidityByProvider($provider: Bytes!) {
  liquidityAdds(where: { provider: $provider }, orderBy: timestamp, orderDirection: desc) {
    id
    amountA
    amountB
    shares
    timestamp
  }
}
```

## 3. Pool aggregate metrics

```graphql
query PoolMetrics {
  pools {
    id
    totalSwaps
    totalVolumeA
    totalVolumeB
    lastUpdated
  }
}
```

## 4. Active governance proposals

```graphql
query GovernanceProposals {
  proposals(orderBy: createdAt, orderDirection: desc) {
    id
    proposer
    description
    voteStart
    voteEnd
    state
  }
}
```

## 5. Votes for a proposal

```graphql
query ProposalVotes($proposal: ID!) {
  voteCasts(where: { proposal: $proposal }, orderBy: timestamp, orderDirection: desc) {
    id
    voter
    support
    weight
    reason
    timestamp
  }
}
```
