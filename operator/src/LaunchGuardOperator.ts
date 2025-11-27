import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import * as FHEDecryptor from './FHEDecryptor';
import * as Consensus from './Consensus';
import * as ReputationMonitor from './ReputationMonitor';

dotenv.config();

/**
 * LaunchGuardOperator - Functional approach to EigenLayer AVS operator
 */

export interface OperatorConfig {
    rpcUrl: string;
    privateKey: string;
    operatorId: number;
    contractAddresses: {
        launchGuard: string;
        auction: string;
        reputation: string;
    };
}

export interface OperatorState {
    config: OperatorConfig;
    provider: ethers.Provider;
    wallet: ethers.Wallet;
    contracts: {
        launchGuard: ethers.Contract;
        auction: ethers.Contract;
        reputation: ethers.Contract;
    };
    decryptor: FHEDecryptor.DecryptorConfig;
    consensus: Consensus.ConsensusState;
    reputation: ReputationMonitor.ReputationState;
    isRunning: boolean;
}

/**
 * Create operator configuration
 */
export const createOperatorConfig = (
    rpcUrl: string,
    privateKey: string,
    operatorId: number,
    contractAddresses: {
        launchGuard: string;
        auction: string;
        reputation: string;
    }
): OperatorConfig => ({
    rpcUrl,
    privateKey,
    operatorId,
    contractAddresses
});

/**
 * Initialize operator state
 */
export const initializeOperator = (config: OperatorConfig): OperatorState => {
    const provider = new ethers.JsonRpcProvider(config.rpcUrl);
    const wallet = new ethers.Wallet(config.privateKey, provider);
    
    const launchGuardABI = getLaunchGuardABI();
    const auctionABI = getAuctionABI();
    const reputationABI = getReputationABI();
    
    const contracts = {
        launchGuard: new ethers.Contract(
            config.contractAddresses.launchGuard,
            launchGuardABI,
            wallet
        ),
        auction: new ethers.Contract(
            config.contractAddresses.auction,
            auctionABI,
            wallet
        ),
        reputation: new ethers.Contract(
            config.contractAddresses.reputation,
            reputationABI,
            wallet
        )
    };
    
    const decryptor = FHEDecryptor.createDecryptor(provider, config.operatorId);
    const consensus = Consensus.createConsensusState(config.operatorId);
    const reputation = ReputationMonitor.createReputationState(config.operatorId);
    
    console.log(`LaunchGuard Operator ${config.operatorId} initialized`);
    console.log(`Wallet: ${wallet.address}`);
    
    return {
        config,
        provider,
        wallet,
        contracts,
        decryptor,
        consensus,
        reputation,
        isRunning: false
    };
};

/**
 * Set up event listeners
 */
export const setupEventListeners = (
    state: OperatorState,
    handlers: {
        onAuctionCreated: (poolId: string, endTime: bigint) => Promise<void>;
        onBidSubmitted: (poolId: string, bidder: string) => Promise<void>;
        onAuctionSettled: (poolId: string, totalBids: number, winnersCount: number) => void;
    }
): OperatorState => {
    state.contracts.auction.on('AuctionCreated', async (poolId, endTime, ...args) => {
        console.log(`New auction created for pool ${poolId}`);
        await handlers.onAuctionCreated(poolId, endTime);
    });
    
    state.contracts.auction.on('BidSubmitted', async (poolId, bidder, timestamp) => {
        console.log(`New bid from ${bidder} for pool ${poolId}`);
        await handlers.onBidSubmitted(poolId, bidder);
    });
    
    state.contracts.launchGuard.on('AuctionSettled', async (poolId, totalBids, winnersCount) => {
        console.log(`Auction settled for pool ${poolId}: ${winnersCount} winners`);
        handlers.onAuctionSettled(poolId, totalBids, winnersCount);
    });
    
    return state;
};

/**
 * Handle auction creation
 */
export const handleAuctionCreated = async (
    state: OperatorState,
    poolId: string,
    endTime: bigint
): Promise<void> => {
    console.log(`Monitoring auction ${poolId} until ${new Date(Number(endTime) * 1000)}`);
    
    const now = Math.floor(Date.now() / 1000);
    const timeUntilEnd = Number(endTime) - now;
    
    if (timeUntilEnd > 0) {
        setTimeout(() => {
            initiateSettlement(state, poolId);
        }, timeUntilEnd * 1000 + 5000);
    }
};

/**
 * Handle bid submission
 */
export const handleBidSubmitted = async (
    state: OperatorState,
    poolId: string,
    bidder: string
): Promise<OperatorState> => {
    const analysis = ReputationMonitor.analyzeUser(state.reputation, bidder);
    
    if (analysis.shouldBlacklist) {
        console.log(`⚠️  Recommending blacklist for ${bidder}`);
    }
    
    const newReputation = ReputationMonitor.recordActivity(
        state.reputation,
        bidder,
        {
            type: 'bid',
            timestamp: Date.now()
        }
    );
    
    return {
        ...state,
        reputation: newReputation
    };
};

/**
 * Initiate settlement for an auction
 */
export const initiateSettlement = async (
    state: OperatorState,
    poolId: string
): Promise<OperatorState> => {
    console.log(`\n🎯 Initiating settlement for pool ${poolId}`);
    
    try {
        // Step 1: Get all bids
        const bids = await getBidsForPool(state, poolId);
        console.log(`Found ${bids.length} bids`);
        
        // Step 2: Decrypt bids
        const decryptedBids = await decryptBids(state, poolId, bids);
        console.log(`Decrypted ${decryptedBids.length} bids`);
        
        // Step 3: Rank bids and select winners
        const auctionConfig = await getAuctionConfig(state, poolId);
        const winners = Consensus.rankBids(decryptedBids, auctionConfig.maxWinners);
        console.log(`Selected ${winners.length} winners`);
        
        // Step 4: Propose settlement
        const proposal = Consensus.proposeSettlement(state.consensus, poolId, winners);
        
        // Step 5: Vote on proposal
        const [newConsensus, vote] = Consensus.voteOnProposal(state.consensus, proposal, true);
        
        // Step 6: Check consensus
        console.log('Waiting for consensus from other operators...');
        await sleep(5000);
        
        const newState = { ...state, consensus: newConsensus };
        
        // Step 7: Submit if consensus reached
        if (Consensus.hasReachedConsensus(newConsensus, proposal.hash)) {
            await submitSettlement(newState, poolId, winners);
            console.log('✅ Settlement submitted successfully');
        } else {
            console.log('❌ Consensus not reached');
        }
        
        return newState;
    } catch (error) {
        console.error('Settlement failed:', error);
        return state;
    }
};

/**
 * Decrypt bids using threshold FHE
 */
export const decryptBids = async (
    state: OperatorState,
    poolId: string,
    bids: { bidder: string; encryptedAmount: bigint; timestamp: number }[]
): Promise<Consensus.BidData[]> => {
    const decryptPromises = bids.map(async (bid) => {
        try {
            const share = await FHEDecryptor.generateDecryptionShare(
                state.decryptor,
                bid.encryptedAmount,
                poolId
            );
            
            const shares = [share]; // In production: collect from other operators
            const decryptedAmount = await FHEDecryptor.combineShares(state.decryptor, shares);
            
            if (decryptedAmount !== null) {
                return {
                    bidder: bid.bidder,
                    amount: decryptedAmount,
                    timestamp: bid.timestamp
                };
            }
            return null;
        } catch (error) {
            console.error(`Failed to decrypt bid from ${bid.bidder}:`, error);
            return null;
        }
    });
    
    const results = await Promise.all(decryptPromises);
    return results.filter((bid): bid is Consensus.BidData => bid !== null);
};

/**
 * Submit settlement transaction
 */
export const submitSettlement = async (
    state: OperatorState,
    poolId: string,
    winners: Consensus.WinnerProposal[]
): Promise<void> => {
    console.log(`Submitting settlement for pool ${poolId}...`);
    
    const winnersArray = winners.map(w => ({
        bidder: w.bidder,
        amount: w.amount,
        allocation: w.allocation
    }));
    
    console.log('Settlement data:', { poolId, winners: winnersArray });
    
    // In production: Submit actual transaction
    // const tx = await state.contracts.launchGuard.settleAuction(poolId, winnersArray);
    // await tx.wait();
};

/**
 * Update reputation scores
 */
export const updateReputationScores = (state: OperatorState): void => {
    const blacklistRecs = ReputationMonitor.getBlacklistRecommendations(state.reputation);
    if (blacklistRecs.length > 0) {
        console.log(`Blacklist recommendations: ${blacklistRecs.length} addresses`);
    }
    
    const whitelistRecs = ReputationMonitor.getWhitelistRecommendations(state.reputation);
    if (whitelistRecs.length > 0) {
        console.log(`Whitelist recommendations: ${whitelistRecs.length} addresses`);
    }
};

/**
 * Main monitoring loop
 */
export const monitoringLoop = async (
    state: OperatorState,
    checkPendingAuctions: (state: OperatorState) => Promise<void>
): Promise<void> => {
    while (state.isRunning) {
        try {
            await checkPendingAuctions(state);
            updateReputationScores(state);
            await sleep(30000); // 30 seconds
        } catch (error) {
            console.error('Error in monitoring loop:', error);
            await sleep(5000);
        }
    }
};

/**
 * Start the operator
 */
export const startOperator = async (state: OperatorState): Promise<OperatorState> => {
    console.log(`Starting operator ${state.config.operatorId}...`);
    
    const runningState = { ...state, isRunning: true };
    
    const handlers = {
        onAuctionCreated: (poolId: string, endTime: bigint) => 
            handleAuctionCreated(runningState, poolId, endTime),
        onBidSubmitted: async (poolId: string, bidder: string) => {
            const newState = await handleBidSubmitted(runningState, poolId, bidder);
            Object.assign(runningState, newState);
        },
        onAuctionSettled: (poolId: string, totalBids: number, winnersCount: number) => {
            console.log(`Auction ${poolId} settled`);
        }
    };
    
    setupEventListeners(runningState, handlers);
    
    // Start monitoring loop
    monitoringLoop(runningState, async (s) => {
        // Check pending auctions
    });
    
    console.log(`Operator ${state.config.operatorId} is running`);
    return runningState;
};

/**
 * Stop the operator
 */
export const stopOperator = (state: OperatorState): OperatorState => {
    console.log(`Stopping operator ${state.config.operatorId}...`);
    
    state.contracts.launchGuard.removeAllListeners();
    state.contracts.auction.removeAllListeners();
    
    console.log(`Operator ${state.config.operatorId} stopped`);
    
    return { ...state, isRunning: false };
};

// ============ Helper Functions ============

const getBidsForPool = async (state: OperatorState, poolId: string): Promise<any[]> => {
    // In production: Query contract for bids
    return [];
};

const getAuctionConfig = async (state: OperatorState, poolId: string): Promise<any> => {
    // In production: Query contract
    return { maxWinners: 10 };
};

const sleep = (ms: number): Promise<void> => 
    new Promise(resolve => setTimeout(resolve, ms));

const getLaunchGuardABI = (): any[] => [
    'event AuctionCreated(bytes32 indexed poolId, uint256 auctionEndTime, uint256 priorityWindowDuration, uint256 minBidAmount, uint256 maxWinners)',
    'event AuctionSettled(bytes32 indexed poolId, uint256 totalBids, uint256 winnersCount)',
    'function settleAuction(bytes32 poolId, tuple(address bidder, uint256 amount, uint256 allocation)[] winners)'
];

const getAuctionABI = (): any[] => [
    'event AuctionCreated(bytes32 indexed poolId, uint256 auctionEndTime, uint256 priorityWindowDuration, uint256 minBidAmount, uint256 maxWinners)',
    'event BidSubmitted(bytes32 indexed poolId, address indexed bidder, uint256 timestamp)'
];

const getReputationABI = (): any[] => [
    'function blacklist(address user, string reason)',
    'function addCommunityMember(address user)'
];

// ============ Main Entry Point ============

const main = async () => {
    const config = createOperatorConfig(
        process.env.RPC_URL || 'http://localhost:8545',
        process.env.PRIVATE_KEY || '',
        parseInt(process.env.OPERATOR_ID || '0'),
        {
            launchGuard: process.env.LAUNCHGUARD_ADDRESS || '',
            auction: process.env.AUCTION_ADDRESS || '',
            reputation: process.env.REPUTATION_ADDRESS || ''
        }
    );
    
    let state = initializeOperator(config);
    state = await startOperator(state);
    
    // Handle graceful shutdown
    process.on('SIGINT', () => {
        console.log('\nShutting down...');
        state = stopOperator(state);
        process.exit(0);
    });
};

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

export {
    initializeOperator,
    startOperator,
    stopOperator,
    handleAuctionCreated,
    handleBidSubmitted,
    initiateSettlement
};
