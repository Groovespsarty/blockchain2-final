import { BigInt } from "@graphprotocol/graph-ts";
import {
  ProposalCreated as ProposalCreatedEvent,
  ProposalQueued as ProposalQueuedEvent,
  ProposalExecuted as ProposalExecutedEvent,
  ProposalCanceled as ProposalCanceledEvent,
  VoteCast as VoteCastEvent,
} from "../generated/Governor/Governor";
import { Proposal, VoteCast } from "../generated/schema";

export function handleProposalCreated(event: ProposalCreatedEvent): void {
  let proposal = new Proposal(event.params.proposalId.toString());
  proposal.proposer = event.params.proposer;
  proposal.description = event.params.description;
  proposal.voteStart = event.params.voteStart;
  proposal.voteEnd = event.params.voteEnd;
  proposal.state = "Pending";
  proposal.createdAt = event.block.timestamp;
  proposal.queuedAt = null;
  proposal.executedAt = null;
  proposal.canceledAt = null;
  proposal.save();
}

export function handleVoteCast(event: VoteCastEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let vote = new VoteCast(id);
  vote.proposal = event.params.proposalId.toString();
  vote.voter = event.params.voter;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.timestamp = event.block.timestamp;
  vote.blockNumber = event.block.number;
  vote.save();
}

export function handleProposalQueued(event: ProposalQueuedEvent): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (!proposal) return;
  proposal.state = "Queued";
  proposal.queuedAt = event.params.etaSeconds;
  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecutedEvent): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (!proposal) return;
  proposal.state = "Executed";
  proposal.executedAt = event.block.timestamp;
  proposal.save();
}

export function handleProposalCanceled(event: ProposalCanceledEvent): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (!proposal) return;
  proposal.state = "Canceled";
  proposal.canceledAt = event.block.timestamp;
  proposal.save();
}
