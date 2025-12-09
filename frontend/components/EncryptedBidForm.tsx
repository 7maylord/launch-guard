import { useState } from 'react';
import { Lock, Send, Loader2 } from 'lucide-react';
import { useReownWallet } from '@/hooks/useReownWallet';
import { FhenixService } from '@/lib/fhenix';
import { Contract } from 'ethers';
import { EncryptedAuctionABI } from '@/lib/abis';

interface EncryptedBidFormProps {
  poolId: string;
  contractAddress: string;
}

export function EncryptedBidForm({ poolId, contractAddress }: EncryptedBidFormProps) {
  const { provider, isConnected } = useReownWallet();
  const [amount, setAmount] = useState('');
  const [isEncrypting, setIsEncrypting] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!provider || !amount) return;

    try {
      setIsEncrypting(true);

      // 1. Initialize Fhenix Client (mocked on Sepolia)
      const client = await FhenixService.getInstance(provider);

      // 2. Encrypt Amount
      const encryptedAmount = await client.encrypt(Number(amount), 'uint128');
      setIsEncrypting(false);
      setIsSubmitting(true);

      // 3. Submit Transaction
      const signer = await provider.getSigner();
      const contract = new Contract(contractAddress, EncryptedAuctionABI, signer);

      // Get pool currencies from config
      const { CONTRACTS } = await import('@/lib/config');

      // Create PoolKey tuple (must be array, not object)
      const poolKey = [
        CONTRACTS.testPool.currency0,
        CONTRACTS.testPool.currency1,
        3000,
        60,
        CONTRACTS.launchGuardHook
      ];

      // encryptedAmount already contains the InEuint128 struct from FhenixService
      const tx = await contract.submitBid(poolKey, encryptedAmount);
      await tx.wait();

      alert('Bid submitted successfully! 🎉');
      setAmount('');
    } catch (error: any) {
      console.error('Error submitting bid:', error);
      const message = error?.reason || error?.message || 'Failed to submit bid';
      alert(`Error: ${message}`);
    } finally {
      setIsEncrypting(false);
      setIsSubmitting(false);
    }
  };

  if (!isConnected) {
    return (
      <div className="p-6 rounded-2xl bg-white/5 border border-white/10 text-center">
        <Lock className="w-12 h-12 text-white/20 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-white mb-2">Connect Wallet to Bid</h3>
        <p className="text-white/60">You need to connect your wallet to submit encrypted bids.</p>
      </div>
    );
  }

  return (
    <div className="p-6 rounded-2xl bg-gradient-to-b from-white/10 to-white/5 border border-white/10 backdrop-blur-sm">
      <div className="flex items-center gap-3 mb-6">
        <div className="p-2 bg-purple-500/20 rounded-lg">
          <Lock className="w-5 h-5 text-purple-400" />
        </div>
        <div>
          <h3 className="text-lg font-semibold text-white">Submit Encrypted Bid</h3>
          <p className="text-sm text-white/60">Your bid amount will be hidden on-chain</p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-white/80 mb-2">
            Bid Amount (ETH)
          </label>
          <div className="relative">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.0"
              step="0.0001"
              min="0"
              className="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-purple-500/50 transition-all"
            />
            <span className="absolute right-4 top-1/2 -translate-y-1/2 text-sm text-white/40">
              ETH
            </span>
          </div>
        </div>

        <button
          type="submit"
          disabled={!amount || isEncrypting || isSubmitting}
          className={`
            w-full flex items-center justify-center gap-2 py-3 rounded-xl font-medium transition-all
            ${!amount || isEncrypting || isSubmitting
              ? 'bg-white/10 text-white/40 cursor-not-allowed'
              : 'bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 text-white shadow-lg shadow-purple-500/20'
            }
          `}
        >
          {isEncrypting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              Encrypting...
            </>
          ) : isSubmitting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              Submitting...
            </>
          ) : (
            <>
              <Send className="w-4 h-4" />
              Submit Encrypted Bid
            </>
          )}
        </button>
      </form>
    </div>
  );
}
