/**
 * Consensus - Functional approach to BFT consensus
 */

export interface SettlementProposal {
    poolId: string;
    winners: WinnerProposal[];
    proposerId: number;
    timestamp: number;
    hash: string;
}

export interface WinnerProposal {
    bidder: string;
    amount: bigint;
    allocation: number;
}

export interface Vote {
    operatorId: number;
    proposalHash: string;
    approve: boolean;
    timestamp: number;
}

export interface BidData {
    bidder: string;
    amount: bigint;
    timestamp: number;
}

export interface ThresholdSignature {
    proposalHash: string;
    signers: number[];
    signature: string;
    timestamp: number;
}

export interface ConsensusState {
    operatorId: number;
    totalOperators: number;
    threshold: number;
    pendingVotes: Map<string, Vote[]>;
}

/**
 * Create initial consensus state
 */
export const createConsensusState = (
    operatorId: number,
    totalOperators: number = 5,
    threshold: number = 3
): ConsensusState => ({
    operatorId,
    totalOperators,
    threshold,
    pendingVotes: new Map()
});

/**
 * Propose settlement for an auction
 */
export const proposeSettlement = (
    state: ConsensusState,
    poolId: string,
    winners: WinnerProposal[]
): SettlementProposal => {
    const proposal: SettlementProposal = {
        poolId,
        winners,
        proposerId: state.operatorId,
        timestamp: Date.now(),
        hash: hashProposal(poolId, winners)
    };
    
    console.log(`[Operator ${state.operatorId}] Proposing settlement for pool ${poolId}`);
    console.log(`Winners: ${winners.length}, Hash: ${proposal.hash}`);
    
    return proposal;
};

/**
 * Vote on a settlement proposal
 */
export const voteOnProposal = (
    state: ConsensusState,
    proposal: SettlementProposal,
    approve: boolean
): [ConsensusState, Vote] => {
    const vote: Vote = {
        operatorId: state.operatorId,
        proposalHash: proposal.hash,
        approve,
        timestamp: Date.now()
    };
    
    // Create new state with updated votes
    const votes = state.pendingVotes.get(proposal.hash) || [];
    const newVotes = [...votes, vote];
    const newPendingVotes = new Map(state.pendingVotes);
    newPendingVotes.set(proposal.hash, newVotes);
    
    const newState: ConsensusState = {
        ...state,
        pendingVotes: newPendingVotes
    };
    
    console.log(`[Operator ${state.operatorId}] Voted ${approve ? 'YES' : 'NO'} on proposal ${proposal.hash}`);
    
    return [newState, vote];
};

/**
 * Check if proposal has reached consensus
 */
export const hasReachedConsensus = (
    state: ConsensusState,
    proposalHash: string
): boolean => {
    const votes = state.pendingVotes.get(proposalHash) || [];
    
    if (votes.length < state.threshold) {
        return false;
    }
    
    const approvals = votes.filter(v => v.approve).length;
    const hasConsensus = approvals >= state.threshold;
    
    if (hasConsensus) {
        console.log(`Consensus reached for ${proposalHash}: ${approvals}/${votes.length} approvals`);
    }
    
    return hasConsensus;
};

/**
 * Get votes for a proposal
 */
export const getVotes = (
    state: ConsensusState,
    proposalHash: string
): Vote[] => state.pendingVotes.get(proposalHash) || [];

/**
 * Verify proposal matches expected data
 */
export const verifyProposal = (
    proposal: SettlementProposal,
    expectedWinners: WinnerProposal[]
): boolean => {
    // Verify winner count matches
    if (proposal.winners.length !== expectedWinners.length) {
        console.log('Winner count mismatch');
        return false;
    }
    
    // Verify each winner
    const winnersMatch = proposal.winners.every((proposed, i) => {
        const expected = expectedWinners[i];
        return proposed.bidder === expected.bidder &&
               proposed.amount === expected.amount &&
               proposed.allocation === expected.allocation;
    });
    
    if (!winnersMatch) {
        console.log('Winners mismatch');
        return false;
    }
    
    // Verify hash
    const expectedHash = hashProposal(proposal.poolId, expectedWinners);
    if (proposal.hash !== expectedHash) {
        console.log('Hash mismatch');
        return false;
    }
    
    return true;
};

/**
 * Rank bids to determine winners
 */
export const rankBids = (
    bids: BidData[],
    maxWinners: number
): WinnerProposal[] => {
    // Sort bids by amount (descending), then by timestamp (ascending)
    const sortedBids = [...bids].sort((a, b) => {
        if (b.amount > a.amount) return 1;
        if (b.amount < a.amount) return -1;
        return a.timestamp - b.timestamp;
    });
    
    // Select top N winners
    const topBids = sortedBids.slice(0, Math.min(maxWinners, sortedBids.length));
    
    // Calculate total bid amount
    const totalAmount = topBids.reduce((sum, bid) => sum + bid.amount, BigInt(0));
    
    // Allocate proportionally
    const winners: WinnerProposal[] = topBids.map(bid => ({
        bidder: bid.bidder,
        amount: bid.amount,
        allocation: totalAmount > BigInt(0)
            ? Number((bid.amount * BigInt(10000)) / totalAmount)
            : 0
    }));
    
    console.log(`Ranked ${bids.length} bids, selected ${winners.length} winners`);
    return winners;
};

/**
 * Create threshold signature for settlement
 */
export const createThresholdSignature = (
    state: ConsensusState,
    proposalHash: string,
    votes: Vote[]
): ThresholdSignature => {
    if (votes.length < state.threshold) {
        throw new Error('Insufficient votes for threshold signature');
    }
    
    return {
        proposalHash,
        signers: votes.map(v => v.operatorId),
        signature: simulateSignature(proposalHash, votes),
        timestamp: Date.now()
    };
};

/**
 * Verify threshold signature
 */
export const verifyThresholdSignature = (
    state: ConsensusState,
    signature: ThresholdSignature
): boolean => {
    // Verify sufficient signers
    if (signature.signers.length < state.threshold) {
        return false;
    }
    
    // Verify no duplicate signers
    const uniqueSigners = new Set(signature.signers);
    if (uniqueSigners.size !== signature.signers.length) {
        return false;
    }
    
    return true;
};

// ============ Helper Functions ============

const hashProposal = (poolId: string, winners: WinnerProposal[]): string => {
    const data = JSON.stringify({ poolId, winners });
    let hash = 0;
    for (let i = 0; i < data.length; i++) {
        hash = ((hash << 5) - hash) + data.charCodeAt(i);
        hash = hash & hash;
    }
    return `0x${Math.abs(hash).toString(16).padStart(64, '0')}`;
};

const simulateSignature = (proposalHash: string, votes: Vote[]): string => {
    const signerIds = votes.map(v => v.operatorId).join(',');
    return `sig_${proposalHash}_${signerIds}`;
};
