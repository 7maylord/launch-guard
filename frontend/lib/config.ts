/**
 * LaunchGuard Configuration
 * Deployed contract addresses and network settings
 */

export const NETWORKS = {
  sepolia: {
    chainId: 11155111,
    name: 'Sepolia',
    rpcUrl: 'https://rpc.sepolia.org',
    explorerUrl: 'https://sepolia.etherscan.io',
  },
  localhost: {
    chainId: 31337,
    name: 'Localhost',
    rpcUrl: 'http://127.0.0.1:8545',
    explorerUrl: '',
  },
} as const;

// Current network configuration
export const CURRENT_NETWORK = NETWORKS.sepolia;

// Deployed contract addresses on Sepolia
export const CONTRACTS = {
  poolManager: '0xE03A1074c86CFeDd5C142C4F04F1a1536e203543',
  launchGuardHook: '0xB60f3011897219d6EbDECD6A09Af1B3E67642880',
  encryptedAuction: '0x69aeF7863e0149a78E3D1F375d55208cbE873Fc0',
  reputationRegistry: '0xef0eE06EBfB7536DfCe6Db0c83Aa460Ef3eD8322',
  serviceManager: '0x49fa30F9BE0158cE135fa42D390AD4664362ff9A', // EigenLayer AVS

  // Test pool tokens (from pool-info.json)
  testPool: {
    myToken: '0x6Af3bF76C0DF3cc024cf9f9b84f7409E059504E4',
    weth: '0x2276EcD90c1E8A8939C70c8F70dcE69C3c2704f6',
    currency0: '0x2276EcD90c1E8A8939C70c8F70dcE69C3c2704f6', // WETH
    currency1: '0x6Af3bF76C0DF3cc024cf9f9b84f7409E059504E4', // MyToken
    poolId: '94694747172547630862093291812931808249162049708118797674722772915316000339355',
  },
} as const;

// Pool key for the test pool
export const TEST_POOL_KEY = {
  currency0: CONTRACTS.testPool.currency0,
  currency1: CONTRACTS.testPool.currency1,
  fee: 3000, // 0.3%
  tickSpacing: 60,
  hooks: CONTRACTS.launchGuardHook,
} as const;

// Auction configuration
export const AUCTION_CONFIG = {
  minBid: '10000000000000000', // 0.01 ETH in wei
  maxWinners: 100,
  priorityWindowDuration: 300, // 5 minutes in seconds
} as const;

// UI configuration
export const UI_CONFIG = {
  refreshInterval: 10000, // 10 seconds
  maxBidAmount: '10', // 10 ETH max
  minBidAmount: '0.01', // 0.01 ETH min
} as const;

// Contract ABIs (minimal, for reading)
export const ABIS = {
  launchGuardHook: [
    'function getAuction((address,address,uint24,int24,address)) view returns (uint256,uint256,uint256,uint256,bool)',
    'function createAuction((address,address,uint24,int24,address),uint256,uint256,uint256,uint256)',
  ],
  encryptedAuction: [
    'function submitBid((address,address,uint24,int24,address),(bytes))',
    'function isWinner((address,address,uint24,int24,address),address) view returns (bool)',
    'function isInPriorityWindow((address,address,uint24,int24,address)) view returns (bool)',
    'function auctions(bytes32) view returns (uint256,uint256,uint256,uint256,bool)',
  ],
  reputationRegistry: [
    'function canParticipate(address) view returns (bool)',
    'function isBlacklisted(address) view returns (bool)',
    'function isCommunityMember(address) view returns (bool)',
  ],
  erc20: [
    'function balanceOf(address) view returns (uint256)',
    'function allowance(address,address) view returns (uint256)',
    'function approve(address,uint256) returns (bool)',
    'function symbol() view returns (string)',
    'function decimals() view returns (uint8)',
  ],
} as const;

// Helper to get explorer link
export function getExplorerLink(address: string, type: 'address' | 'tx' = 'address'): string {
  const baseUrl = CURRENT_NETWORK.explorerUrl;
  return `${baseUrl}/${type}/${address}`;
}

// Helper to format wei to ETH
export function formatEth(wei: bigint | string): string {
  const weiValue = typeof wei === 'string' ? BigInt(wei) : wei;
  const eth = Number(weiValue) / 1e18;
  return eth.toFixed(4);
}

// Helper to parse ETH to wei
export function parseEth(eth: string): bigint {
  const value = parseFloat(eth);
  if (isNaN(value) || value < 0) {
    throw new Error('Invalid ETH amount');
  }
  return BigInt(Math.floor(value * 1e18));
}
