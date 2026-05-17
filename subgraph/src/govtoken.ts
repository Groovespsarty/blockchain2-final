import {
  Transfer as TransferEvent,
  DelegateChanged as DelegateChangedEvent,
} from "../generated/GovToken/GovToken";
import { TokenTransfer, DelegateChanged } from "../generated/schema";

export function handleTransfer(event: TransferEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let transfer = new TokenTransfer(id);
  transfer.from = event.params.from;
  transfer.to = event.params.to;
  transfer.amount = event.params.value;
  transfer.timestamp = event.block.timestamp;
  transfer.blockNumber = event.block.number;
  transfer.save();
}

export function handleDelegateChanged(event: DelegateChangedEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let del = new DelegateChanged(id);
  del.delegator = event.params.delegator;
  del.fromDelegate = event.params.fromDelegate;
  del.toDelegate = event.params.toDelegate;
  del.timestamp = event.block.timestamp;
  del.blockNumber = event.block.number;
  del.save();
}