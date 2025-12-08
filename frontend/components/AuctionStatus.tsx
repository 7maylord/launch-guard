import { Clock, Users, Trophy } from 'lucide-react';

interface AuctionStatusProps {
  endTime: number;
  totalBids: number;
  minBid: string;
  isActive: boolean;
}

export function AuctionStatus({ endTime, totalBids, minBid, isActive }: AuctionStatusProps) {
  const timeLeft = Math.max(0, endTime - Date.now() / 1000);
  const hours = Math.floor(timeLeft / 3600);
  const minutes = Math.floor((timeLeft % 3600) / 60);

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
      <div className="p-4 rounded-xl bg-white/5 border border-white/10 backdrop-blur-sm">
        <div className="flex items-center gap-3 mb-2">
          <div className="p-2 bg-blue-500/20 rounded-lg">
            <Clock className="w-4 h-4 text-blue-400" />
          </div>
          <span className="text-sm font-medium text-white/60">Time Remaining</span>
        </div>
        <div className="text-2xl font-bold text-white">
          {isActive ? `${hours}h ${minutes}m` : 'Ended'}
        </div>
      </div>

      <div className="p-4 rounded-xl bg-white/5 border border-white/10 backdrop-blur-sm">
        <div className="flex items-center gap-3 mb-2">
          <div className="p-2 bg-green-500/20 rounded-lg">
            <Users className="w-4 h-4 text-green-400" />
          </div>
          <span className="text-sm font-medium text-white/60">Total Bids</span>
        </div>
        <div className="text-2xl font-bold text-white">
          {totalBids}
        </div>
      </div>

      <div className="p-4 rounded-xl bg-white/5 border border-white/10 backdrop-blur-sm">
        <div className="flex items-center gap-3 mb-2">
          <div className="p-2 bg-yellow-500/20 rounded-lg">
            <Trophy className="w-4 h-4 text-yellow-400" />
          </div>
          <span className="text-sm font-medium text-white/60">Min Bid</span>
        </div>
        <div className="text-2xl font-bold text-white">
          {minBid} ETH
        </div>
      </div>
    </div>
  );
}
