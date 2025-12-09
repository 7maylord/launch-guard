'use client';

import { useEffect, useState } from 'react';
import { Contract, formatEther } from 'ethers';
import { Navbar } from '@/components/Navbar';
import { EncryptedBidForm } from '@/components/EncryptedBidForm';
import { AuctionStatus } from '@/components/AuctionStatus';
import { CreateAuctionForm } from '@/components/CreateAuctionForm';
import { AuctionDetails } from '@/components/AuctionDetails';
import { useReownWallet } from '@/hooks/useReownWallet';
import { CONTRACTS, CURRENT_NETWORK } from '@/lib/config';
import { useAppKitNetwork } from '@reown/appkit/react';
import { AlertCircle } from 'lucide-react';
import { EncryptedAuctionABI } from '@/lib/abis';

interface AuctionData {
  endTime: number;
  totalBids: number;
  minBid: string;
  isActive: boolean;
  priorityWindow: number;
  maxWinners: number;
  settled: boolean;
}

export default function Home() {
  const { provider, isConnected, isCorrectNetwork } = useReownWallet();
  const { caipNetwork, switchNetwork } = useAppKitNetwork();
  const [auctionData, setAuctionData] = useState<AuctionData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // Create PoolKey from deployment data
  const poolKey = {
    currency0: CONTRACTS.testPool.currency0,
    currency1: CONTRACTS.testPool.currency1,
    fee: 3000,
    tickSpacing: 60,
    hooks: CONTRACTS.launchGuardHook,
  };

  useEffect(() => {
    async function fetchAuctionData() {
      if (!provider) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const contract = new Contract(
          CONTRACTS.encryptedAuction,
          EncryptedAuctionABI,
          provider
        );

        // Fetch auction configuration
        const auctionConfig = await contract.getAuctionConfig(poolKey);

        // Check if auction exists (auctionEndTime will be 0 if no auction)
        if (Number(auctionConfig.auctionEndTime) === 0) {
          throw new Error('No auction exists for this pool');
        }

        // Fetch bidders list
        const bidders = await contract.getBidders(poolKey);

        const currentTime = Math.floor(Date.now() / 1000);
        const endTime = Number(auctionConfig.auctionEndTime);
        const hasEnded = currentTime > endTime;

        setAuctionData({
          endTime: endTime,
          totalBids: bidders.length,
          minBid: formatEther(auctionConfig.minBidAmount),
          isActive: auctionConfig.isActive && !hasEnded,
          priorityWindow: Number(auctionConfig.priorityWindowDuration),
          maxWinners: Number(auctionConfig.maxWinners),
          settled: !auctionConfig.isActive && hasEnded,
        });
      } catch (err) {
        console.error('Error fetching auction data:', err);
        setError('Failed to load auction data. Make sure an auction exists for this pool.');
      } finally {
        setLoading(false);
      }
    }

    fetchAuctionData();

    // Refresh every 30 seconds
    const interval = setInterval(fetchAuctionData, 30000);
    return () => clearInterval(interval);
  }, [provider, refreshTrigger]);

  const handleAuctionCreated = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  return (
    <div className="min-h-screen bg-[#0a0a0a] text-white selection:bg-blue-500/30">
      <div className="fixed inset-0 bg-[url('/grid.svg')] bg-center [mask-image:linear-gradient(180deg,white,rgba(255,255,255,0))]" />

      <Navbar />

      <main className="container mx-auto px-4 py-12 relative z-10">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-12">
            <h1 className="text-4xl md:text-6xl font-bold bg-gradient-to-r from-white to-white/60 bg-clip-text text-transparent mb-4">
              Fair Token Launches
            </h1>
            <p className="text-lg text-white/60 max-w-2xl mx-auto">
              Participate in encrypted auctions protected by FHE and EigenLayer.
              No front-running, no sniping, just fair price discovery.
            </p>
          </div>

          {/* Network Warning */}
          {isConnected && !isCorrectNetwork && (
            <div className="mb-6 p-4 rounded-xl bg-yellow-500/10 border border-yellow-500/20 backdrop-blur-sm">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-5 h-5 text-yellow-400 shrink-0 mt-0.5" />
                <div className="flex-1">
                  <h3 className="font-semibold text-yellow-400 mb-1">Wrong Network</h3>
                  <p className="text-sm text-yellow-400/80 mb-3">
                    Please switch to {CURRENT_NETWORK.name} to interact with the auction.
                  </p>
                  <button
                    onClick={async () => {
                      try {
                        await switchNetwork({
                          id: CURRENT_NETWORK.chainId,
                          name: CURRENT_NETWORK.name,
                          nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
                          rpcUrls: { default: { http: [CURRENT_NETWORK.rpcUrl] } },
                          blockExplorers: CURRENT_NETWORK.explorerUrl ? {
                            default: { name: 'Etherscan', url: CURRENT_NETWORK.explorerUrl }
                          } : undefined,
                        } as any);
                      } catch (err) {
                        console.error('Failed to switch network:', err);
                      }
                    }}
                    className="px-4 py-2 bg-yellow-500 hover:bg-yellow-400 text-black font-medium rounded-lg transition-colors"
                  >
                    Switch to {CURRENT_NETWORK.name}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Loading State */}
          {loading && (
            <div className="text-center py-12">
              <div className="inline-block w-8 h-8 border-4 border-white/20 border-t-white rounded-full animate-spin mb-4" />
              <p className="text-white/60">Loading auction data...</p>
            </div>
          )}

          {/* Create Auction Form */}
          <CreateAuctionForm onAuctionCreated={handleAuctionCreated} />

          {/* Error State */}
          {error && !loading && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 backdrop-blur-sm">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-5 h-5 text-red-400 shrink-0 mt-0.5" />
                <div>
                  <h3 className="font-semibold text-red-400 mb-1">No Auction Found</h3>
                  <p className="text-sm text-red-400/80">{error}</p>
                  <p className="text-sm text-red-400/60 mt-2">Create an auction above to get started!</p>
                </div>
              </div>
            </div>
          )}

          {/* Auction Data */}
          {auctionData && !loading && (
            <>
              <AuctionStatus
                endTime={auctionData.endTime}
                totalBids={auctionData.totalBids}
                minBid={auctionData.minBid}
                isActive={auctionData.isActive}
              />

              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Bid Form */}
                <div className="lg:col-span-1">
                  <EncryptedBidForm
                    poolId="" // Not used - poolKey is constructed in the component
                    contractAddress={CONTRACTS.encryptedAuction}
                  />
                </div>

                {/* How it Works */}
                <div className="lg:col-span-1">
                  <div className="p-6 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-sm">
                  <h3 className="text-lg font-semibold text-white mb-4">How it works</h3>
                  <ul className="space-y-4">
                    <li className="flex gap-3">
                      <div className="w-6 h-6 rounded-full bg-blue-500/20 flex items-center justify-center text-sm font-bold text-blue-400 shrink-0">
                        1
                      </div>
                      <p className="text-sm text-white/60">
                        Submit your bid encrypted. The amount is hidden from everyone, including miners.
                      </p>
                    </li>
                    <li className="flex gap-3">
                      <div className="w-6 h-6 rounded-full bg-purple-500/20 flex items-center justify-center text-sm font-bold text-purple-400 shrink-0">
                        2
                      </div>
                      <p className="text-sm text-white/60">
                        When the auction ends, operators collaboratively decrypt bids using threshold cryptography.
                      </p>
                    </li>
                    <li className="flex gap-3">
                      <div className="w-6 h-6 rounded-full bg-green-500/20 flex items-center justify-center text-sm font-bold text-green-400 shrink-0">
                        3
                      </div>
                      <p className="text-sm text-white/60">
                        Winners get exclusive access to trade during the priority window.
                      </p>
                    </li>
                  </ul>

                  {/* Auction Details */}
                  <div className="mt-6 pt-6 border-t border-white/10 space-y-2">
                    <h4 className="text-sm font-semibold text-white/80 mb-3">Auction Details</h4>
                    <div className="flex justify-between text-sm">
                      <span className="text-white/60">Max Winners</span>
                      <span className="text-white font-medium">{auctionData.maxWinners}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-white/60">Priority Window</span>
                      <span className="text-white font-medium">{Math.floor(auctionData.priorityWindow / 60)} minutes</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-white/60">Status</span>
                      <span className={`font-medium ${auctionData.settled ? 'text-green-400' : auctionData.isActive ? 'text-blue-400' : 'text-yellow-400'}`}>
                        {auctionData.settled ? 'Settled' : auctionData.isActive ? 'Active' : 'Ended'}
                      </span>
                    </div>
                  </div>
                  </div>
                </div>

                {/* Auction Details */}
                <div className="lg:col-span-1">
                  <AuctionDetails
                    auctionEndTime={auctionData.endTime}
                    settled={auctionData.settled}
                    refreshTrigger={refreshTrigger}
                  />
                </div>
              </div>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
