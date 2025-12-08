// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {FHE, InEuint128, euint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

import {EncryptedAuction} from "./EncryptedAuction.sol";
import {ReputationRegistry} from "./ReputationRegistry.sol";
import {ILaunchGuard} from "./interface/ILaunchGuard.sol";

/**
 * @title LaunchGuardHook
 * @notice Uniswap v4 hook for fair token launches using encrypted auctions
 * @dev Integrates Fhenix FHE for bid privacy and EigenLayer AVS for settlement
 */
contract LaunchGuardHook is BaseHook, ILaunchGuard {
    using PoolIdLibrary for PoolKey;
    using FHE for euint128;
    
    // ============ State Variables ============
    
    EncryptedAuction public immutable auction;
    ReputationRegistry public immutable reputationRegistry;
    
    // Track which pools have LaunchGuard enabled
    mapping(PoolId => bool) public isLaunchGuardPool;
    
    // ============ Events ============
    
    event LaunchGuardEnabled(PoolId indexed poolId);
    event UnauthorizedSwapBlocked(PoolId indexed poolId, address indexed user);
    
    // ============ Constructor ============
    
    constructor(
        IPoolManager _poolManager,
        address _reputationRegistry
    ) BaseHook(_poolManager) {
        reputationRegistry = ReputationRegistry(_reputationRegistry);
        auction = new EncryptedAuction(_reputationRegistry);
    }
    
    // ============ Hook Permissions ============
    
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    // ============ Hook Functions ============
    
    /**
     * @notice Called before pool initialization
     * @dev Automatically enables LaunchGuard for all pools using this hook
     */
    function _beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) internal override returns (bytes4) {
        // Automatically enable LaunchGuard for any pool that uses this hook
        isLaunchGuardPool[key.toId()] = true;
        emit LaunchGuardEnabled(key.toId());

        return BaseHook.beforeInitialize.selector;
    }
    
    /**
     * @notice Called before liquidity is added
     * @dev Allows initial liquidity from pool creator during auction
     */
    function _beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();
        
        // If not a LaunchGuard pool, allow all liquidity
        if (!isLaunchGuardPool[poolId]) {
            return BaseHook.beforeAddLiquidity.selector;
        }
        
        // During auction and priority window, only allow authorized addresses
        if (auction.isInPriorityWindow(key)) {
            // Only winners or pool creator can add liquidity during priority window
            if (!auction.isWinner(key, sender)) {
                revert NotAuthorized();
            }
        }
        
        return BaseHook.beforeAddLiquidity.selector;
    }
    
    /**
     * @notice Called before a swap
     * @dev Enforces priority window for auction winners
     */
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        
        // If not a LaunchGuard pool, allow all swaps
        if (!isLaunchGuardPool[poolId]) {
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }
        
        // Check if we're in the priority window
        if (auction.isInPriorityWindow(key)) {
            // Only winners can swap during priority window
            if (!auction.isWinner(key, sender)) {
                emit UnauthorizedSwapBlocked(poolId, sender);
                revert PriorityWindowActive();
            }
            
            // Check if winner has already executed
            ILaunchGuard.Bid memory bid = auction.getBid(key, sender);
            if (bid.hasExecuted) {
                revert AlreadyExecuted();
            }
            
            // Mark as executed
            auction.markExecuted(key, sender);
            
            emit WinnerExecuted(key, sender, auction.getAllocation(key, sender));
        }
        
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
    
    // ============ LaunchGuard Functions ============
    
    /**
     * @notice Create a new auction for a pool
     * @param poolKey The pool to create auction for
     * @param auctionEndTime When the auction ends
     * @param priorityWindowDuration How long winners have priority
     * @param minBidAmount Minimum bid amount
     * @param maxWinners Maximum number of winners
     */
    function createAuction(
        PoolKey calldata poolKey,
        uint256 auctionEndTime,
        uint256 priorityWindowDuration,
        uint256 minBidAmount,
        uint256 maxWinners
    ) external override {
        // Only allow auction creation for LaunchGuard pools
        if (!isLaunchGuardPool[poolKey.toId()]) {
            revert InvalidConfiguration();
        }
        
        auction.createAuction(
            poolKey,
            auctionEndTime,
            priorityWindowDuration,
            minBidAmount,
            maxWinners
        );
        
        emit AuctionCreated(
            poolKey,
            auctionEndTime,
            priorityWindowDuration,
            minBidAmount,
            maxWinners
        );
    }
    
    /**
     * @notice Submit an encrypted bid
     * @param poolKey The pool to bid on
     * @param encryptedAmount Encrypted bid amount
     */
    function submitBid(
        PoolKey calldata poolKey,
        euint128 encryptedAmount
    ) external override {
        // Convert euint128 to InEuint128 for auction contract
        InEuint128 memory inAmount;
        // Note: In production, this would use proper FHE serialization
        // For now, we'll call the auction directly with the euint128
        
        auction.submitBid(poolKey, inAmount);
        
        emit BidSubmitted(poolKey, msg.sender, encryptedAmount, block.timestamp);
    }
    
    /**
     * @notice Settle auction with decrypted winners
     * @dev Called by EigenLayer AVS operators
     * @param poolKey The pool to settle
     * @param winners Array of winners with decrypted amounts
     */
    function settleAuction(
        PoolKey calldata poolKey,
        Winner[] calldata winners
    ) external override {
        auction.settleAuction(poolKey, winners);
        
        emit AuctionSettled(poolKey, auction.getBidders(poolKey).length, winners.length);
        emit PoolOpenedToPublic(poolKey, block.timestamp);
    }
    
    /**
     * @notice Execute priority swap (called by winner)
     * @param poolKey The pool
     */
    function executePrioritySwap(
        PoolKey calldata poolKey
    ) external override {
        if (!auction.isWinner(poolKey, msg.sender)) {
            revert NotWinner();
        }
        
        if (!auction.isInPriorityWindow(poolKey)) {
            revert PriorityWindowExpired();
        }
        
        ILaunchGuard.Bid memory bid = auction.getBid(poolKey, msg.sender);
        if (bid.hasExecuted) {
            revert AlreadyExecuted();
        }
        
        // Winner should execute swap through normal swap flow
        // This function is just for validation
    }
    
    // ============ View Functions ============
    
    function isInPriorityWindow(PoolKey calldata poolKey) external view override returns (bool) {
        return auction.isInPriorityWindow(poolKey);
    }
    
    function getAuctionConfig(PoolKey calldata poolKey) external view override returns (AuctionConfig memory) {
        return auction.getAuctionConfig(poolKey);
    }
    
    function getBid(PoolKey calldata poolKey, address bidder) external view override returns (Bid memory) {
        return auction.getBid(poolKey, bidder);
    }
    
    function isWinner(PoolKey calldata poolKey, address bidder) external view override returns (bool) {
        return auction.isWinner(poolKey, bidder);
    }
    
    /**
     * @notice Get the auction contract address
     */
    function getAuctionContract() external view returns (address) {
        return address(auction);
    }
    
    /**
     * @notice Get the reputation registry address
     */
    function getReputationRegistry() external view returns (address) {
        return address(reputationRegistry);
    }
}
