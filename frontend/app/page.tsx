'use client';

import { Navbar } from '@/components/Navbar';
import { EncryptedBidForm } from '@/components/EncryptedBidForm';
import { AuctionStatus } from '@/components/AuctionStatus';

export default function Home() {
  // Mock data - in production this would come from the contract
  const auctionData = {
    poolId: '0x123...',
    contractAddress: '0xabc...',
    endTime: Date.now() / 1000 + 3600, // 1 hour from now
    totalBids: 42,
    minBid: '0.1',
    isActive: true
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

          <AuctionStatus 
            endTime={auctionData.endTime}
            totalBids={auctionData.totalBids}
            minBid={auctionData.minBid}
            isActive={auctionData.isActive}
          />

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <EncryptedBidForm 
              poolId={auctionData.poolId}
              contractAddress={auctionData.contractAddress}
            />

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
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
