import { useState, useEffect, useCallback } from 'react';
import { BrowserProvider, JsonRpcSigner } from 'ethers';

export interface WalletState {
  address: string | null;
  chainId: number | null;
  isConnected: boolean;
  isConnecting: boolean;
  provider: BrowserProvider | null;
  signer: JsonRpcSigner | null;
}

export function useWallet() {
  const [state, setState] = useState<WalletState>({
    address: null,
    chainId: null,
    isConnected: false,
    isConnecting: true,
    provider: null,
    signer: null,
  });

  const connect = useCallback(async () => {
    if (typeof window === 'undefined' || !window.ethereum) {
      alert('Please install MetaMask!');
      return;
    }

    setState(prev => ({ ...prev, isConnecting: true }));

    try {
      const provider = new BrowserProvider(window.ethereum);
      const accounts = await provider.send('eth_requestAccounts', []);
      const network = await provider.getNetwork();
      const signer = await provider.getSigner();

      setState({
        address: accounts[0],
        chainId: Number(network.chainId),
        isConnected: true,
        isConnecting: false,
        provider,
        signer,
      });
    } catch (error) {
      console.error('Failed to connect wallet:', error);
      setState(prev => ({ ...prev, isConnecting: false }));
    }
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined' && window.ethereum) {
      // Check if already connected
      const provider = new BrowserProvider(window.ethereum);
      provider.listAccounts().then(accounts => {
        if (accounts.length > 0) {
          connect();
        } else {
          setState(prev => ({ ...prev, isConnecting: false }));
        }
      });

      // Listen for account changes
      window.ethereum.on('accountsChanged', (accounts: string[]) => {
        if (accounts.length > 0) {
          connect();
        } else {
          setState({
            address: null,
            chainId: null,
            isConnected: false,
            isConnecting: false,
            provider: null,
            signer: null,
          });
        }
      });
    } else {
      setState(prev => ({ ...prev, isConnecting: false }));
    }
  }, [connect]);

  return { ...state, connect };
}
