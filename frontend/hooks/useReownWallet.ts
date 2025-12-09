import { useState, useEffect, useCallback } from 'react';
import { BrowserProvider, JsonRpcSigner } from 'ethers';
import { useAppKitAccount, useAppKitProvider } from '@reown/appkit/react';
import { CURRENT_NETWORK } from '../lib/config';

export interface WalletState {
  address: string | null;
  chainId: number | null;
  isConnected: boolean;
  provider: BrowserProvider | null;
  signer: JsonRpcSigner | null;
  isCorrectNetwork: boolean;
}

export function useReownWallet() {
  const { address, isConnected } = useAppKitAccount();
  const { walletProvider } = useAppKitProvider('eip155');

  const [state, setState] = useState<WalletState>({
    address: null,
    chainId: null,
    isConnected: false,
    provider: null,
    signer: null,
    isCorrectNetwork: false,
  });

  useEffect(() => {
    async function updateState() {
      if (!isConnected || !walletProvider || !address) {
        setState({
          address: null,
          chainId: null,
          isConnected: false,
          provider: null,
          signer: null,
          isCorrectNetwork: false,
        });
        return;
      }

      try {
        // Create ethers provider from wallet provider
        const provider = new BrowserProvider(walletProvider as any);
        const signer = await provider.getSigner();
        const network = await provider.getNetwork();
        const currentChainId = Number(network.chainId);

        setState({
          address: address as string,
          chainId: currentChainId,
          isConnected: true,
          provider,
          signer,
          isCorrectNetwork: currentChainId === CURRENT_NETWORK.chainId,
        });
      } catch (error) {
        console.error('Error updating wallet state:', error);
      }
    }

    updateState();
  }, [isConnected, walletProvider, address]);

  return state;
}
