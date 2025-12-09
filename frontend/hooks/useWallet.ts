import { useState, useEffect, useCallback } from 'react';
import { BrowserProvider, JsonRpcSigner } from 'ethers';
import { CURRENT_NETWORK } from '../lib/config';

export interface WalletState {
  address: string | null;
  chainId: number | null;
  isConnected: boolean;
  isConnecting: boolean;
  provider: BrowserProvider | null;
  signer: JsonRpcSigner | null;
  isCorrectNetwork: boolean;
}

export function useWallet() {
  const [state, setState] = useState<WalletState>({
    address: null,
    chainId: null,
    isConnected: false,
    isConnecting: true,
    provider: null,
    signer: null,
    isCorrectNetwork: false,
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

      const chainId = Number(network.chainId);
      const isCorrectNetwork = chainId === CURRENT_NETWORK.chainId;

      setState({
        address: accounts[0],
        chainId,
        isConnected: true,
        isConnecting: false,
        provider,
        signer,
        isCorrectNetwork,
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
            isCorrectNetwork: false,
          });
        }
      });
    } else {
      setState(prev => ({ ...prev, isConnecting: false }));
    }
  }, [connect]);

  const switchToCorrectNetwork = useCallback(async () => {
    if (!window.ethereum) return;

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${CURRENT_NETWORK.chainId.toString(16)}` }],
      });
    } catch (error: any) {
      // Chain doesn't exist, add it
      if (error.code === 4902) {
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: `0x${CURRENT_NETWORK.chainId.toString(16)}`,
              chainName: CURRENT_NETWORK.name,
              rpcUrls: [CURRENT_NETWORK.rpcUrl],
              blockExplorerUrls: CURRENT_NETWORK.explorerUrl ? [CURRENT_NETWORK.explorerUrl] : undefined,
            }],
          });
        } catch (addError) {
          console.error('Failed to add network:', addError);
        }
      } else {
        console.error('Failed to switch network:', error);
      }
    }
  }, []);

  return { ...state, connect, switchToCorrectNetwork };
}
