import LaunchGuardHookABI from './LaunchGuardHook.json';
import EncryptedAuctionABI from './EncryptedAuction.json';

export { LaunchGuardHookABI, EncryptedAuctionABI };

// Type-safe ABI exports
export const ABIS = {
  LaunchGuardHook: LaunchGuardHookABI,
  EncryptedAuction: EncryptedAuctionABI,
} as const;
