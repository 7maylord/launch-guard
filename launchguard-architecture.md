# LaunchGuard - Encrypted Fair Launch Auctions

## Project Overview

**Project Name:** LaunchGuard - Encrypted Fair Launch Auctions

**Tagline:** Eliminate sniper bots and MEV extraction during token launches through encrypted Dutch auctions coordinated by EigenLayer AVS operators.

**Problem Statement:**
- New token launches on DEXs are dominated by bots that snipe first liquidity positions
- Front-running bots extract maximum value from retail buyers
- Insider information asymmetry advantages sophisticated actors
- Legitimate community members and early supporters get rekt
- Projects lose control over their launch price discovery
- Auction sniping: bots watch mempool and submit higher gas to win

**Solution:**
LaunchGuard enables fair token launches through encrypted Dutch auctions where:
1. Projects auction the right to provide initial liquidity
2. Projects auction priority trading rights for first N swaps
3. All bids are encrypted using Fhenix FHE - no one can see bid amounts
4. EigenLayer AVS operators coordinate auction logic off-chain
5. Auction proceeds go to project treasury
6. Known snipers are excluded via reputation system
7. Community contributors get bid discounts

**Sponsor Integration:**

**Fhenix (VIP Sponsor):**
- All bid amounts encrypted using FHE library
- Comparison logic happens on encrypted values (FHE.gt(), FHE.lt())
- No bid sniping possible - amounts hidden until settlement
- Maintains fair price discovery while protecting privacy

**EigenLayer (Benefactor Sponsor):**
- AVS operators run auction coordination
- Validate encrypted bids off-chain
- Determine winners without revealing sensitive data
- Sequence execution across multiple blocks
- Maintain reputation scores to exclude bad actors
- Ensure censorship-resistant settlement

**Expected Impact:**
- Fair launches for new tokens without bot manipulation
- Auction proceeds create initial treasury for projects
- Community-focused launches reward genuine supporters
- Could become standard for v4 token launches
- Reduces toxic launch experiences

---

## System Architecture

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    LAUNCHGUARD SYSTEM                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────┐        ┌──────────────┐       ┌──────────────┐ │
│  │  Project    │───────▶│  Auction     │◀──────│  Bidders     │ │
│  │  (Creator)  │        │  Parameters  │       │ (Encrypted)  │ │
│  └─────────────┘        └──────────────┘       └──────────────┘ │
│                                │                        │         │
│                                │                        │         │
│                                ▼                        ▼         │
│                    ┌───────────────────────────┐                 │
│                    │   LaunchGuard Hook        │                 │
│                    │   (Uniswap v4)            │                 │
│                    │                           │                 │
│                    │  • Encrypted Bids (FHE)   │                 │
│                    │  • Auction Logic          │                 │
│                    │  • Winner Selection       │                 │
│                    │  • Priority Execution     │                 │
│                    └───────────────────────────┘                 │
│                                │                                  │
│              ┌─────────────────┼─────────────────┐              │
│              ▼                 ▼                 ▼              │
│       beforeInitialize   beforeSwap      afterSwap             │
│      (setup auction)   (enforce priority) (collect proceeds)   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐│
│  │         EigenLayer AVS Operator Network                    ││
│  │                                                             ││
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                ││
│  │  │Operator 1│  │Operator 2│  │Operator N│                ││
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘                ││
│  │       │             │             │                        ││
│  │       └─────────────┼─────────────┘                       ││
│  │                     ▼                                      ││
│  │         Consensus on Auction Results                      ││
│  │         • Decrypt bids (threshold)                        ││
│  │         • Rank bidders                                    ││
│  │         • Validate reputation                             ││
│  │         • Coordinate settlement                           ││
│  └────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐│
│  │              Fhenix FHE Encryption Layer                   ││
│  │  • Encrypt bid amounts                                     ││
│  │  • Homomorphic comparison (FHE.gt, FHE.lt)                ││
│  │  • Preserve privacy until settlement                       ││
│  │  • Threshold decryption by operators                      ││
│  └────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. Smart Contract Layer

**Core Hook Contract: `LaunchGuardHook.sol`**
- Implements Uniswap v4 BaseHook
- Manages encrypted auction state
- Handles bid submission with FHE
- Enforces priority execution windows
- Collects auction proceeds

**Supporting Contracts:**
- `EncryptedAuction.sol` - Auction logic with Fhenix FHE
- `ReputationRegistry.sol` - Track and manage bidder reputation
- `PriorityQueue.sol` - Manage priority trading windows
- `TreasuryManager.sol` - Handle auction proceeds

#### 2. Fhenix FHE Integration

**Encryption Layer:**
- All bids encrypted client-side before submission
- Server-side FHE operations for comparisons
- Threshold decryption by AVS operators
- Privacy preserved until settlement

**FHE Operations Used:**
```solidity
// Fhenix FHE library functions
FHE.asEuint64(encryptedAmount)  // Convert to encrypted uint64
FHE.gt(bid1, bid2)              // Compare encrypted bids
FHE.decrypt(encryptedBid)       // Decrypt (requires permission)
```

#### 3. EigenLayer AVS Integration

**AVS Operator Responsibilities:**
- Monitor auction state
- Validate encrypted bids
- Participate in threshold decryption
- Reach consensus on winners
- Execute settlement transactions
- Maintain reputation database
- Coordinate multi-block execution

#### 4. Frontend Application

**User Interface:**
- Project dashboard (configure auction)
- Bidding interface (encrypt & submit)
- Auction monitoring (blind - no amounts shown)
- Winner announcement
- Reputation display

---

## How It Works: Complete Flow

### Phase 1: Pre-Launch Setup

```
Project Creates Auction
        │
        ├─ Set Parameters:
        │   • Token to launch
        │   • Initial supply to auction
        │   • Auction duration
        │   • Starting price (Dutch auction)
        │   • Floor price
        │   • Number of priority swaps
        │
        ├─ Deploy Hook with Parameters
        │
        └─ Announce Launch Time
```

### Phase 2: Encrypted Bidding Period

```
Bidders Submit Encrypted Bids
        │
        ├─ Step 1: Bidder encrypts amount locally
        │   • Uses Fhenix FHE client library
        │   • Generates encrypted value
        │   • Signs transaction
        │
        ├─ Step 2: Submit to Hook Contract
        │   • Hook stores encrypted bid
        │   • No one can see actual amount
        │   • Time-locked until auction ends
        │
        ├─ Step 3: Reputation Check (AVS)
        │   • EigenLayer operators validate bidder
        │   • Known snipers rejected/penalized
        │   • Community members get discounts
        │
        └─ Result: All bids hidden, fair competition
```

### Phase 3: Auction Settlement (AVS Coordination)

```
Auction Ends → AVS Operators Coordinate
        │
        ├─ Step 1: Threshold Decryption
        │   • N of M operators decrypt bids
        │   • Consensus required (BFT)
        │   • Results computed off-chain
        │
        ├─ Step 2: Determine Winners
        │   • Rank bids by amount
        │   • Apply reputation adjustments
        │   • Select top bidders for:
        │     - LP provision rights
        │     - Priority swap rights
        │
        ├─ Step 3: Submit Settlement Tx
        │   • Operators collectively sign
        │   • Settlement posted on-chain
        │   • Winners revealed
        │
        └─ Step 4: Create Uniswap Pool
            • Initialize pool with auction price
            • Add initial liquidity from winners
            • Enable priority swap window
```

### Phase 4: Priority Trading Window

```
Pool Opens with Priority Enforcement
        │
        ├─ Priority Slot 1
        │   • Winner 1 can swap
        │   • Others blocked by hook
        │   • beforeSwap checks priority list
        │
        ├─ Priority Slot 2
        │   • Winner 2 can swap
        │   • ...
        │
        ├─ Priority Slot N
        │   • Winner N can swap
        │   • ...
        │
        └─ Public Trading Opens
            • All restrictions lifted
            • Normal Uniswap v4 pool
```

### Phase 5: Proceeds Distribution

```
Auction Complete → Distribute Proceeds
        │
        ├─ LP Auction Proceeds
        │   • Go to project treasury
        │   • Used for development/marketing
        │
        ├─ Priority Swap Proceeds
        │   • Go to project treasury
        │   • OR distributed to LP providers
        │
        └─ Reputation Updates
            • Winners get positive reputation
            • Update on-chain registry
            • Future auction discounts
```

---

## Technical Specifications

### Hook Flags Required

```solidity
uint160 constant HOOK_FLAGS = 
    Hooks.BEFORE_INITIALIZE_FLAG |     // Set up auction parameters
    Hooks.BEFORE_SWAP_FLAG |           // Enforce priority windows
    Hooks.AFTER_SWAP_FLAG;             // Collect proceeds
```

**Why These Flags:**

1. **BEFORE_INITIALIZE_FLAG**:
   - Configure auction parameters when pool is created
   - Set launch time, price parameters
   - Initialize encrypted bid storage

2. **BEFORE_SWAP_FLAG**:
   - Check if priority window is active
   - Verify swapper is on priority list
   - Reject unauthorized swaps during priority period

3. **AFTER_SWAP_FLAG**:
   - Collect auction proceeds from priority swaps
   - Route to project treasury
   - Track swap execution

---

## Smart Contract Implementation

### Core State Variables

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {FHE} from "@fhenixprotocol/contracts/FHE.sol";
import {euint64, inEuint64} from "@fhenixprotocol/contracts/FHE.sol";

contract LaunchGuardHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    
    // ===== AUCTION CONFIGURATION =====
    struct AuctionConfig {
        address projectTreasury;      // Where proceeds go
        uint256 launchTime;           // When launch happens
        uint256 auctionEndTime;       // When bidding ends
        uint256 startPrice;           // Dutch auction start
        uint256 floorPrice;           // Dutch auction floor
        uint256 lpSlotsAvailable;     // LP positions to auction
        uint256 prioritySwapSlots;    // Priority swap slots
        bool auctionFinalized;        // Has auction settled?
    }
    
    // ===== ENCRYPTED BID =====
    struct EncryptedBid {
        address bidder;               // Who submitted
        euint64 encryptedAmount;      // Encrypted bid amount (FHE)
        uint256 timestamp;            // When submitted
        BidType bidType;              // LP or Priority Swap
        bool isValid;                 // Passed reputation check
    }
    
    enum BidType {
        LP_PROVISION,     // Bid for LP rights
        PRIORITY_SWAP     // Bid for priority swap rights
    }
    
    // ===== AUCTION RESULTS (POST-SETTLEMENT) =====
    struct AuctionResults {
        address[] lpWinners;          // Winners for LP provision
        address[] swapWinners;        // Winners for priority swaps
        uint256[] lpAmounts;          // Decrypted LP bid amounts
        uint256[] swapAmounts;        // Decrypted swap bid amounts
        uint256 totalProceeds;        // Total collected
        bool settled;                 // Settlement complete
    }
    
    // ===== STATE MAPPINGS =====
    
    // Pool ID => Auction Config
    mapping(PoolId => AuctionConfig) public auctions;
    
    // Pool ID => Array of encrypted bids
    mapping(PoolId => EncryptedBid[]) public encryptedBids;
    
    // Pool ID => Auction Results (after settlement)
    mapping(PoolId => AuctionResults) public results;
    
    // Pool ID => Current priority swap index
    mapping(PoolId => uint256) public currentPriorityIndex;
    
    // Pool ID => Swap address => Has used priority
    mapping(PoolId => mapping(address => bool)) public hasUsedPriority;
    
    // ===== REPUTATION SYSTEM =====
    
    // Address => Reputation score (0-100)
    mapping(address => uint256) public reputation;
    
    // Address => Is known sniper (blacklisted)
    mapping(address => bool) public isBlacklisted;
    
    // Address => Community member (gets discounts)
    mapping(address => bool) public isCommunityMember;
    
    // ===== CONSTANTS =====
    uint256 public constant MIN_REPUTATION = 20;
    uint256 public constant COMMUNITY_DISCOUNT = 10; // 10% discount
    uint256 public constant SNIPER_PENALTY = 50;     // 50% penalty
    
    // ===== AVS OPERATOR REGISTRY =====
    mapping(address => bool) public isOperator;
    address[] public operators;
    uint256 public constant THRESHOLD = 3; // 3 of 5 operators needed
    
    // ===== EVENTS =====
    event AuctionCreated(
        PoolId indexed poolId,
        address indexed project,
        uint256 launchTime,
        uint256 lpSlots,
        uint256 swapSlots
    );
    
    event EncryptedBidSubmitted(
        PoolId indexed poolId,
        address indexed bidder,
        BidType bidType
    );
    
    event AuctionSettled(
        PoolId indexed poolId,
        uint256 totalProceeds,
        uint256 lpWinners,
        uint256 swapWinners
    );
    
    event PrioritySwapExecuted(
        PoolId indexed poolId,
        address indexed winner,
        uint256 index
    );
    
    event ReputationUpdated(
        address indexed user,
        uint256 oldScore,
        uint256 newScore
    );
    
    // ===== CONSTRUCTOR =====
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        // Initialize operators (would be set via governance)
    }
    
    // ===== HOOK OVERRIDES =====
    
    function getHookPermissions() 
        public 
        pure 
        override 
        returns (Hooks.Permissions memory) 
    {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}
```

### Key Functions

#### 1. beforeInitialize - Setup Auction

```solidity
function beforeInitialize(
    address sender,
    PoolKey calldata key,
    uint160 sqrtPriceX96,
    bytes calldata hookData
) external override returns (bytes4) {
    
    PoolId poolId = key.toId();
    
    // Decode auction parameters from hookData
    (
        address treasury,
        uint256 launchTime,
        uint256 auctionDuration,
        uint256 startPrice,
        uint256 floorPrice,
        uint256 lpSlots,
        uint256 swapSlots
    ) = abi.decode(
        hookData,
        (address, uint256, uint256, uint256, uint256, uint256, uint256)
    );
    
    // Validate parameters
    require(launchTime > block.timestamp, "Launch time must be future");
    require(startPrice > floorPrice, "Invalid price range");
    require(lpSlots > 0 && swapSlots > 0, "Must have slots");
    
    // Store auction config
    auctions[poolId] = AuctionConfig({
        projectTreasury: treasury,
        launchTime: launchTime,
        auctionEndTime: launchTime - 1 hours, // Auction ends 1hr before launch
        startPrice: startPrice,
        floorPrice: floorPrice,
        lpSlotsAvailable: lpSlots,
        prioritySwapSlots: swapSlots,
        auctionFinalized: false
    });
    
    emit AuctionCreated(
        poolId,
        sender,
        launchTime,
        lpSlots,
        swapSlots
    );
    
    return BaseHook.beforeInitialize.selector;
}
```

#### 2. Submit Encrypted Bid

```solidity
/**
 * @notice Submit encrypted bid for LP provision or priority swap
 * @param key Pool key
 * @param bidType Type of bid (LP or Priority Swap)
 * @param encryptedAmount Encrypted bid amount (Fhenix FHE)
 */
function submitBid(
    PoolKey calldata key,
    BidType bidType,
    inEuint64 calldata encryptedAmount
) external {
    PoolId poolId = key.toId();
    AuctionConfig storage auction = auctions[poolId];
    
    // Validate timing
    require(block.timestamp < auction.auctionEndTime, "Auction ended");
    require(block.timestamp < auction.launchTime, "Auction already launched");
    
    // Reputation check
    require(!isBlacklisted[msg.sender], "Bidder blacklisted");
    require(
        reputation[msg.sender] >= MIN_REPUTATION,
        "Insufficient reputation"
    );
    
    // Convert to encrypted uint64
    euint64 encBid = FHE.asEuint64(encryptedAmount);
    
    // Store encrypted bid
    encryptedBids[poolId].push(EncryptedBid({
        bidder: msg.sender,
        encryptedAmount: encBid,
        timestamp: block.timestamp,
        bidType: bidType,
        isValid: true
    }));
    
    emit EncryptedBidSubmitted(poolId, msg.sender, bidType);
}
```

#### 3. AVS Settlement Function (Called by Operators)

```solidity
/**
 * @notice Settle auction - called by AVS operators after consensus
 * @param key Pool key
 * @param lpWinners Array of LP winner addresses
 * @param swapWinners Array of priority swap winner addresses
 * @param lpAmounts Decrypted LP bid amounts
 * @param swapAmounts Decrypted swap bid amounts
 * @param operatorSignatures Signatures from threshold operators
 */
function settleAuction(
    PoolKey calldata key,
    address[] calldata lpWinners,
    address[] calldata swapWinners,
    uint256[] calldata lpAmounts,
    uint256[] calldata swapAmounts,
    bytes[] calldata operatorSignatures
) external {
    PoolId poolId = key.toId();
    AuctionConfig storage auction = auctions[poolId];
    
    // Verify auction ended
    require(block.timestamp >= auction.auctionEndTime, "Auction still active");
    require(!auction.auctionFinalized, "Already finalized");
    
    // Verify operator threshold signatures
    require(
        _verifyOperatorSignatures(poolId, lpWinners, swapWinners, operatorSignatures),
        "Insufficient operator signatures"
    );
    
    // Validate winner counts
    require(
        lpWinners.length <= auction.lpSlotsAvailable,
        "Too many LP winners"
    );
    require(
        swapWinners.length <= auction.prioritySwapSlots,
        "Too many swap winners"
    );
    
    // Calculate total proceeds
    uint256 totalProceeds = 0;
    for (uint256 i = 0; i < lpAmounts.length; i++) {
        totalProceeds += lpAmounts[i];
    }
    for (uint256 i = 0; i < swapAmounts.length; i++) {
        totalProceeds += swapAmounts[i];
    }
    
    // Store results
    results[poolId] = AuctionResults({
        lpWinners: lpWinners,
        swapWinners: swapWinners,
        lpAmounts: lpAmounts,
        swapAmounts: swapAmounts,
        totalProceeds: totalProceeds,
        settled: true
    });
    
    auction.auctionFinalized = true;
    
    // Update reputation for winners
    _updateWinnerReputations(poolId, lpWinners, swapWinners);
    
    emit AuctionSettled(
        poolId,
        totalProceeds,
        lpWinners.length,
        swapWinners.length
    );
}

/**
 * @notice Verify threshold signatures from AVS operators
 */
function _verifyOperatorSignatures(
    PoolId poolId,
    address[] calldata lpWinners,
    address[] calldata swapWinners,
    bytes[] calldata signatures
) internal view returns (bool) {
    require(signatures.length >= THRESHOLD, "Not enough signatures");
    
    // Hash the settlement data
    bytes32 messageHash = keccak256(abi.encodePacked(
        poolId,
        lpWinners,
        swapWinners
    ));
    
    bytes32 ethSignedHash = keccak256(abi.encodePacked(
        "\x19Ethereum Signed Message:\n32",
        messageHash
    ));
    
    // Verify each signature is from a registered operator
    uint256 validSigs = 0;
    address[] memory signers = new address[](signatures.length);
    
    for (uint256 i = 0; i < signatures.length; i++) {
        address signer = _recoverSigner(ethSignedHash, signatures[i]);
        
        // Check signer is operator and not duplicate
        if (isOperator[signer] && !_contains(signers, signer, i)) {
            signers[i] = signer;
            validSigs++;
        }
    }
    
    return validSigs >= THRESHOLD;
}
```

#### 4. beforeSwap - Enforce Priority

```solidity
function beforeSwap(
    address sender,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    bytes calldata hookData
) external override returns (bytes4, BeforeSwapDelta, uint24) {
    
    PoolId poolId = key.toId();
    AuctionConfig storage auction = auctions[poolId];
    AuctionResults storage auctionResults = results[poolId];
    
    // Check if we're in priority window
    bool inPriorityWindow = (
        block.timestamp >= auction.launchTime &&
        block.timestamp < auction.launchTime + 1 hours &&
        auctionResults.settled
    );
    
    if (inPriorityWindow) {
        uint256 currentIndex = currentPriorityIndex[poolId];
        
        // Check if all priority slots have been used
        if (currentIndex < auctionResults.swapWinners.length) {
            address currentWinner = auctionResults.swapWinners[currentIndex];
            
            // Verify sender is current priority winner
            require(
                sender == currentWinner,
                "Not authorized: priority window active"
            );
            
            // Verify winner hasn't already used their slot
            require(
                !hasUsedPriority[poolId][sender],
                "Priority already used"
            );
            
            // Mark as used and increment
            hasUsedPriority[poolId][sender] = true;
            currentPriorityIndex[poolId]++;
            
            emit PrioritySwapExecuted(poolId, sender, currentIndex);
        }
    }
    
    return (
        BaseHook.beforeSwap.selector,
        BeforeSwapDeltaLibrary.ZERO_DELTA,
        0
    );
}
```

#### 5. afterSwap - Collect Proceeds

```solidity
function afterSwap(
    address sender,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    BalanceDelta delta,
    bytes calldata hookData
) external override returns (bytes4, int128) {
    
    PoolId poolId = key.toId();
    AuctionConfig storage auction = auctions[poolId];
    AuctionResults storage auctionResults = results[poolId];
    
    // If this was a priority swap, collect proceeds
    bool wasPrioritySwap = (
        hasUsedPriority[poolId][sender] &&
        block.timestamp < auction.launchTime + 1 hours
    );
    
    if (wasPrioritySwap) {
        // Calculate fee (e.g., 1% of swap amount goes to treasury)
        // Implementation depends on delta structure
        
        // Transfer to project treasury
        // (Implementation details depend on currency type)
    }
    
    return (BaseHook.afterSwap.selector, 0);
}
```

#### 6. Reputation Management

```solidity
/**
 * @notice Update reputation for auction winners
 */
function _updateWinnerReputations(
    PoolId poolId,
    address[] memory lpWinners,
    address[] memory swapWinners
) internal {
    // Increase reputation for all winners
    for (uint256 i = 0; i < lpWinners.length; i++) {
        _increaseReputation(lpWinners[i], 5);
    }
    
    for (uint256 i = 0; i < swapWinners.length; i++) {
        _increaseReputation(swapWinners[i], 3);
    }
}

/**
 * @notice Increase user reputation (max 100)
 */
function _increaseReputation(address user, uint256 amount) internal {
    uint256 oldScore = reputation[user];
    uint256 newScore = oldScore + amount;
    if (newScore > 100) newScore = 100;
    
    reputation[user] = newScore;
    
    emit ReputationUpdated(user, oldScore, newScore);
}

/**
 * @notice Mark address as sniper (called by AVS operators)
 */
function markAsSniper(address sniper, bytes[] calldata operatorSignatures) 
    external 
{
    require(
        _verifyOperatorAction("MARK_SNIPER", sniper, operatorSignatures),
        "Insufficient signatures"
    );
    
    isBlacklisted[sniper] = true;
    reputation[sniper] = 0;
    
    emit ReputationUpdated(sniper, reputation[sniper], 0);
}

/**
 * @notice Grant community member status (discounts in auctions)
 */
function addCommunityMember(address member, bytes[] calldata operatorSignatures) 
    external 
{
    require(
        _verifyOperatorAction("ADD_COMMUNITY", member, operatorSignatures),
        "Insufficient signatures"
    );
    
    isCommunityMember[member] = true;
}
```

---

## Off-Chain AVS Operator Implementation

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│           LaunchGuard AVS Operator Node                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐     ┌──────────────┐                  │
│  │  Auction     │────▶│  FHE         │                  │
│  │  Monitor     │     │  Decryption  │                  │
│  └──────────────┘     └──────────────┘                  │
│         │                     │                          │
│         │                     ▼                          │
│         │            ┌──────────────┐                   │
│         │            │  Bid         │                   │
│         └───────────▶│  Ranking     │                   │
│                      └──────────────┘                   │
│                              │                           │
│                              ▼                           │
│                    ┌──────────────────┐                 │
│                    │  Reputation      │                 │
│                    │  Validation      │                 │
│                    └──────────────────┘                 │
│                              │                           │
│                              ▼                           │
│                    ┌──────────────────┐                 │
│                    │  Consensus       │                 │
│                    │  (BFT)           │                 │
│                    └──────────────────┘                 │
│                              │                           │
│                              ▼                           │
│                    ┌──────────────────┐                 │
│                    │  Settlement      │                 │
│                    │  Transaction     │                 │
│                    └──────────────────┘                 │
└─────────────────────────────────────────────────────────┘
```

### Core Operator Code (TypeScript)

```typescript
// launchGuardOperator.ts

import { ethers } from 'ethers';
import { LaunchGuardHook__factory } from './typechain';
import { FhenixClient } from 'fhenixjs';

interface EncryptedBid {
    bidder: string;
    encryptedAmount: string; // Encrypted value
    timestamp: number;
    bidType: 'LP' | 'SWAP';
}

interface DecryptedBid {
    bidder: string;
    amount: bigint;
    timestamp: number;
    bidType: 'LP' | 'SWAP';
    adjustedAmount: bigint; // After reputation adjustment
}

interface AuctionConfig {
    poolId: string;
    launchTime: number;
    auctionEndTime: number;
    lpSlots: number;
    swapSlots: number;
}

class LaunchGuardOperator {
    private provider: ethers.Provider;
    private wallet: ethers.Wallet;
    private hookContract: ethers.Contract;
    private fhenixClient: FhenixClient;
    private otherOperators: string[]; // Other operator addresses
    
    constructor(
        rpcUrl: string,
        privateKey: string,
        hookAddress: string,
        operatorAddresses: string[]
    ) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.wallet = new ethers.Wallet(privateKey, this.provider);
        this.hookContract = LaunchGuardHook__factory.connect(
            hookAddress,
            this.wallet
        );
        this.fhenixClient = new FhenixClient({ provider: this.provider });
        this.otherOperators = operatorAddresses;
    }
    
    /**
     * Main monitoring loop
     */
    async start() {
        console.log('LaunchGuard AVS Operator started...');
        
        // Monitor for auctions ending
        this.provider.on('block', async (blockNumber) => {
            await this.checkForAuctionsToSettle(blockNumber);
        });
        
        // Monitor for reputation violations
        setInterval(() => this.monitorReputationViolations(), 60000);
    }
    
    /**
     * Check if any auctions need settlement
     */
    async checkForAuctionsToSettle(blockNumber: number) {
        try {
            // Get active auctions from contract
            // (In production, maintain a cache of auctions)
            const auctions = await this.getActiveAuctions();
            
            for (const auction of auctions) {
                const currentTime = Math.floor(Date.now() / 1000);
                
                // Check if auction ended and not yet settled
                if (currentTime >= auction.auctionEndTime) {
                    const isSettled = await this.isAuctionSettled(auction.poolId);
                    
                    if (!isSettled) {
                        console.log(`Auction ${auction.poolId} ready for settlement`);
                        await this.settleAuction(auction);
                    }
                }
            }
        } catch (error) {
            console.error('Error checking auctions:', error);
        }
    }
    
    /**
     * Settle an auction through AVS consensus
     */
    async settleAuction(auction: AuctionConfig) {
        console.log(`Starting settlement for auction ${auction.poolId}`);
        
        // Step 1: Get all encrypted bids
        const encryptedBids = await this.getEncryptedBids(auction.poolId);
        console.log(`Found ${encryptedBids.length} encrypted bids`);
        
        // Step 2: Participate in threshold decryption
        const decryptedBids = await this.thresholdDecryptBids(
            encryptedBids,
            auction.poolId
        );
        console.log(`Decrypted ${decryptedBids.length} bids`);
        
        // Step 3: Apply reputation adjustments
        const adjustedBids = await this.applyReputationAdjustments(decryptedBids);
        
        // Step 4: Rank bids and select winners
        const { lpWinners, swapWinners } = this.selectWinners(
            adjustedBids,
            auction.lpSlots,
            auction.swapSlots
        );
        
        console.log(`Selected ${lpWinners.length} LP winners, ${swapWinners.length} swap winners`);
        
        // Step 5: Reach consensus with other operators
        const consensusReached = await this.reachConsensus(
            auction.poolId,
            lpWinners,
            swapWinners
        );
        
        if (!consensusReached) {
            console.log('Failed to reach consensus, retrying...');
            return;
        }
        
        // Step 6: Collect operator signatures
        const signatures = await this.collectOperatorSignatures(
            auction.poolId,
            lpWinners,
            swapWinners
        );
        
        // Step 7: Submit settlement transaction
        await this.submitSettlement(
            auction.poolId,
            lpWinners,
            swapWinners,
            signatures
        );
        
        console.log(`Auction ${auction.poolId} settled successfully`);
    }
    
    /**
     * Participate in threshold decryption of bids
     */
    async thresholdDecryptBids(
        encryptedBids: EncryptedBid[],
        poolId: string
    ): Promise<DecryptedBid[]> {
        const decryptedBids: DecryptedBid[] = [];
        
        for (const bid of encryptedBids) {
            try {
                // In production, this would use threshold FHE decryption
                // where N of M operators must participate
                
                // For POC, simulate decryption
                // Each operator gets a decryption share
                const myShare = await this.getDecryptionShare(
                    bid.encryptedAmount,
                    poolId
                );
                
                // Collect shares from other operators
                const allShares = await this.collectDecryptionShares(
                    bid.encryptedAmount,
                    poolId
                );
                
                // Combine shares to decrypt
                const decryptedAmount = await this.combineDecryptionShares(allShares);
                
                decryptedBids.push({
                    bidder: bid.bidder,
                    amount: decryptedAmount,
                    timestamp: bid.timestamp,
                    bidType: bid.bidType,
                    adjustedAmount: decryptedAmount // Will be adjusted later
                });
                
            } catch (error) {
                console.error(`Failed to decrypt bid from ${bid.bidder}:`, error);
            }
        }
        
        return decryptedBids;
    }
    
    /**
     * Apply reputation adjustments to bid amounts
     */
    async applyReputationAdjustments(
        bids: DecryptedBid[]
    ): Promise<DecryptedBid[]> {
        for (const bid of bids) {
            // Get reputation score
            const reputation = await this.hookContract.reputation(bid.bidder);
            const isCommunity = await this.hookContract.isCommunityMember(bid.bidder);
            const isBlacklisted = await this.hookContract.isBlacklisted(bid.bidder);
            
            if (isBlacklisted) {
                // Blacklisted users get massive penalty
                bid.adjustedAmount = bid.amount / BigInt(10);
                continue;
            }
            
            if (isCommunity) {
                // Community members get 10% bonus
                bid.adjustedAmount = bid.amount * BigInt(110) / BigInt(100);
            } else if (reputation < 50) {
                // Low reputation gets penalty
                const penalty = BigInt(100 - reputation);
                bid.adjustedAmount = bid.amount * BigInt(100 - Number(penalty)) / BigInt(100);
            } else {
                // No adjustment
                bid.adjustedAmount = bid.amount;
            }
        }
        
        return bids;
    }
    
    /**
     * Select winners from adjusted bids
     */
    selectWinners(
        bids: DecryptedBid[],
        lpSlots: number,
        swapSlots: number
    ): { lpWinners: any[], swapWinners: any[] } {
        // Separate LP and swap bids
        const lpBids = bids.filter(b => b.bidType === 'LP');
        const swapBids = bids.filter(b => b.bidType === 'SWAP');
        
        // Sort by adjusted amount (descending)
        lpBids.sort((a, b) => 
            Number(b.adjustedAmount - a.adjustedAmount)
        );
        swapBids.sort((a, b) => 
            Number(b.adjustedAmount - a.adjustedAmount)
        );
        
        // Select top N winners
        const lpWinners = lpBids.slice(0, lpSlots).map(b => ({
            address: b.bidder,
            amount: b.amount.toString()
        }));
        
        const swapWinners = swapBids.slice(0, swapSlots).map(b => ({
            address: b.bidder,
            amount: b.amount.toString()
        }));
        
        return { lpWinners, swapWinners };
    }
    
    /**
     * Reach consensus with other operators using BFT
     */
    async reachConsensus(
        poolId: string,
        lpWinners: any[],
        swapWinners: any[]
    ): Promise<boolean> {
        // Hash the results
        const resultsHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
                ['string', 'address[]', 'address[]'],
                [
                    poolId,
                    lpWinners.map(w => w.address),
                    swapWinners.map(w => w.address)
                ]
            )
        );
        
        // Broadcast to other operators (P2P network or coordinator)
        // In production: use libp2p or similar
        const votes = await this.broadcastAndCollectVotes(resultsHash);
        
        // Count votes
        const threshold = Math.ceil(this.otherOperators.length * 2 / 3);
        const agreeingVotes = votes.filter(v => v.hash === resultsHash).length;
        
        return agreeingVotes >= threshold;
    }
    
    /**
     * Collect signatures from operators for settlement
     */
    async collectOperatorSignatures(
        poolId: string,
        lpWinners: any[],
        swapWinners: any[]
    ): Promise<string[]> {
        // Message to sign
        const messageHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
                ['bytes32', 'address[]', 'address[]'],
                [
                    poolId,
                    lpWinners.map(w => w.address),
                    swapWinners.map(w => w.address)
                ]
            )
        );
        
        // Sign with our key
        const mySignature = await this.wallet.signMessage(
            ethers.getBytes(messageHash)
        );
        
        // Request signatures from other operators
        const otherSignatures = await this.requestSignaturesFromOperators(
            messageHash
        );
        
        return [mySignature, ...otherSignatures];
    }
    
    /**
     * Submit settlement transaction to blockchain
     */
    async submitSettlement(
        poolId: string,
        lpWinners: any[],
        swapWinners: any[],
        signatures: string[]
    ) {
        const poolKey = await this.getPoolKey(poolId);
        
        const tx = await this.hookContract.settleAuction(
            poolKey,
            lpWinners.map(w => w.address),
            swapWinners.map(w => w.address),
            lpWinners.map(w => w.amount),
            swapWinners.map(w => w.amount),
            signatures
        );
        
        await tx.wait();
        console.log(`Settlement submitted: ${tx.hash}`);
    }
    
    /**
     * Monitor for reputation violations
     */
    async monitorReputationViolations() {
        // Check recent transactions for suspicious patterns
        // - Multiple failed bids (bid sniping attempts)
        // - Sandwich attacks during priority windows
        // - Other bot-like behavior
        
        // If violations detected, coordinate with other operators
        // to blacklist the address
    }
    
    // ===== HELPER FUNCTIONS =====
    
    async getActiveAuctions(): Promise<AuctionConfig[]> {
        // Query contract for active auctions
        // In production, maintain off-chain cache
        return [];
    }
    
    async getEncryptedBids(poolId: string): Promise<EncryptedBid[]> {
        const bids = await this.hookContract.getEncryptedBids(poolId);
        return bids.map((b: any) => ({
            bidder: b.bidder,
            encryptedAmount: b.encryptedAmount,
            timestamp: Number(b.timestamp),
            bidType: b.bidType === 0 ? 'LP' : 'SWAP'
        }));
    }
    
    async isAuctionSettled(poolId: string): Promise<boolean> {
        const results = await this.hookContract.results(poolId);
        return results.settled;
    }
    
    async getDecryptionShare(encryptedValue: string, poolId: string): Promise<string> {
        // Fhenix threshold FHE decryption
        // Each operator generates a decryption share
        return this.fhenixClient.getDecryptionShare(encryptedValue);
    }
    
    async collectDecryptionShares(encryptedValue: string, poolId: string): Promise<string[]> {
        // Request decryption shares from other operators
        // Via P2P network or coordinator
        return [];
    }
    
    async combineDecryptionShares(shares: string[]): Promise<bigint> {
        // Combine threshold shares to decrypt
        return this.fhenixClient.combineShares(shares);
    }
    
    async broadcastAndCollectVotes(hash: string): Promise<any[]> {
        // Broadcast via P2P and collect votes
        return [];
    }
    
    async requestSignaturesFromOperators(messageHash: string): Promise<string[]> {
        // Request signatures from other operators
        return [];
    }
    
    async getPoolKey(poolId: string): Promise<any> {
        // Reconstruct PoolKey from poolId
        return {};
    }
}

// Main execution
async function main() {
    const operator = new LaunchGuardOperator(
        process.env.RPC_URL!,
        process.env.PRIVATE_KEY!,
        process.env.HOOK_ADDRESS!,
        process.env.OTHER_OPERATORS!.split(',')
    );
    
    await operator.start();
}

main().catch(console.error);
```

---

## Frontend Implementation

### Client-Side Encryption (Fhenix)

```typescript
// bidding.ts - Frontend code

import { FhenixClient } from 'fhenixjs';
import { ethers } from 'ethers';

class BiddingInterface {
    private fhenixClient: FhenixClient;
    private provider: ethers.BrowserProvider;
    private signer: ethers.Signer;
    
    constructor() {
        this.provider = new ethers.BrowserProvider(window.ethereum);
        this.fhenixClient = new FhenixClient({ provider: this.provider });
    }
    
    /**
     * Submit encrypted bid
     */
    async submitBid(
        hookAddress: string,
        poolKey: any,
        bidAmount: string,
        bidType: 'LP' | 'SWAP'
    ) {
        // Step 1: Get signer
        this.signer = await this.provider.getSigner();
        
        // Step 2: Encrypt bid amount using Fhenix
        const amountWei = ethers.parseEther(bidAmount);
        const encryptedAmount = await this.fhenixClient.encrypt_uint64(
            Number(amountWei)
        );
        
        console.log('Bid encrypted:', encryptedAmount);
        
        // Step 3: Submit to contract
        const hookContract = new ethers.Contract(
            hookAddress,
            HOOK_ABI,
            this.signer
        );
        
        const tx = await hookContract.submitBid(
            poolKey,
            bidType === 'LP' ? 0 : 1,
            encryptedAmount
        );
        
        await tx.wait();
        console.log('Bid submitted:', tx.hash);
        
        return tx.hash;
    }
    
    /**
     * Check auction status
     */
    async getAuctionStatus(hookAddress: string, poolId: string) {
        const hookContract = new ethers.Contract(
            hookAddress,
            HOOK_ABI,
            this.provider
        );
        
        const config = await hookContract.auctions(poolId);
        const results = await hookContract.results(poolId);
        
        return {
            launchTime: Number(config.launchTime),
            auctionEndTime: Number(config.auctionEndTime),
            isSettled: results.settled,
            lpWinners: results.settled ? results.lpWinners : [],
            swapWinners: results.settled ? results.swapWinners : []
        };
    }
    
    /**
     * Check user reputation
     */
    async getReputation(hookAddress: string, userAddress: string) {
        const hookContract = new ethers.Contract(
            hookAddress,
            HOOK_ABI,
            this.provider
        );
        
        const reputation = await hookContract.reputation(userAddress);
        const isCommunity = await hookContract.isCommunityMember(userAddress);
        const isBlacklisted = await hookContract.isBlacklisted(userAddress);
        
        return {
            score: Number(reputation),
            isCommunity,
            isBlacklisted
        };
    }
}
```

---

## Implementation Roadmap

### Week 1: Core Hook & FHE Integration (Days 1-7)

**Day 1-2: Project Setup**
- [ ] Initialize Foundry project with Uniswap v4
- [ ] Add Fhenix FHE contracts
- [ ] Set up EigenLayer operator framework
- [ ] Create basic hook structure

**Day 3-4: Encrypted Auction Logic**
- [ ] Implement bid submission with FHE encryption
- [ ] Write bid storage and retrieval
- [ ] Test FHE encrypt/decrypt locally
- [ ] Implement beforeInitialize for auction setup

**Day 5-6: Settlement Logic**
- [ ] Write settlement function with operator signatures
- [ ] Implement signature verification
- [ ] Add reputation system
- [ ] Write winner selection logic

**Day 7: Hook Functions**
- [ ] Implement beforeSwap (priority enforcement)
- [ ] Implement afterSwap (proceeds collection)
- [ ] Write tests for priority windows
- [ ] Debug and fix issues

### Week 2: AVS Operator Development (Days 8-14)

**Day 8-9: Operator Setup**
- [ ] Set up Node.js operator project
- [ ] Implement Fhenix client integration
- [ ] Create operator class structure
- [ ] Set up P2P communication (or mock)

**Day 10-11: Decryption & Consensus**
- [ ] Implement threshold decryption logic
- [ ] Write consensus mechanism (BFT)
- [ ] Implement signature collection
- [ ] Test with multiple operators

**Day 12-13: Reputation Monitoring**
- [ ] Write reputation validation logic
- [ ] Implement sniper detection
- [ ] Add community member management
- [ ] Test reputation adjustments

**Day 14: Integration Testing**
- [ ] Deploy to testnet
- [ ] Run full auction simulation
- [ ] Test with multiple bidders
- [ ] Verify settlement works end-to-end

### Week 3: Frontend, Polish & Demo (Days 15-21)

**Day 15-16: Frontend (Optional)**
- [ ] Create React/Next.js app
- [ ] Build bidding interface with encryption
- [ ] Add auction monitoring dashboard
- [ ] Show reputation and status

**Day 17-18: Comprehensive Testing**
- [ ] Test edge cases (no bids, ties, etc.)
- [ ] Test reputation system thoroughly
- [ ] Test priority enforcement
- [ ] Security review

**Day 19-20: Demo Preparation**
- [ ] Record demo video (<5 min)
- [ ] Show encrypted bidding
- [ ] Show AVS coordination
- [ ] Demonstrate fair launch

**Day 21: Final Submission**
- [ ] Clean up code and documentation
- [ ] Write comprehensive README
- [ ] Deploy final version
- [ ] Submit to hackathon

---

## Testing Strategy

### Unit Tests (Foundry)

```solidity
// test/LaunchGuardHook.t.sol

contract LaunchGuardHookTest is Test {
    
    function testAuctionCreation() public {
        // Test auction initialization
        // Test parameter validation
    }
    
    function testEncryptedBidSubmission() public {
        // Test bid submission with FHE
        // Test invalid bids rejected
        // Test reputation requirements
    }
    
    function testAuctionSettlement() public {
        // Test operator signature verification
        // Test winner selection
        // Test reputation updates
    }
    
    function testPriorityEnforcement() public {
        // Test priority window works
        // Test unauthorized swaps blocked
        // Test transition to public trading
    }
    
    function testReputationSystem() public {
        // Test blacklist enforcement
        // Test community member benefits
        // Test reputation adjustments
    }
}
```

### Integration Tests

```typescript
// test/integration.test.ts

describe('LaunchGuard Integration', () => {
    
    it('should handle full auction lifecycle', async () => {
        // 1. Project creates auction
        // 2. Multiple users submit encrypted bids
        // 3. Operators settle auction
        // 4. Winners execute priority swaps
        // 5. Pool opens to public
    });
    
    it('should decrypt bids correctly', async () => {
        // Test threshold decryption
        // Test consensus mechanism
    });
    
    it('should enforce reputation correctly', async () => {
        // Test blacklist blocks bids
        // Test community member bonuses
    });
});
```

---

## Demo Requirements

### Video Script (5 minutes)

**Minute 1: Problem**
- Show bot-dominated token launches
- Explain sniper problem
- Show retail getting rekt

**Minute 2: Solution Overview**
- Explain encrypted auction concept
- Show Fhenix FHE hiding bids
- Show EigenLayer coordinating settlement

**Minute 3: Live Demo**
- Project creates auction
- Users submit encrypted bids
- Show that bid amounts are hidden
- Operators settle auction
- Winners revealed

**Minute 4: Priority Execution**
- Show priority swap window
- Unauthorized swap blocked
- Winner executes successfully
- Pool opens to public

**Minute 5: Impact & Technology**
- Show Fhenix integration (FHE operations)
- Show EigenLayer AVS coordination
- Explain reputation system
- Future vision for fair launches

### Required Deliverables

1. **GitHub Repository**
   - Smart contracts with Fhenix FHE integration
   - AVS operator code
   - Frontend with encryption
   - Comprehensive README
   - Test suite

2. **Demo Video** (Max 5 minutes)
   - Clear explanation of encrypted auction
   - Working demo with multiple bidders
   - Show both sponsor integrations
   - Technical depth on FHE and AVS

3. **Documentation**
   - Architecture diagrams
   - Fhenix integration guide
   - EigenLayer AVS design doc
   - API reference
   - Deployment guide

4. **Deployments**
   - Testnet contracts
   - Verified on Etherscan
   - Working operator node
   - Frontend (optional)

---

## Project Structure

```
launchguard/
├── contracts/
│   ├── LaunchGuardHook.sol          # Main hook
│   ├── EncryptedAuction.sol         # FHE auction logic
│   ├── ReputationRegistry.sol       # Reputation system
│   └── interfaces/
│       └── ILaunchGuard.sol
├── operator/
│   ├── src/
│   │   ├── LaunchGuardOperator.ts   # Main operator
│   │   ├── FHEDecryptor.ts          # Threshold decryption
│   │   ├── Consensus.ts             # BFT consensus
│   │   └── ReputationMonitor.ts     # Reputation tracking
│   ├── package.json
│   └── tsconfig.json
├── frontend/
│   ├── app/
│   │   ├── page.tsx
│   │   ├── bidding/
│   │   └── components/
│   │       ├── EncryptedBidForm.tsx
│   │       └── AuctionStatus.tsx
│   ├── lib/
│   │   └── fhenix.ts                # Fhenix encryption utils
│   └── package.json
├── test/
│   ├── LaunchGuardHook.t.sol        # Solidity tests
│   ├── integration.test.ts          # Integration tests
│   └── fhe.test.ts                  # FHE encryption tests
├── script/
│   └── Deploy.s.sol
├── foundry.toml
└── README.md
```

---

## Key Differentiators

### Why This Wins

1. **Integrates BOTH Sponsors** ✅
   - Fhenix: Encrypted bids with FHE operations
   - EigenLayer: AVS coordination and settlement
   - Maximum prize eligibility

2. **Solves Clear Problem** ✅
   - Bot-dominated launches plague crypto
   - Everyone understands the pain
   - High-impact solution

3. **Novel Implementation** ✅
   - First encrypted auction hook for v4
   - Unique reputation system
   - Priority trading windows

4. **Technical Innovation** ✅
   - Threshold FHE decryption
   - BFT consensus for settlement
   - Privacy-preserving price discovery

5. **Demo-able** ✅
   - Clear before/after comparison
   - Visual bidding process
   - Exciting settlement reveal

6. **Production Potential** ✅
   - Could become standard for launches
   - Clear business model (auction proceeds)
   - Extensible to other use cases

---

## Sponsor Requirements Met

### Fhenix (VIP Sponsor)

**Requirement:** Enable confidential liquidity provisioning, protect order flow from MEV

**How We Meet It:**
- ✅ Use FHE library operations (FHE.asEuint64, FHE.gt, FHE.decrypt)
- ✅ Encrypt bid amounts to prevent sniping
- ✅ Maintain privacy until settlement
- ✅ Threshold decryption by operators
- ✅ Clear documentation of FHE integration

### EigenLayer (Benefactor Sponsor)

**Requirement:** Uniswap v4 hook + offchain operator software

**How We Meet It:**
- ✅ Hook with complex auction logic
- ✅ AVS operators coordinate settlement
- ✅ Off-chain computation (bid ranking, reputation)
- ✅ Threshold signatures for security
- ✅ Clear AVS architecture documentation

---

## Complexity & Risk Management

### Complexity Challenges

1. **FHE Integration**
   - Risk: Fhenix library learning curve
   - Mitigation: Use simple FHE operations, reference examples
   - Fallback: Simplified encryption (commit-reveal)

2. **Threshold Decryption**
   - Risk: Complex cryptography
   - Mitigation: Simulate threshold scheme for POC
   - Fallback: Single operator decryption with slashing

3. **AVS Coordination**
   - Risk: Distributed consensus
   - Mitigation: Simplified BFT for POC
   - Fallback: 3-of-5 multisig settlement

### Simplifications for POC

- Use mock threshold decryption (simulate shares)
- Simple majority voting instead of full BFT
- Manual reputation updates (not automatic detection)
- Single auction type (combined LP + swap)
- Testnet only (no mainnet considerations)

---

## Resources & References

### Fhenix Resources
- **Docs:** https://docs.fhenix.zone/
- **CoFHE Quickstart:** https://cofhe-docs.fhenix.zone/docs/devdocs/quick-start
- **FHE Hook Template:** https://github.com/marronjo/fhe-hook-template
- **FHE Examples:** Limit order and market order hooks

### EigenLayer Resources
- **Docs:** https://docs.eigenlayer.xyz/
- **AVS Guide:** https://docs.eigenlayer.xyz/developers/Concepts/avs-developer-guide
- **Example AVS:** Hello World, Incredible Squaring

### Uniswap v4 Resources
- **Docs:** https://docs.uniswap.org/
- **v4 Core:** https://github.com/Uniswap/v4-core
- **Hook Examples:** https://github.com/Uniswap/v4-periphery

### Development Tools
- **Foundry:** https://book.getfoundry.sh/
- **FhenixJS:** npm install fhenixjs
- **Ethers.js:** https://docs.ethers.org/

---

## Success Metrics

### Technical Metrics
- ✅ Encrypted bids successfully submitted
- ✅ Threshold decryption works
- ✅ Settlement completes correctly
- ✅ Priority enforcement works
- ✅ 100% test coverage

### Demo Metrics
- ✅ Live encrypted bidding shown
- ✅ AVS coordination demonstrated
- ✅ Fair launch completed end-to-end
- ✅ Reputation system visible
- ✅ Both sponsors clearly integrated

### Prize Criteria Alignment
- **Original Idea (30%):** Novel encrypted auction for launches
- **Unique Execution (25%):** FHE + AVS coordination
- **Impact (20%):** Solves major bot problem
- **Functionality (15%):** Full working demo
- **Presentation (10%):** Clear, compelling video

---

## Notes for Claude Code

This document provides comprehensive architecture for LaunchGuard. Key implementation priorities:

1. **Start Simple:** Begin with basic auction, add encryption
2. **Fhenix First:** Get FHE working before AVS complexity
3. **Mock Threshold:** Simulate decryption shares for POC
4. **Test Extensively:** Encryption bugs are hard to debug
5. **Document Clearly:** Show sponsor integration in README

Remember: The goal is a working POC that demonstrates the concept, not production-ready code. Focus on clear demo over perfect implementation.

---

**Last Updated:** November 24, 2024
**Project Timeline:** 3 weeks (Nov 24 - Dec 11)
**Target:** UHI7 Hookathon Demo Day (Dec 19)
**Sponsors:** Fhenix (VIP) + EigenLayer (Benefactor)
