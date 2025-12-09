'use client';

import { useEffect, useState } from 'react';
import { Contract, formatEther } from 'ethers';
import { Users, Trophy, CheckCircle, Clock } from 'lucide-react';
import { useReownWallet } from '@/hooks/useReownWallet';
import { CONTRACTS } from '@/lib/config';
import { EncryptedAuctionABI } from '@/lib/abis';

interface AuctionDetailsProps {
  auctionEndTime: number;
  settled: boolean;
  refreshTrigger?: number;
}

export function AuctionDetails({ auctionEndTime, settled, refreshTrigger }: AuctionDetailsProps) {
  const { provider, address } = useReownWallet();
  const [bidders, setBidders] = useState<string[]>([]);
  const [isWinner, setIsWinner] = useState(false);
  const [allocation, setAllocation] = useState<string>('0');
  const [inPriorityWindow, setInPriorityWindow] = useState(false);
  const [loading, setLoading] = useState(true);

  const poolKey = {
    currency0: CONTRACTS.testPool.currency0,
    currency1: CONTRACTS.testPool.currency1,
    fee: 3000,
    tickSpacing: 60,
    hooks: CONTRACTS.launchGuardHook,
  };

  useEffect(() => {
    async function fetchDetails() {
      if (!provider) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        const contract = new Contract(CONTRACTS.encryptedAuction, EncryptedAuctionABI, provider);

        // Fetch bidders
        const biddersList = await contract.getBidders(poolKey);
        setBidders(biddersList);

        // Check priority window
        const priorityWindow = await contract.isInPriorityWindow(poolKey);
        setInPriorityWindow(priorityWindow);

        // If user is connected and auction is settled, check winner status
        if (address && settled) {
          const winner = await contract.isWinner(poolKey, address);
          setIsWinner(winner);

          if (winner) {
            const alloc = await contract.getAllocation(poolKey, address);
            setAllocation(formatEther(alloc));
          }
        }
      } catch (error) {
        console.error('Error fetching auction details:', error);
      } finally {
        setLoading(false);
      }
    }

    fetchDetails();
  }, [provider, address, settled, refreshTrigger]);

  if (loading) {
    return (
      <div className="p-6 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-sm">
        <div className="text-center text-white/60">Loading auction details...</div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* User Status */}
      {address && settled && (
        <div className={`p-4 rounded-xl border ${
          isWinner
            ? 'bg-green-500/10 border-green-500/20'
            : 'bg-white/5 border-white/10'
        }`}>
          <div className="flex items-center gap-3">
            {isWinner ? (
              <>
                <Trophy className="w-5 h-5 text-green-400" />
                <div>
                  <h3 className="font-semibold text-green-400">You Won! 🎉</h3>
                  <p className="text-sm text-green-400/80">
                    Allocation: {allocation} ETH
                  </p>
                </div>
              </>
            ) : (
              <>
                <CheckCircle className="w-5 h-5 text-white/60" />
                <div>
                  <h3 className="font-medium text-white/80">Not a Winner</h3>
                  <p className="text-sm text-white/60">
                    You can trade after the priority window
                  </p>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {/* Priority Window Status */}
      {settled && inPriorityWindow && (
        <div className="p-4 rounded-xl bg-yellow-500/10 border border-yellow-500/20">
          <div className="flex items-center gap-3">
            <Clock className="w-5 h-5 text-yellow-400" />
            <div>
              <h3 className="font-semibold text-yellow-400">Priority Window Active</h3>
              <p className="text-sm text-yellow-400/80">
                Only auction winners can trade right now
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Bidders List */}
      <div className="p-6 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-sm">
        <div className="flex items-center gap-3 mb-4">
          <Users className="w-5 h-5 text-blue-400" />
          <h3 className="text-lg font-semibold text-white">Bidders ({bidders.length})</h3>
        </div>

        {bidders.length === 0 ? (
          <p className="text-white/60 text-sm">No bids yet. Be the first to bid!</p>
        ) : (
          <div className="space-y-2 max-h-60 overflow-y-auto">
            {bidders.map((bidder, index) => (
              <div
                key={index}
                className={`p-3 rounded-lg ${
                  bidder.toLowerCase() === address?.toLowerCase()
                    ? 'bg-blue-500/10 border border-blue-500/20'
                    : 'bg-black/20'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-mono text-white/80">
                    {bidder.slice(0, 6)}...{bidder.slice(-4)}
                  </span>
                  {bidder.toLowerCase() === address?.toLowerCase() && (
                    <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-1 rounded">
                      You
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
