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
    stakeAmount: bigint; // Amount to stake when registering as operator
    contractAddresses: {
        serviceManager: string; // LaunchGuardServiceManager (AVS)
        auction: string; // EncryptedAuction
        reputation: string; // ReputationRegistry
    };
}

export interface OperatorState {
    config: OperatorConfig;
    provider: ethers.Provider;
    wallet: ethers.Wallet;
    contracts: {
        serviceManager: ethers.Contract; // LaunchGuardServiceManager
        auction: ethers.Contract; // EncryptedAuction
        reputation: ethers.Contract; // ReputationRegistry
    };
    decryptor: FHEDecryptor.DecryptorConfig;
    consensus: Consensus.ConsensusState;
    reputation: ReputationMonitor.ReputationState;
    isRegistered: boolean; // Whether operator is registered with AVS
    isRunning: boolean;
}

/**
 * Create operator configuration
 */
export const createOperatorConfig = (
    rpcUrl: string,
    privateKey: string,
    operatorId: number,
    stakeAmount: bigint,
    contractAddresses: {
        serviceManager: string;
        auction: string;
        reputation: string;
    }
): OperatorConfig => ({
    rpcUrl,
    privateKey,
    operatorId,
    stakeAmount,
    contractAddresses
});

/**
 * Initialize operator state
 */
export const initializeOperator = (config: OperatorConfig): OperatorState => {
    const provider = new ethers.JsonRpcProvider(config.rpcUrl);
    const wallet = new ethers.Wallet(config.privateKey, provider);

    const serviceManagerABI = getServiceManagerABI();
    const auctionABI = getAuctionABI();
    const reputationABI = getReputationABI();

    const contracts = {
        serviceManager: new ethers.Contract(
            config.contractAddresses.serviceManager,
            serviceManagerABI,
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

    console.log(`LaunchGuard AVS Operator ${config.operatorId} initialized`);
    console.log(`Wallet: ${wallet.address}`);

    return {
        config,
        provider,
        wallet,
        contracts,
        decryptor,
        consensus,
        reputation,
        isRegistered: false,
        isRunning: false
    };
};

/**
 * Register operator with AVS
 */
export const registerOperator = async (state: OperatorState): Promise<OperatorState> => {
    console.log(`Registering operator with stake: ${ethers.formatEther(state.config.stakeAmount)} ETH`);

    try {
        // Check if already registered
        const isOperator = await state.contracts.serviceManager.isOperator(state.wallet.address);
        if (isOperator) {
            console.log('✅ Already registered as operator');
            return { ...state, isRegistered: true };
        }

        // Register with stake
        const tx = await state.contracts.serviceManager.registerOperator({
            value: state.config.stakeAmount
        });

        console.log(`Registration transaction: ${tx.hash}`);
        await tx.wait();

        console.log('✅ Successfully registered as AVS operator');
        return { ...state, isRegistered: true };
    } catch (error) {
        console.error('❌ Failed to register operator:', error);
        throw error;
    }
};

/**
 * Set up event listeners for AVS tasks
 */
export const setupEventListeners = (
    state: OperatorState,
    handlers: {
        onTaskCreated: (taskId: number, poolId: string, totalBidders: number) => Promise<void>;
        onBidSubmitted: (poolId: string, bidder: string) => Promise<void>;
        onAuctionSettled: (poolId: string, totalBids: number, winnersCount: number) => void;
    }
): OperatorState => {
    // Listen for AVS task creation
    state.contracts.serviceManager.on('TaskCreated', async (taskId, poolId, totalBidders) => {
        console.log(`\n🎯 New AVS Task #${taskId} created for pool ${poolId}`);
        console.log(`Total bidders: ${totalBidders}`);
        await handlers.onTaskCreated(taskId, poolId, totalBidders);
    });

    // Listen for bid submissions
    state.contracts.auction.on('BidSubmitted', async (poolId, bidder, timestamp) => {
        console.log(`New bid from ${bidder} for pool ${poolId}`);
        await handlers.onBidSubmitted(poolId, bidder);
    });

    // Listen for auction settlements
    state.contracts.auction.on('AuctionSettled', async (poolId, totalBids, winnersCount) => {
        console.log(`✅ Auction settled for pool ${poolId}: ${winnersCount} winners`);
        handlers.onAuctionSettled(poolId, totalBids, winnersCount);
    });

    return state;
};

/**
 * Handle AVS task creation
 */
export const handleTaskCreated = async (
    state: OperatorState,
    taskId: number,
    poolId: string,
    totalBidders: number
): Promise<void> => {
    console.log(`\n📋 Processing AVS Task #${taskId}`);
    console.log(`Pool: ${poolId}`);
    console.log(`Total bidders: ${totalBidders}`);

    try {
        // Step 1: Get all bids for this pool
        const bids = await getBidsForPool(state, poolId);
        console.log(`Retrieved ${bids.length} encrypted bids`);

        // Step 2: Decrypt bids using threshold FHE
        const decryptedBids = await decryptBids(state, poolId, bids);
        console.log(`Decrypted ${decryptedBids.length} bids`);

        // Step 3: Rank bids and select winners
        const auctionConfig = await getAuctionConfig(state, poolId);
        const winners = Consensus.rankBids(decryptedBids, auctionConfig.maxWinners);
        console.log(`Selected ${winners.length} winners`);

        // Step 4: Compute winnersRoot for consensus
        const winnersArray = winners.map(w => ({
            bidder: w.bidder,
            amount: w.amount,
            allocation: BigInt(w.allocation) // Convert to bigint for contract
        }));
        const winnersRoot = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ['tuple(address bidder, uint256 amount, uint256 allocation)[]'],
            [winnersArray]
        ));

        console.log(`Winners root: ${winnersRoot}`);

        // Step 5: Submit response to AVS
        await respondToTask(state, taskId, winnersArray, winnersRoot);

        console.log(`✅ Task #${taskId} response submitted`);
    } catch (error) {
        console.error(`❌ Failed to process task #${taskId}:`, error);
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
 * Respond to AVS task with decrypted winners
 */
export const respondToTask = async (
    state: OperatorState,
    taskId: number,
    winners: { bidder: string; amount: bigint; allocation: bigint }[],
    winnersRoot: string
): Promise<void> => {
    console.log(`\n📤 Submitting response to Task #${taskId}...`);

    try {
        const tx = await state.contracts.serviceManager.respondToTask(
            taskId,
            winners,
            winnersRoot
        );

        console.log(`Response transaction: ${tx.hash}`);
        await tx.wait();

        console.log(`✅ Response submitted for Task #${taskId}`);

        // Check if quorum is reached
        const hasQuorum = await state.contracts.serviceManager.hasReachedQuorum(taskId);
        if (hasQuorum) {
            console.log(`🎉 Quorum reached for Task #${taskId}! Settlement will be finalized.`);
        } else {
            console.log(`⏳ Waiting for more operator responses to reach quorum...`);
        }
    } catch (error) {
        console.error(`❌ Failed to submit response:`, error);
        throw error;
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
    console.log(`\n🚀 Starting LaunchGuard AVS Operator ${state.config.operatorId}...`);

    // Step 1: Register with AVS
    let registeredState = state;
    if (!state.isRegistered) {
        registeredState = await registerOperator(state);
    }

    const runningState = { ...registeredState, isRunning: true };

    // Step 2: Set up event listeners
    const handlers = {
        onTaskCreated: (taskId: number, poolId: string, totalBidders: number) =>
            handleTaskCreated(runningState, taskId, poolId, totalBidders),
        onBidSubmitted: async (poolId: string, bidder: string) => {
            const newState = await handleBidSubmitted(runningState, poolId, bidder);
            Object.assign(runningState, newState);
        },
        onAuctionSettled: (poolId: string, totalBids: number, winnersCount: number) => {
            console.log(`✅ Auction ${poolId} settled with ${winnersCount} winners`);
        }
    };

    setupEventListeners(runningState, handlers);

    // Step 3: Start monitoring loop
    monitoringLoop(runningState, async (s) => {
        // Monitor for pending tasks
    });

    console.log(`\n✅ Operator ${state.config.operatorId} is running and listening for tasks...`);
    return runningState;
};

/**
 * Stop the operator
 */
export const stopOperator = (state: OperatorState): OperatorState => {
    console.log(`\n🛑 Stopping operator ${state.config.operatorId}...`);

    state.contracts.serviceManager.removeAllListeners();
    state.contracts.auction.removeAllListeners();

    console.log(`✅ Operator ${state.config.operatorId} stopped`);

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

const getServiceManagerABI = (): any[] => [
    // Operator management
    'function registerOperator() payable',
    'function deregisterOperator()',
    'function isOperator(address) view returns (bool)',
    'function getOperatorInfo(address) view returns (tuple(address operatorAddress, bool isActive, uint256 stake, uint256 taskResponses, uint256 slashedAmount))',

    // Task management
    'event TaskCreated(uint32 indexed taskId, bytes32 indexed poolId, uint256 totalBidders)',
    'event TaskResponded(uint32 indexed taskId, address indexed operator, bytes32 winnersRoot)',
    'event TaskCompleted(uint32 indexed taskId, bytes32 indexed poolId, uint256 winnersCount)',
    'function respondToTask(uint32 taskId, tuple(address bidder, uint256 amount, uint256 allocation)[] winners, bytes32 winnersRoot)',
    'function hasReachedQuorum(uint32 taskId) view returns (bool)',
    'function getTask(uint32 taskId) view returns (tuple(uint32 taskId, bytes32 poolId, uint256 auctionEndTime, uint256 totalBidders, uint32 taskCreatedBlock, uint8 quorumThresholdPercentage))',

    // Events
    'event OperatorRegistered(address indexed operator, uint256 stake)',
    'event OperatorDeregistered(address indexed operator)',
    'event OperatorSlashed(address indexed operator, uint256 amount, string reason)'
];

const getAuctionABI = (): any[] => [
    'event AuctionCreated(bytes32 indexed poolId, uint256 auctionEndTime, uint256 priorityWindowDuration, uint256 minBidAmount, uint256 maxWinners)',
    'event BidSubmitted(bytes32 indexed poolId, address indexed bidder, uint256 timestamp)',
    'event AuctionSettled(bytes32 indexed poolId, uint256 totalBids, uint256 winnersCount)',
    'function getBidders(tuple(address,address,uint24,int24,address)) view returns (address[])',
    'function getBid(tuple(address,address,uint24,int24,address), address) view returns (tuple(address bidder, uint256 encryptedAmount, uint256 timestamp, bool isWinner, bool hasExecuted))',
    'function getAuctionConfig(tuple(address,address,uint24,int24,address)) view returns (tuple(uint256 auctionEndTime, uint256 priorityWindowDuration, uint256 minBidAmount, uint256 maxWinners, bool isActive))'
];

const getReputationABI = (): any[] => [
    'function blacklist(address user, string reason)',
    'function addCommunityMember(address user)',
    'function canParticipate(address) view returns (bool)',
    'function isBlacklisted(address) view returns (bool)'
];

// ============ Main Entry Point ============

const main = async () => {
    console.log('╔═══════════════════════════════════════════════╗');
    console.log('║   LaunchGuard AVS Operator - EigenLayer      ║');
    console.log('╚═══════════════════════════════════════════════╝\n');

    const config = createOperatorConfig(
        process.env.RPC_URL || 'http://localhost:8545',
        process.env.PRIVATE_KEY || '',
        parseInt(process.env.OPERATOR_ID || '0'),
        ethers.parseEther(process.env.STAKE_AMOUNT || '2'), // Default 2 ETH stake
        {
            serviceManager: process.env.SERVICE_MANAGER_ADDRESS || '',
            auction: process.env.AUCTION_ADDRESS || '',
            reputation: process.env.REPUTATION_ADDRESS || ''
        }
    );

    console.log('Configuration:');
    console.log(`  RPC URL: ${config.rpcUrl}`);
    console.log(`  Operator ID: ${config.operatorId}`);
    console.log(`  Stake: ${ethers.formatEther(config.stakeAmount)} ETH`);
    console.log(`  Service Manager: ${config.contractAddresses.serviceManager}`);
    console.log(`  Auction: ${config.contractAddresses.auction}`);
    console.log(`  Reputation: ${config.contractAddresses.reputation}\n`);

    let state = initializeOperator(config);
    state = await startOperator(state);

    // Handle graceful shutdown
    process.on('SIGINT', () => {
        console.log('\n\n🛑 Received shutdown signal...');
        state = stopOperator(state);
        process.exit(0);
    });

    // Keep process alive
    await new Promise(() => {});
};

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}


