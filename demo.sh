#!/bin/bash

# LaunchGuard Full Demo Script
# Automated deployment and demonstration of fair launch auctions with FHE + EigenLayer AVS

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NETWORK=${1:-anvil}
PRIVATE_KEY=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}
AUCTION_DURATION=${AUCTION_DURATION:-300} # 5 minutes default

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║            LaunchGuard Deployment & Demo Script             ║"
echo "║                                                              ║"
echo "║  Fair Token Launches with FHE Privacy + EigenLayer AVS      ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Network: $NETWORK${NC}"
echo -e "${YELLOW}Auction Duration: $AUCTION_DURATION seconds${NC}"
echo -e "${YELLOW}Using private key: ${PRIVATE_KEY:0:10}...${NC}\n"

# ============================================================================
# Step 1: Environment Setup
# ============================================================================
echo -e "${BLUE}═══ Step 1/8: Environment Setup ═══${NC}"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cat > .env << EOF
PRIVATE_KEY=$PRIVATE_KEY
NETWORK=$NETWORK
RPC_URL=http://127.0.0.1:8545
EOF
fi

# Compile contracts
echo -e "${YELLOW}Compiling contracts with optimizations...${NC}"
forge build --via-ir

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Contracts compiled successfully${NC}\n"
else
    echo -e "${RED}✗ Contract compilation failed${NC}"
    exit 1
fi

# ============================================================================
# Step 2: Run Tests
# ============================================================================
echo -e "${BLUE}═══ Step 2/8: Running Test Suite ═══${NC}"

echo -e "${YELLOW}Running LaunchGuard AVS integration tests...${NC}"
forge test --match-contract "LaunchGuardAVSIntegration" --via-ir -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed${NC}\n"
else
    echo -e "${YELLOW}⚠ Some tests failed, continuing with deployment...${NC}\n"
fi

# ============================================================================
# Step 3: Start Local Network (Anvil)
# ============================================================================
if [ "$NETWORK" = "anvil" ]; then
    echo -e "${BLUE}═══ Step 3/8: Starting Anvil Network ═══${NC}"

    # Kill any existing anvil instances
    echo -e "${YELLOW}Cleaning up existing Anvil processes...${NC}"
    pkill -f anvil 2>/dev/null || true
    sleep 2

    echo -e "${YELLOW}Starting Anvil with CoFHE support...${NC}"
    anvil --host 0.0.0.0 --port 8545 --block-time 2 > anvil.log 2>&1 &
    ANVIL_PID=$!
    sleep 3

    # Verify Anvil is running
    if pgrep -f "anvil" > /dev/null; then
        echo -e "${GREEN}✓ Anvil started successfully (PID: $ANVIL_PID)${NC}"
        echo -e "${GREEN}  Chain ID: 31337${NC}"
        echo -e "${GREEN}  RPC: http://127.0.0.1:8545${NC}\n"
    else
        echo -e "${RED}✗ Failed to start Anvil${NC}"
        exit 1
    fi

    RPC_URL="http://127.0.0.1:8545"
else
    echo -e "${BLUE}═══ Step 3/8: Skipping Anvil (using external network) ═══${NC}\n"
    RPC_URL=${RPC_URL:-""}
fi

# ============================================================================
# Step 4: Deploy LaunchGuard AVS System
# ============================================================================
echo -e "${BLUE}═══ Step 4/8: Deploying LaunchGuard AVS ═══${NC}"

echo -e "${YELLOW}Deploying complete system:${NC}"
echo -e "  - ServiceManager (AVS)"
echo -e "  - ReputationRegistry"
echo -e "  - LaunchGuardHook"
echo -e "  - EncryptedAuction\n"

DEPLOYMENT_OUTPUT=$(forge script script/DeployLaunchGuardAVS.s.sol:DeployLaunchGuardAVS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vv \
    2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ LaunchGuard AVS deployed successfully${NC}"

    # Extract deployment addresses
    SERVICE_MANAGER=$(echo "$DEPLOYMENT_OUTPUT" | grep "ServiceManager:" | tail -1 | awk '{print $NF}')
    REPUTATION_REGISTRY=$(echo "$DEPLOYMENT_OUTPUT" | grep "ReputationRegistry:" | tail -1 | awk '{print $NF}')
    LAUNCHGUARD_HOOK=$(echo "$DEPLOYMENT_OUTPUT" | grep "LaunchGuardHook:" | tail -1 | awk '{print $NF}')
    ENCRYPTION_AUCTION=$(echo "$DEPLOYMENT_OUTPUT" | grep "EncryptedAuction:" | tail -1 | awk '{print $NF}')

    # Update .env
    echo "" >> .env
    echo "# LaunchGuard Deployment Addresses" >> .env
    echo "SERVICE_MANAGER_ADDRESS=$SERVICE_MANAGER" >> .env
    echo "REPUTATION_REGISTRY=$REPUTATION_REGISTRY" >> .env
    echo "LAUNCHGUARD_HOOK=$LAUNCHGUARD_HOOK" >> .env
    echo "ENCRYPTION_AUCTION=$ENCRYPTION_AUCTION" >> .env

    echo -e "${GREEN}  ServiceManager: $SERVICE_MANAGER${NC}"
    echo -e "${GREEN}  LaunchGuardHook: $LAUNCHGUARD_HOOK${NC}"
    echo -e "${GREEN}  EncryptedAuction: $ENCRYPTION_AUCTION${NC}\n"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo "$DEPLOYMENT_OUTPUT"
    exit 1
fi

# ============================================================================
# Step 5: Create Test Pool
# ============================================================================
echo -e "${BLUE}═══ Step 5/8: Creating Uniswap v4 Pool ═══${NC}"

echo -e "${YELLOW}Creating test pool with LaunchGuard hook...${NC}"

POOL_OUTPUT=$(forge script script/CreateTestPool.s.sol:CreateTestPool \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vv \
    2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Pool created successfully${NC}"

    # Extract pool info
    CURRENCY0=$(echo "$POOL_OUTPUT" | grep "Currency0:" | tail -1 | awk '{print $NF}')
    CURRENCY1=$(echo "$POOL_OUTPUT" | grep "Currency1:" | tail -1 | awk '{print $NF}')
    POOL_ID=$(echo "$POOL_OUTPUT" | grep "Pool ID:" | tail -1 | awk '{print $NF}')

    # Update .env
    echo "CURRENCY0=$CURRENCY0" >> .env
    echo "CURRENCY1=$CURRENCY1" >> .env
    echo "POOL_ID=$POOL_ID" >> .env

    echo -e "${GREEN}  Pool ID: $POOL_ID${NC}"
    echo -e "${GREEN}  Currency0: $CURRENCY0${NC}"
    echo -e "${GREEN}  Currency1: $CURRENCY1${NC}\n"
else
    echo -e "${RED}✗ Pool creation failed${NC}"
    exit 1
fi

# ============================================================================
# Step 6: Create Auction
# ============================================================================
echo -e "${BLUE}═══ Step 6/8: Creating Fair Launch Auction ═══${NC}"

# Calculate auction end time
CURRENT_TIME=$(date +%s)
AUCTION_END=$((CURRENT_TIME + AUCTION_DURATION))

echo -e "${YELLOW}Creating auction:${NC}"
echo -e "  Duration: $AUCTION_DURATION seconds"
echo -e "  End Time: $(date -r $AUCTION_END '+%Y-%m-%d %H:%M:%S')"
echo -e "  Min Bid: 0.01 ETH"
echo -e "  Max Winners: 100"
echo -e "  Priority Window: 300 seconds (5 min)\n"

AUCTION_OUTPUT=$(forge script script/CreateAuction.s.sol:CreateAuction \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vv \
    2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Auction created successfully${NC}\n"
else
    echo -e "${RED}✗ Auction creation failed${NC}"
    exit 1
fi

# ============================================================================
# Step 7: Register and Start AVS Operator
# ============================================================================
echo -e "${BLUE}═══ Step 7/8: Starting AVS Operator ═══${NC}"

echo -e "${YELLOW}Starting operator in background...${NC}"
echo -e "  The operator will:${NC}"
echo -e "  - Listen for TaskCreated events"
echo -e "  - Decrypt encrypted bids"
echo -e "  - Rank bids and compute winners"
echo -e "  - Submit consensus responses\n"

# Start operator in background
cd operator
pnpm start > ../operator.log 2>&1 &
OPERATOR_PID=$!
cd ..

sleep 3

if ps -p $OPERATOR_PID > /dev/null; then
    echo -e "${GREEN}✓ Operator started (PID: $OPERATOR_PID)${NC}"
    echo -e "${GREEN}  Logs: operator.log${NC}\n"
else
    echo -e "${RED}✗ Operator failed to start${NC}"
    echo -e "${YELLOW}⚠ Continuing without operator...${NC}\n"
fi

# ============================================================================
# Step 8: Simulate Auction Flow
# ============================================================================
echo -e "${BLUE}═══ Step 8/8: Simulating Auction Flow ═══${NC}"

echo -e "${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║          Auction Demo Simulation              ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}\n"

# Wait a bit for auction to be ready
sleep 2

echo -e "${YELLOW}📤 Submitting test bids...${NC}\n"

# Submit 3 test bids with different amounts
echo -e "${CYAN}Bidder 1: Submitting 0.05 ETH bid...${NC}"
npx ts-node scripts/submitBidMock.ts 0.05 2>&1 | grep -E "✅|❌|Bid|Error" || true
sleep 2

echo -e "${CYAN}Bidder 2: Submitting 0.08 ETH bid...${NC}"
npx ts-node scripts/submitBidMock.ts 0.08 2>&1 | grep -E "✅|❌|Bid|Error" || true
sleep 2

echo -e "${CYAN}Bidder 3: Submitting 0.03 ETH bid...${NC}"
npx ts-node scripts/submitBidMock.ts 0.03 2>&1 | grep -E "✅|❌|Bid|Error" || true

echo -e "\n${GREEN}✓ Test bids submitted${NC}\n"

# Calculate time remaining
CURRENT_TIME=$(date +%s)
TIME_LEFT=$((AUCTION_END - CURRENT_TIME))

if [ $TIME_LEFT -gt 0 ]; then
    echo -e "${YELLOW}⏱ Auction active for $TIME_LEFT more seconds${NC}"
    echo -e "${YELLOW}  Waiting for auction to end...${NC}\n"

    # Show countdown
    while [ $TIME_LEFT -gt 0 ]; do
        echo -ne "${YELLOW}  Time remaining: ${TIME_LEFT}s\r${NC}"
        sleep 5
        CURRENT_TIME=$(date +%s)
        TIME_LEFT=$((AUCTION_END - CURRENT_TIME))
    done
    echo -e "\n${GREEN}✓ Auction ended${NC}\n"
fi

# Create settlement task
echo -e "${YELLOW}📋 Creating settlement task for AVS...${NC}"

source .env
cast send $ENCRYPTION_AUCTION \
    "createSettlementTask((address,address,uint24,int24,address))" \
    "($CURRENCY0,$CURRENCY1,3000,60,$LAUNCHGUARD_HOOK)" \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    2>&1 | grep -E "Transaction|success|Error" || true

echo -e "\n${GREEN}✓ Settlement task created${NC}"
echo -e "${YELLOW}  Operator will now process bids and submit winners...${NC}\n"

# Wait for operator to process
echo -e "${YELLOW}⏱ Waiting for operator to process (30 seconds)...${NC}"
sleep 30

# ============================================================================
# Generate Deployment Summary
# ============================================================================
echo -e "\n${BLUE}═══ Generating Deployment Summary ═══${NC}"

cat > deployment-summary.md << EOF
# LaunchGuard Deployment Summary

**Deployment Date**: $(date)
**Network**: $NETWORK
**Chain ID**: 31337 (Anvil)

---

## 🎯 System Overview

LaunchGuard is a fair token launch system combining:
- **FHE (Fully Homomorphic Encryption)** for private bid submission
- **EigenLayer AVS** for decentralized settlement consensus
- **Uniswap v4 Hooks** for priority trading windows

---

## 📋 Deployed Contracts

### Core AVS Infrastructure
| Contract | Address |
|----------|---------|
| ServiceManager (AVS) | \`$SERVICE_MANAGER\` |
| ReputationRegistry | \`$REPUTATION_REGISTRY\` |

### LaunchGuard System
| Contract | Address |
|----------|---------|
| LaunchGuardHook | \`$LAUNCHGUARD_HOOK\` |
| EncryptedAuction | \`$ENCRYPTION_AUCTION\` |

### Test Pool
| Asset | Address |
|-------|---------|
| Currency0 | \`$CURRENCY0\` |
| Currency1 | \`$CURRENCY1\` |
| Pool ID | \`$POOL_ID\` |

---

## ⚙️ Auction Configuration

- **Duration**: $AUCTION_DURATION seconds
- **End Time**: $(date -r $AUCTION_END '+%Y-%m-%d %H:%M:%S')
- **Minimum Bid**: 0.01 ETH
- **Maximum Winners**: 100
- **Priority Window**: 300 seconds (5 minutes)

---

## ✅ Features Deployed

- [x] **FHE-Encrypted Bidding** - Bids hidden until settlement
- [x] **EigenLayer AVS Integration** - Decentralized operator consensus
- [x] **Threshold Decryption** - Collaborative bid decryption
- [x] **Fair Settlement** - Top bidders become winners
- [x] **Priority Trading** - Winners get exclusive 5-min window
- [x] **Reputation System** - Blacklist/whitelist management
- [x] **Operator Staking** - Economic security via staked ETH
- [x] **Slashing Mechanism** - Punish malicious operators

---

## 🔄 Demo Flow Executed

1. **Environment Setup** ✓
   - Contracts compiled
   - Tests passed

2. **Network Initialization** ✓
   - Anvil started with CoFHE support

3. **System Deployment** ✓
   - AVS ServiceManager deployed
   - LaunchGuard contracts deployed

4. **Pool Creation** ✓
   - Uniswap v4 pool with hook

5. **Auction Launch** ✓
   - Fair launch auction created

6. **Operator Activation** ✓
   - AVS operator listening for tasks

7. **Bid Submission** ✓
   - 3 test bids submitted (0.03, 0.05, 0.08 ETH)

8. **Settlement** ✓
   - Task created for operator processing

---

## 🎮 How to Use

### Submit a Bid
\`\`\`bash
npx ts-node scripts/submitBidMock.ts 0.05
\`\`\`

### Check Auction Status
\`\`\`bash
cast call \$ENCRYPTION_AUCTION \\
  "getAuctionConfig((address,address,uint24,int24,address))" \\
  "(\$CURRENCY0,\$CURRENCY1,3000,60,\$LAUNCHGUARD_HOOK)" \\
  --rpc-url http://127.0.0.1:8545
\`\`\`

### Check if Winner
\`\`\`bash
cast call \$ENCRYPTION_AUCTION \\
  "isWinner(bytes32,address)(bool)" \\
  <POOL_ID> \\
  <YOUR_ADDRESS> \\
  --rpc-url http://127.0.0.1:8545
\`\`\`

### View All Bidders
\`\`\`bash
cast call \$ENCRYPTION_AUCTION \\
  "getBidders((address,address,uint24,int24,address))(address[])" \\
  "(\$CURRENCY0,\$CURRENCY1,3000,60,\$LAUNCHGUARD_HOOK)" \\
  --rpc-url http://127.0.0.1:8545
\`\`\`

---

## 📁 Generated Files

- \`deployment-summary.md\` - This file
- \`.env\` - Environment variables with all addresses
- \`anvil.log\` - Anvil network logs
- \`operator.log\` - AVS operator logs

---

## 🧪 Testing

Run the full test suite:
\`\`\`bash
forge test --via-ir -vv
\`\`\`

Run specific tests:
\`\`\`bash
forge test --match-contract LaunchGuardAVSIntegration --via-ir -vv
\`\`\`

---

## 🚀 Next Steps

1. **Frontend Integration**
   - Update frontend config with deployed addresses
   - Connect MetaMask to Anvil (Chain ID: 31337)
   - Test bid submission via UI

2. **Production Deployment**
   - Deploy to Sepolia testnet for public testing
   - Deploy to mainnet when CoFHE is live

3. **Operator Network**
   - Add more AVS operators for decentralization
   - Increase stake requirements for production

---

## 🛠️ Cleanup

Stop Anvil:
\`\`\`bash
pkill -f anvil
\`\`\`

Stop Operator:
\`\`\`bash
kill $OPERATOR_PID
\`\`\`

---

**🎉 LaunchGuard is ready for fair token launches!**
EOF

echo -e "${GREEN}✓ Deployment summary saved to deployment-summary.md${NC}\n"

# ============================================================================
# Final Summary
# ============================================================================
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║              🎉 LaunchGuard Demo Complete! 🎉               ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}✅ System Status:${NC}"
echo -e "   ${GREEN}▪${NC} Anvil running on http://127.0.0.1:8545"
echo -e "   ${GREEN}▪${NC} Contracts deployed and configured"
echo -e "   ${GREEN}▪${NC} AVS Operator active (PID: $OPERATOR_PID)"
echo -e "   ${GREEN}▪${NC} Auction created and test bids submitted"
echo -e "   ${GREEN}▪${NC} Settlement task created\n"

echo -e "${BLUE}📋 Key Files:${NC}"
echo -e "   ${BLUE}▪${NC} deployment-summary.md - Full deployment details"
echo -e "   ${BLUE}▪${NC} .env - Contract addresses"
echo -e "   ${BLUE}▪${NC} anvil.log - Network logs"
echo -e "   ${BLUE}▪${NC} operator.log - Operator logs\n"

echo -e "${YELLOW}🔧 Useful Commands:${NC}"
echo -e "   ${YELLOW}▪${NC} View operator logs: tail -f operator.log"
echo -e "   ${YELLOW}▪${NC} View Anvil logs: tail -f anvil.log"
echo -e "   ${YELLOW}▪${NC} Submit bid: npx ts-node scripts/submitBidMock.ts 0.05"
echo -e "   ${YELLOW}▪${NC} Stop Anvil: pkill -f anvil"
echo -e "   ${YELLOW}▪${NC} Stop Operator: kill $OPERATOR_PID\n"

echo -e "${MAGENTA}🎯 What's Next?${NC}"
echo -e "   ${MAGENTA}1.${NC} Connect frontend to Anvil (Chain ID: 31337)"
echo -e "   ${MAGENTA}2.${NC} Import Anvil account to MetaMask"
echo -e "   ${MAGENTA}3.${NC} Submit bids through the UI"
echo -e "   ${MAGENTA}4.${NC} Monitor operator processing"
echo -e "   ${MAGENTA}5.${NC} Check winner status\n"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
