# LaunchGuard Quick Start Guide

Run the complete LaunchGuard demo with a single command. This script will compile contracts, run tests, deploy the entire system, and simulate an auction flow.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- [Node.js](https://nodejs.org/) v18+ and pnpm installed
- Git

## One-Command Demo

```bash
./demo.sh
```

This automated script will:

1. **Compile Contracts** - Build all Solidity contracts
2. **Run Tests** - Execute the full test suite
3. **Start Anvil** - Launch local Ethereum testnet with CoFHE support
4. **Deploy AVS** - Deploy LaunchGuard EigenLayer AVS system
5. **Create Pool** - Deploy Uniswap v4 pool with LaunchGuard hook
6. **Create Auction** - Initialize encrypted auction for the pool
7. **Start Operator** - Launch AVS operator for bid decryption
8. **Simulate Bids** - Submit encrypted test bids and settle auction

## What Happens During the Demo

### Step 1-2: Compilation & Testing
The script compiles all contracts and runs the test suite to verify everything works correctly.

### Step 3: Anvil Network
Starts a local Ethereum testnet with:
- CoFHE mock precompiles (for FHE operations)
- Fast block times
- Unlimited free gas

### Step 4: AVS Deployment
Deploys the LaunchGuard AVS system:
- Service Manager
- Task Manager
- Stake Registry
- Operator Registry

### Step 5: Pool Creation
Creates a Uniswap v4 pool with:
- Test tokens (currency0 and currency1)
- LaunchGuard hook for priority trading
- 0.3% fee tier

### Step 6: Auction Setup
Initializes an encrypted auction:
- 5 minute auction duration
- 3 minute priority window
- 10 max winners
- 0.01 ETH minimum bid

### Step 7: Operator Startup
Starts the AVS operator that:
- Monitors auction end times
- Decrypts bids using threshold cryptography
- Settles auctions and determines winners

### Step 8: Bid Simulation
Submits test bids:
- 3 encrypted bids (0.05, 0.1, 0.15 ETH)
- Waits for auction to end
- Operator decrypts and settles
- Winners get priority trading access

## After the Demo

### View Deployment Info

The script generates `deployment-summary.json` with all contract addresses:

```json
{
  "network": "anvil",
  "serviceManager": "0x...",
  "taskManager": "0x...",
  "poolManager": "0x...",
  "launchGuardHook": "0x...",
  "encryptedAuction": "0x...",
  "testPool": {
    "currency0": "0x...",
    "currency1": "0x...",
    "poolKey": {...}
  }
}
```

### Operator Logs

Check operator output in `operator.log`:

```bash
tail -f operator.log
```

### Submit Additional Bids

While the auction is active:

```bash
npx ts-node scripts/submitBidCofhe.ts 0.2
```

### Interact with Contracts

Use the deployment addresses to interact via scripts or frontend:

```typescript
import { CONTRACTS } from './deployment-summary.json';

// Submit bid to auction
const tx = await auctionContract.submitBid(poolKey, encryptedAmount);
```

## Stopping the Demo

Press `Ctrl+C` to stop the script. This will:
- Stop the Anvil network
- Terminate the operator
- Clean up background processes

## Manual Testing

If you want to run steps individually:

### 1. Start Anvil
```bash
anvil --code-size-limit 50000
```

### 2. Deploy Contracts
```bash
forge script script/DeployLaunchGuardAVS.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 3. Start Operator
```bash
cd operator
pnpm start
```

### 4. Submit Bids
```bash
npx ts-node scripts/submitBidCofhe.ts 0.1
```

## Troubleshooting

### "Command not found: forge"
Install Foundry: https://book.getfoundry.sh/getting-started/installation

### "Command not found: pnpm"
Install pnpm:
```bash
npm install -g pnpm
```

### "Port 8545 already in use"
Kill existing Anvil process:
```bash
pkill -f anvil
```

### Operator won't start
Check dependencies are installed:
```bash
cd operator
pnpm install
```

### Bid submission fails
Ensure:
- Anvil is running
- Contracts are deployed
- Auction exists and is active

## Architecture Overview

### LaunchGuard Components

1. **EncryptedAuction Contract**: Manages sealed-bid auctions with FHE encryption
2. **LaunchGuardHook**: Uniswap v4 hook enforcing priority windows
3. **AVS Operator**: EigenLayer operator for threshold decryption
4. **Service/Task Managers**: Coordinate AVS operations

### How It Works

1. **Bid Submission**: Users encrypt bid amounts using CoFHE (Fully Homomorphic Encryption)
2. **Auction Period**: All bids remain encrypted and hidden on-chain
3. **Decryption**: AVS operators collaboratively decrypt using threshold cryptography
4. **Settlement**: Highest bidders become winners
5. **Priority Window**: Winners get exclusive trading access for configured duration
6. **Public Trading**: After priority window, pool opens to everyone

### Why FHE + EigenLayer?

- **No Front-Running**: Encrypted bids prevent MEV attacks
- **Fair Discovery**: All participants bid without seeing others' amounts
- **Decentralized Settlement**: EigenLayer AVS operators handle decryption trustlessly
- **Priority Access**: Winners get fair advantage without sniping

## Next Steps

- Review [src/](src/) for implementation details
- Check [operator/src/](operator/src/) for AVS operator logic
- Explore [frontend/](frontend/) for UI integration
- Read [ANVIL_TESTING_GUIDE.md](ANVIL_TESTING_GUIDE.md) for detailed testing instructions

## Production Deployment

This demo uses Anvil for local testing. For production:

1. **Wait for CoFHE on mainnet**: CoFHE precompiles need to be available
2. **Deploy on Uniswap v4 network**: Must have both Uniswap v4 and CoFHE
3. **Register AVS operators**: Set up EigenLayer operator infrastructure
4. **Configure parameters**: Adjust auction timing, fees, and limits

## Resources

- [Uniswap v4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [EigenLayer AVS Guide](https://docs.eigenlayer.xyz/eigenlayer/avs-guides/avs-developer-guide)
- [CoFHE Contracts](https://github.com/FhenixProtocol/fhenix-contracts)
- [Foundry Book](https://book.getfoundry.sh/)

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review logs in `operator.log`
3. Verify Anvil is running with `ps aux | grep anvil`
4. Ensure all dependencies are installed

---

**Happy Testing!** 🚀

For questions or contributions, open an issue on the repository.
