import { BigInt } from "@graphprotocol/graph-ts";
import {
  Swap as SwapEvent,
  LiquidityAdded as LiquidityAddedEvent,
  LiquidityRemoved as LiquidityRemovedEvent,
} from "../generated/AMM/AMM";
import { Swap, LiquidityAdd, LiquidityRemove, Pool } from "../generated/schema";

function getPool(): Pool {
  let pool = Pool.load("main");
  if (!pool) {
    pool = new Pool("main");
    pool.totalSwaps = BigInt.fromI32(0);
    pool.totalVolumeA = BigInt.fromI32(0);
    pool.totalVolumeB = BigInt.fromI32(0);
    pool.lastUpdated = BigInt.fromI32(0);
  }
  return pool;
}

export function handleSwap(event: SwapEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let swap = new Swap(id);
  swap.user = event.params.user;
  swap.tokenIn = event.params.tokenIn;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.timestamp = event.block.timestamp;
  swap.blockNumber = event.block.number;
  swap.save();

  let pool = getPool();
  pool.totalSwaps = pool.totalSwaps.plus(BigInt.fromI32(1));
  pool.totalVolumeA = pool.totalVolumeA.plus(event.params.amountIn);
  pool.lastUpdated = event.block.timestamp;
  pool.save();
}

export function handleLiquidityAdded(event: LiquidityAddedEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let liq = new LiquidityAdd(id);
  liq.provider = event.params.provider;
  liq.amountA = event.params.amountA;
  liq.amountB = event.params.amountB;
  liq.shares = event.params.shares;
  liq.timestamp = event.block.timestamp;
  liq.blockNumber = event.block.number;
  liq.save();
}

export function handleLiquidityRemoved(event: LiquidityRemovedEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let liq = new LiquidityRemove(id);
  liq.provider = event.params.provider;
  liq.amountA = event.params.amountA;
  liq.amountB = event.params.amountB;
  liq.shares = event.params.shares;
  liq.timestamp = event.block.timestamp;
  liq.blockNumber = event.block.number;
  liq.save();
}