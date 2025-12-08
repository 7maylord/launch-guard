import { BrowserProvider } from 'ethers';
// Remove static import
// import { FhenixClient } from 'fhenixjs';

export class FhenixService {
  private static instance: any | null = null;
  private static initializationPromise: Promise<any> | null = null;

  static async getInstance(provider: BrowserProvider): Promise<any> {
    if (this.instance) return this.instance;

    if (this.initializationPromise) return this.initializationPromise;

    this.initializationPromise = (async () => {
      try {
        // Mock Fhenix Client for now to bypass build issues
        // const { FhenixClient } = await import('fhenixjs');
        // const client = new FhenixClient({ provider: provider as any });
        
        const client = {
          encrypt: async (amount: number, type: string) => {
            console.log('Mock encrypting:', amount, type);
            return {
              data: '0x' + amount.toString(16).padStart(64, '0') // Mock encrypted data
            };
          }
        };
        
        this.instance = client;
        return client;
      } catch (error) {
        this.initializationPromise = null;
        throw error;
      }
    })();

    return this.initializationPromise;
  }


  static async encrypt(amount: number, type: 'uint8' | 'uint16' | 'uint32' | 'uint128' = 'uint128') {
    if (!this.instance) throw new Error('Fhenix client not initialized');
    
    // Note: In a real app, you'd handle the different types properly
    // This is a simplified wrapper
    return this.instance.encrypt(amount, type as any);
  }
}
