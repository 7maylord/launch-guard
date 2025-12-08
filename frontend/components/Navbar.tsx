import { Wallet, Shield } from 'lucide-react';
import { useWallet } from '@/hooks/useWallet';

export function Navbar() {
  const { address, isConnected, connect, isConnecting } = useWallet();

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  return (
    <nav className="border-b border-white/10 bg-black/50 backdrop-blur-md sticky top-0 z-50">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-2 bg-blue-500/10 rounded-lg">
            <Shield className="w-6 h-6 text-blue-500" />
          </div>
          <span className="text-xl font-bold bg-gradient-to-r from-blue-400 to-purple-500 bg-clip-text text-transparent">
            LaunchGuard
          </span>
        </div>

        <button
          onClick={isConnected ? undefined : connect}
          disabled={isConnecting}
          className={`
            flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all
            ${isConnected 
              ? 'bg-white/5 text-white/80 cursor-default' 
              : 'bg-blue-600 hover:bg-blue-500 text-white shadow-lg shadow-blue-500/20'
            }
          `}
        >
          <Wallet className="w-4 h-4" />
          {isConnecting ? 'Connecting...' : isConnected ? formatAddress(address!) : 'Connect Wallet'}
        </button>
      </div>
    </nav>
  );
}
