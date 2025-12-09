/**
 * Reown AppKit Configuration
 * Multi-wallet connection support for LaunchGuard
 */

import { createAppKit } from '@reown/appkit';
import { EthersAdapter } from '@reown/appkit-adapter-ethers';
import type { AppKitNetwork } from '@reown/appkit/networks';

// Your WalletConnect Project ID
// Get one at https://cloud.reown.com/
const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'YOUR_PROJECT_ID';

// Define Sepolia network with custom RPC
const sepoliaNetwork: AppKitNetwork = {
  id: 11155111,
  name: 'Sepolia',
  nativeCurrency: {
    name: 'Sepolia ETH',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.sepolia.org'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Etherscan',
      url: 'https://sepolia.etherscan.io',
    },
  },
  testnet: true,
} as AppKitNetwork;

// Create AppKit instance
export const appKit = createAppKit({
  adapters: [new EthersAdapter()],
  networks: [sepoliaNetwork],
  projectId,
  metadata: {
    name: 'LaunchGuard',
    description: 'Fair Token Launches with FHE and EigenLayer',
    url: typeof window !== 'undefined' ? window.location.origin : 'https://launchguard.app',
    icons: ['https://avatars.githubusercontent.com/u/37784886'],
  },
  features: {
    analytics: false,
    email: false,
    socials: [],
  },
  themeMode: 'dark',
  themeVariables: {
    '--w3m-accent': '#6366f1', // Indigo/purple theme
    '--w3m-border-radius-master': '12px',
  },
});

export default appKit;
