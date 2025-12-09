'use client';

import { useState } from 'react';
import { Plus, Loader2, Calendar, Users, Coins } from 'lucide-react';
import { useReownWallet } from '@/hooks/useReownWallet';
import { Contract, parseEther } from 'ethers';
import { CONTRACTS } from '@/lib/config';
import { LaunchGuardHookABI } from '@/lib/abis';

interface CreateAuctionFormProps {
  onAuctionCreated?: () => void;
}

export function CreateAuctionForm({ onAuctionCreated }: CreateAuctionFormProps) {
  const { provider, signer, isConnected } = useReownWallet();
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    durationHours: '1',
    priorityMinutes: '5',
    minBidEth: '0.01',
    maxWinners: '100',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!signer) return;

    try {
      setIsSubmitting(true);

      const contract = new Contract(CONTRACTS.launchGuardHook, LaunchGuardHookABI, signer);

      // Create PoolKey tuple
      const poolKey = [
        CONTRACTS.testPool.currency0,
        CONTRACTS.testPool.currency1,
        3000,
        60,
        CONTRACTS.launchGuardHook,
      ];

      // Calculate timestamps
      const auctionEndTime = Math.floor(Date.now() / 1000) + (Number(formData.durationHours) * 3600);
      const priorityWindow = Number(formData.priorityMinutes) * 60;
      const minBid = parseEther(formData.minBidEth);
      const maxWinners = Number(formData.maxWinners);

      console.log('Creating auction with params:', {
        auctionEndTime,
        priorityWindow,
        minBid: minBid.toString(),
        maxWinners,
      });

      const tx = await contract.createAuction(
        poolKey,
        auctionEndTime,
        priorityWindow,
        minBid,
        maxWinners
      );

      console.log('Transaction sent:', tx.hash);
      await tx.wait();

      alert('Auction created successfully! 🎉');
      setIsOpen(false);
      onAuctionCreated?.();
    } catch (error: any) {
      console.error('Error creating auction:', error);

      // Handle specific error cases
      let message = 'Failed to create auction';

      if (error?.data === '0x04581cc8') {
        message = 'An auction already exists for this pool. Please wait for it to end before creating a new one.';
      } else if (error?.reason) {
        message = error.reason;
      } else if (error?.message) {
        message = error.message;
      }

      alert(`Error: ${message}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isConnected) {
    return null;
  }

  return (
    <div className="mb-6">
      {!isOpen ? (
        <button
          onClick={() => setIsOpen(true)}
          className="w-full flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 text-white font-medium transition-all shadow-lg shadow-purple-500/20"
        >
          <Plus className="w-5 h-5" />
          Create New Auction
        </button>
      ) : (
        <div className="p-6 rounded-2xl bg-gradient-to-b from-white/10 to-white/5 border border-white/10 backdrop-blur-sm">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold text-white">Create Auction</h3>
            <button
              onClick={() => setIsOpen(false)}
              className="text-white/60 hover:text-white transition-colors"
            >
              ✕
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="flex items-center gap-2 text-sm font-medium text-white/80 mb-2">
                  <Calendar className="w-4 h-4" />
                  Duration (hours)
                </label>
                <input
                  type="number"
                  value={formData.durationHours}
                  onChange={(e) => setFormData({ ...formData, durationHours: e.target.value })}
                  min="0.1"
                  step="0.1"
                  required
                  className="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-2 text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                />
              </div>

              <div>
                <label className="flex items-center gap-2 text-sm font-medium text-white/80 mb-2">
                  <Calendar className="w-4 h-4" />
                  Priority Window (min)
                </label>
                <input
                  type="number"
                  value={formData.priorityMinutes}
                  onChange={(e) => setFormData({ ...formData, priorityMinutes: e.target.value })}
                  min="1"
                  required
                  className="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-2 text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="flex items-center gap-2 text-sm font-medium text-white/80 mb-2">
                  <Coins className="w-4 h-4" />
                  Min Bid (ETH)
                </label>
                <input
                  type="number"
                  value={formData.minBidEth}
                  onChange={(e) => setFormData({ ...formData, minBidEth: e.target.value })}
                  min="0.001"
                  step="0.001"
                  required
                  className="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-2 text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                />
              </div>

              <div>
                <label className="flex items-center gap-2 text-sm font-medium text-white/80 mb-2">
                  <Users className="w-4 h-4" />
                  Max Winners
                </label>
                <input
                  type="number"
                  value={formData.maxWinners}
                  onChange={(e) => setFormData({ ...formData, maxWinners: e.target.value })}
                  min="1"
                  required
                  className="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-2 text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                type="button"
                onClick={() => setIsOpen(false)}
                className="flex-1 px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/80 font-medium transition-all"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className={`
                  flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-xl font-medium transition-all
                  ${isSubmitting
                    ? 'bg-white/10 text-white/40 cursor-not-allowed'
                    : 'bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 text-white shadow-lg shadow-purple-500/20'
                  }
                `}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Creating...
                  </>
                ) : (
                  <>
                    <Plus className="w-4 h-4" />
                    Create Auction
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
