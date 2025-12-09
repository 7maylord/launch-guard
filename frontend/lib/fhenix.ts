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
            // Return InEuint128-compatible struct for Sepolia testing
            // In production with actual Fhenix, this would return real encrypted data
            // Convert amount to integer to avoid decimal hex conversion
            const amountInt = Math.floor(amount * 1e18); // Convert to wei as integer
            return {
              ctHash: BigInt(amountInt), // Mock hash as BigInt
              securityZone: 0, // Default security zone
              utype: 7, // euint128 type identifier
              signature: '0x' // Empty signature for mock
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
