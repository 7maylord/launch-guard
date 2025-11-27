/**
 * ReputationMonitor - Functional approach to reputation tracking
 */

export interface ReputationData {
    address: string;
    score: number;
    lastUpdate: number;
    updateHistory: ReputationUpdate[];
}

export interface ReputationUpdate {
    delta: number;
    reason: string;
    timestamp: number;
}

export interface ReputationAnalysis {
    address: string;
    score: number;
    isBotLikely: boolean;
    isWashTrading: boolean;
    isSybil: boolean;
    shouldBlacklist: boolean;
    shouldWhitelist: boolean;
    timestamp: number;
}

export interface ActivityRecord {
    type: 'bid' | 'swap' | 'liquidity' | 'transfer';
    timestamp: number;
    data?: {
        amount?: number;
        direction?: 'buy' | 'sell';
        [key: string]: any;
    };
}

export interface ReputationState {
    operatorId: number;
    reputationScores: Map<string, ReputationData>;
    activityLog: Map<string, ActivityRecord[]>;
}

/**
 * Create initial reputation state
 */
export const createReputationState = (operatorId: number): ReputationState => ({
    operatorId,
    reputationScores: new Map(),
    activityLog: new Map()
});

/**
 * Analyze user activity to detect suspicious behavior
 */
export const analyzeUser = (
    state: ReputationState,
    address: string
): ReputationAnalysis => {
    console.log(`[Operator ${state.operatorId}] Analyzing reputation for ${address}`);
    
    const activities = state.activityLog.get(address) || [];
    const reputation = state.reputationScores.get(address) || getDefaultReputation(address);
    
    const isBotLikely = detectBotBehavior(activities);
    const isWashTrading = detectWashTrading(activities);
    const isSybil = detectSybilAttack(address, activities);
    
    const score = calculateReputationScore(reputation, {
        isBotLikely,
        isWashTrading,
        isSybil
    });
    
    const analysis: ReputationAnalysis = {
        address,
        score,
        isBotLikely,
        isWashTrading,
        isSybil,
        shouldBlacklist: score < 50,
        shouldWhitelist: score > 150,
        timestamp: Date.now()
    };
    
    console.log(`Reputation analysis for ${address}:`, analysis);
    return analysis;
};

/**
 * Record user activity (returns new state)
 */
export const recordActivity = (
    state: ReputationState,
    address: string,
    activity: ActivityRecord
): ReputationState => {
    const activities = state.activityLog.get(address) || [];
    const newActivities = [...activities, activity];
    
    // Keep only last 100 activities
    const trimmedActivities = newActivities.length > 100
        ? newActivities.slice(-100)
        : newActivities;
    
    const newActivityLog = new Map(state.activityLog);
    newActivityLog.set(address, trimmedActivities);
    
    return {
        ...state,
        activityLog: newActivityLog
    };
};

/**
 * Update reputation score (returns new state)
 */
export const updateReputation = (
    state: ReputationState,
    address: string,
    delta: number,
    reason: string
): ReputationState => {
    const current = state.reputationScores.get(address) || getDefaultReputation(address);
    
    const newScore = Math.max(0, Math.min(200, current.score + delta));
    const newUpdate: ReputationUpdate = {
        delta,
        reason,
        timestamp: Date.now()
    };
    
    const updated: ReputationData = {
        ...current,
        score: newScore,
        lastUpdate: Date.now(),
        updateHistory: [...current.updateHistory, newUpdate]
    };
    
    const newScores = new Map(state.reputationScores);
    newScores.set(address, updated);
    
    console.log(`Updated reputation for ${address}: ${newScore} (${reason})`);
    
    return {
        ...state,
        reputationScores: newScores
    };
};

/**
 * Get reputation data for address
 */
export const getReputation = (
    state: ReputationState,
    address: string
): ReputationData => state.reputationScores.get(address) || getDefaultReputation(address);

/**
 * Batch analyze multiple users
 */
export const batchAnalyze = (
    state: ReputationState,
    addresses: string[]
): Map<string, ReputationAnalysis> => {
    const results = new Map<string, ReputationAnalysis>();
    
    addresses.forEach(address => {
        const analysis = analyzeUser(state, address);
        results.set(address, analysis);
    });
    
    return results;
};

/**
 * Get blacklist recommendations
 */
export const getBlacklistRecommendations = (state: ReputationState): string[] => {
    return Array.from(state.reputationScores.entries())
        .filter(([_, data]) => data.score < 50)
        .map(([address, _]) => address);
};

/**
 * Get whitelist recommendations (community members)
 */
export const getWhitelistRecommendations = (state: ReputationState): string[] => {
    return Array.from(state.reputationScores.entries())
        .filter(([_, data]) => data.score > 150)
        .map(([address, _]) => address);
};

// ============ Detection Functions ============

const detectBotBehavior = (activities: ActivityRecord[]): boolean => {
    if (activities.length < 5) return false;
    
    const recentActivities = activities.slice(-10);
    const timestamps = recentActivities.map(a => a.timestamp);
    
    // Calculate average time between transactions
    const diffs = timestamps.slice(1).map((t, i) => t - timestamps[i]);
    const avgDiff = diffs.reduce((sum, d) => sum + d, 0) / diffs.length;
    
    // If average time is less than 5 seconds, likely a bot
    const isTooFast = avgDiff < 5000;
    
    // Check for identical transaction patterns
    const patterns = recentActivities.map(a => a.type);
    const uniquePatterns = new Set(patterns);
    const isRepetitive = uniquePatterns.size < patterns.length / 2;
    
    return isTooFast || isRepetitive;
};

const detectWashTrading = (activities: ActivityRecord[]): boolean => {
    const trades = activities.filter(a => a.type === 'swap');
    
    if (trades.length < 4) return false;
    
    // Check for alternating buy/sell patterns
    const alternatingCount = trades.slice(1).reduce((count, trade, i) => {
        const prevDirection = trades[i].data?.direction;
        const currDirection = trade.data?.direction;
        return count + (currDirection !== prevDirection ? 1 : 0);
    }, 0);
    
    return alternatingCount / trades.length > 0.7;
};

const detectSybilAttack = (address: string, activities: ActivityRecord[]): boolean => {
    if (activities.length === 0) return false;
    
    const accountAge = Date.now() - activities[0].timestamp;
    const isNewAccount = accountAge < 7 * 24 * 60 * 60 * 1000; // 7 days
    const hasHighActivity = activities.length > 50;
    
    const amounts = activities
        .filter(a => a.data?.amount)
        .map(a => a.data!.amount!);
    
    if (amounts.length < 3) return false;
    
    const avgAmount = amounts.reduce((sum, a) => sum + a, 0) / amounts.length;
    const similarAmounts = amounts.filter(a => 
        Math.abs(a - avgAmount) / avgAmount < 0.1
    ).length;
    
    const hasSimilarAmounts = similarAmounts / amounts.length > 0.8;
    
    return isNewAccount && hasHighActivity && hasSimilarAmounts;
};

const calculateReputationScore = (
    current: ReputationData,
    flags: {
        isBotLikely: boolean;
        isWashTrading: boolean;
        isSybil: boolean;
    }
): number => {
    let score = current.score;
    
    if (flags.isBotLikely) score -= 30;
    if (flags.isWashTrading) score -= 40;
    if (flags.isSybil) score -= 50;
    
    return Math.max(0, Math.min(200, score));
};

const getDefaultReputation = (address: string): ReputationData => ({
    address,
    score: 100,
    lastUpdate: Date.now(),
    updateHistory: []
});
