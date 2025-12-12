# LaunchGuard - Anvil Local Testing Guide

## Why Anvil?

Anvil (Foundry's local testnet) works perfectly with CoFHE contracts because:
- ✅ **Built-in CoFHE mock precompiles** from `cofhe-foundry-mocks`
- ✅ **Real FHE contract calls** - `FHE.asEuint128()` works!
- ✅ **Fast local testing** - No waiting for block times
- ✅ **Free transactions** - Unlimited gas
- ✅ **Frontend integration** - Connect MetaMask to `http://localhost:8545`

## Quick Start

### 1. Start Anvil

```bash
# Terminal 1: Start Anvil with CoFHE support
anvil --block-time 2
```

This starts a local chain at `http://127.0.0.1:8545` with:
- Chain ID: 31337
- 10 pre-funded accounts (each with 10,000 ETH)
- 2 second block time

### 2. Deploy Contracts to Anvil

```bash
# Terminal 2: Deploy LaunchGuard system
source .env
forge script script/DeployLaunchGuardAVS.s.sol:DeployLaunchGuardAVS \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  -vv
```

Save the deployed addresses from the output!

### 3. Create a Pool and Auction

```bash
# Update .env with Anvil addresses (from step 2)
# Then create pool
forge script script/CreateTestPool.s.sol:CreateTestPool \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  -vv

# Create auction
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  -vv
```

### 4. Submit Bids

#### Option A: Using TypeScript Script

```bash
# Update .env with RPC_URL=http://127.0.0.1:8545
npx ts-node scripts/submitBidMock.ts 0.05
```

#### Option B: Using Frontend

1. **Update frontend config** to point to Anvil:
```typescript
// frontend/lib/config.ts
export const CURRENT_NETWORK = {
  chainId: 31337,
  name: 'Anvil Local',
  rpcUrl: 'http://127.0.0.1:8545',
  // ... update contract addresses from deployment
}
```

2. **Add Anvil to MetaMask**:
   - Network Name: Anvil Local
   - RPC URL: `http://127.0.0.1:8545`
   - Chain ID: `31337`
   - Currency Symbol: `ETH`

3. **Import an Anvil account** to MetaMask:
```
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

4. **Start frontend** and submit bids!

### 5. Run AVS Operator

```bash
# Terminal 3: Run operator to settle auctions
cd operator
pnpm start
```

The operator will:
- Listen for settlement tasks
- "Decrypt" bids (read plaintext on Anvil's CoFHE mocks)
- Rank and submit winners

## Testing the Full Flow

### Step-by-Step

1. **Deploy** (2-3 minutes):
   ```bash
   anvil & # Start in background
   forge script script/DeployLaunchGuardAVS.s.sol:DeployLaunchGuardAVS \
     --rpc-url http://127.0.0.1:8545 --broadcast -vv
   ```

2. **Create Pool & Auction** (1 minute):
   ```bash
   forge script script/CreateTestPool.s.sol:CreateTestPool \
     --rpc-url http://127.0.0.1:8545 --broadcast -vv
   forge script script/CreateAuction.s.sol:CreateAuction \
     --rpc-url http://127.0.0.1:8545 --broadcast -vv
   ```

3. **Submit Multiple Bids** (1 minute):
   ```bash
   # Bid 1: 0.05 ETH
   npx ts-node scripts/submitBidMock.ts 0.05

   # Bid 2: 0.08 ETH (use different account)
   npx ts-node scripts/submitBidMock.ts 0.08

   # Bid 3: 0.03 ETH (use different account)
   npx ts-node scripts/submitBidMock.ts 0.03
   ```

4. **Wait for Auction to End** (based on auction duration)

5. **Create Settlement Task**:
   ```bash
   cast send $ENCRYPTION_AUCTION \
     "createSettlementTask((address,address,uint24,int24,address))" \
     "($CURRENCY0,$CURRENCY1,3000,60,$LAUNCHGUARD_HOOK)" \
     --rpc-url http://127.0.0.1:8545 \
     --private-key $PRIVATE_KEY
   ```

6. **Watch Operator Process** - Operator automatically:
   - Detects task
   - Fetches encrypted bids
   - Decrypts (using CoFHE mocks)
   - Ranks by amount
   - Submits winners

7. **Check Winners**:
   ```bash
   cast call $ENCRYPTION_AUCTION \
     "isWinner(bytes32,address)(bool)" \
     <POOL_ID> \
     <BIDDER_ADDRESS> \
     --rpc-url http://127.0.0.1:8545
   ```

## Advantages of Anvil Testing

### vs Sepolia:
- ✅ **CoFHE works!** - `FHE.asEuint128()` doesn't fail
- ✅ **Instant transactions** - No waiting for blocks
- ✅ **Free** - No test ETH needed
- ✅ **Reset anytime** - `pkill anvil && anvil`
- ✅ **Perfect for development** - Rapid iteration

### vs Production (Fhenix):
- ⚠️ **Mock FHE** - Not real threshold decryption
- ⚠️ **No Uniswap v4** - Need to deploy your own PoolManager
- ✅ **Same contract code** - Exact same Solidity
- ✅ **Full testing** - Test entire flow locally

## Common Commands

### Check Auction Status
```bash
cast call $ENCRYPTION_AUCTION \
  "getAuctionConfig((address,address,uint24,int24,address))" \
  "($CURRENCY0,$CURRENCY1,3000,60,$LAUNCHGUARD_HOOK)" \
  --rpc-url http://127.0.0.1:8545
```

### Get All Bidders
```bash
cast call $ENCRYPTION_AUCTION \
  "getBidders((address,address,uint24,int24,address))(address[])" \
  "($CURRENCY0,$CURRENCY1,3000,60,$LAUNCHGUARD_HOOK)" \
  --rpc-url http://127.0.0.1:8545
```

### Fast-Forward Time (if needed)
```bash
# Increase time by 1 hour (3600 seconds)
cast rpc evm_increaseTime 3600 --rpc-url http://127.0.0.1:8545
cast rpc evm_mine --rpc-url http://127.0.0.1:8545
```

## Troubleshooting

### "Connection refused"
- Make sure Anvil is running: `anvil --block-time 2`
- Check port 8545 is not in use: `lsof -i :8545`

### "Nonce too high"
- Reset MetaMask account: Settings → Advanced → Clear activity tab data

### "Transaction reverted"
- Check auction is active and not ended
- Verify you haven't already bid
- Make sure account isn't blacklisted

## Next Steps

Once everything works on Anvil:
1. ✅ **Full local testing** complete
2. 🎯 **Deploy to Sepolia** - For live testnet (without real FHE)
3. 🚀 **Deploy to production** - When CoFHE is available on mainnet/L2s

---

**Anvil = Perfect for rapid development and testing with CoFHE!**
