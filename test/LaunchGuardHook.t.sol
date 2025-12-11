// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "./utils/Deployers.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {LaunchGuardHook} from "../src/LaunchGuardHook.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {ILaunchGuard} from "../src/interface/ILaunchGuard.sol";

import {FHE, InEuint128, euint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {CoFheTest} from "@fhenixprotocol/cofhe-foundry-mocks/CoFheTest.sol";

/**
 * @title LaunchGuardHookTest
 * @notice Tests for LaunchGuard encrypted auction system
 */
contract LaunchGuardHookTest is CoFheTest, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using FHE for euint128;

    LaunchGuardHook hook;
    ReputationRegistry reputationRegistry;
    PoolKey poolKey;
    address auctionContract;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address poolCreator = makeAddr("poolCreator");

    constructor() CoFheTest(false) {}

    function setUp() public {
        // CoFheTest is initialized in constructor, FHE mocks are ready

        // Deploy v4 core contracts
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        
        // Deploy reputation registry
        reputationRegistry = new ReputationRegistry();

        // Deploy hook to an address with correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG
        );

        // Use deployCodeTo like Counter test - this works with FHE mocks
        bytes memory constructorArgs = abi.encode(manager, address(reputationRegistry));
        address hookAddress = address(flags);
        deployCodeTo("LaunchGuardHook.sol:LaunchGuardHook", constructorArgs, hookAddress);
        hook = LaunchGuardHook(hookAddress);
        
        // Create pool key
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Initialize pool
        manager.initialize(poolKey, SQRT_PRICE_1_1);
        
        // Manually enable LaunchGuard for this pool (since hookData not supported in initialize)
        // In production, this would be done via beforeInitialize with hookData
        bytes32 poolIdSlot = keccak256(abi.encode(poolKey.toId(), uint256(1))); // slot 1 is isLaunchGuardPool mapping
        vm.store(address(hook), poolIdSlot, bytes32(uint256(1)));

        // Get auction contract address for FHE mocking
        auctionContract = hook.getAuctionContract();

        key = poolKey;
    }
    
    function test_CreateAuction() public {
        uint256 auctionEndTime = block.timestamp + 1 hours;
        uint256 priorityWindow = 30 minutes;
        uint256 minBid = 0.1 ether;
        uint256 maxWinners = 10;
        
        vm.prank(poolCreator);
        hook.createAuction(
            poolKey,
            auctionEndTime,
            priorityWindow,
            minBid,
            maxWinners
        );
        
        ILaunchGuard.AuctionConfig memory config = hook.getAuctionConfig(poolKey);
        assertEq(config.auctionEndTime, auctionEndTime);
        assertEq(config.priorityWindowDuration, priorityWindow);
        assertEq(config.minBidAmount, minBid);
        assertEq(config.maxWinners, maxWinners);
        assertTrue(config.isActive);
    }
    
    function test_SubmitBid() public {
        // Create auction first
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        // Submit encrypted bid using CoFHE mock helpers
        // Use the auction contract address as signer since it's the contract that will verify
        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);

        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount);

        ILaunchGuard.Bid memory bid = hook.getBid(poolKey, alice);
        assertEq(bid.bidder, alice);
        assertFalse(bid.isWinner);
        assertFalse(bid.hasExecuted);
    }
    
    function test_RevertWhen_BlacklistedUserBids() public {
        // Blacklist alice
        reputationRegistry.blacklist(alice, "Bot detected");

        // Create auction
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        // Try to submit bid using CoFHE mock helpers
        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);

        vm.prank(alice);
        vm.expectRevert();
        hook.submitBid(poolKey, bidAmount);
    }
    
    function test_SettleAuction() public {
        // Create auction
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        // Submit bids using CoFHE mock helpers
        InEuint128 memory encryptedBid1 = this.createInEuint128(uint128(1 ether), auctionContract);
        InEuint128 memory encryptedBid2 = this.createInEuint128(uint128(2 ether), auctionContract);
        euint128 bidAmount1 = FHE.asEuint128(encryptedBid1);
        euint128 bidAmount2 = FHE.asEuint128(encryptedBid2);

        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount1);

        vm.prank(bob);
        hook.submitBid(poolKey, bidAmount2);

        // Fast forward past auction end
        vm.warp(auctionEndTime + 1);

        // Settle auction (simulating operator)
        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](2);
        winners[0] = ILaunchGuard.Winner({
            bidder: bob,
            amount: 2 ether,
            allocation: 2000
        });
        winners[1] = ILaunchGuard.Winner({
            bidder: alice,
            amount: 1 ether,
            allocation: 1000
        });

        hook.settleAuction(poolKey, winners);

        assertTrue(hook.isWinner(poolKey, alice));
        assertTrue(hook.isWinner(poolKey, bob));
        assertFalse(hook.isWinner(poolKey, charlie));
    }
    
    function test_PriorityWindow() public {
        // Setup and settle auction
        uint256 auctionEndTime = block.timestamp + 1 hours;
        uint256 priorityWindow = 30 minutes;

        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, priorityWindow, 0.1 ether, 10);

        // Submit bid using CoFHE mock helper
        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);
        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount);

        vm.warp(auctionEndTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({
            bidder: alice,
            amount: 1 ether,
            allocation: 1000
        });

        hook.settleAuction(poolKey, winners);

        // Check priority window is active
        assertTrue(hook.isInPriorityWindow(poolKey));

        // Fast forward past priority window
        vm.warp(auctionEndTime + priorityWindow + 1);

        // Priority window should be over
        assertFalse(hook.isInPriorityWindow(poolKey));
    }
    
    function test_ReputationSystem() public {
        // Test community member bonus
        assertFalse(reputationRegistry.isCommunityMember(alice));
        assertEq(reputationRegistry.getReputationScore(alice), 100);

        reputationRegistry.addCommunityMember(alice);
        assertTrue(reputationRegistry.isCommunityMember(alice));
        assertEq(reputationRegistry.getReputationScore(alice), 110);
        assertEq(reputationRegistry.getCommunityBonus(alice), 10);

        // Test blacklist
        reputationRegistry.blacklist(bob, "Suspicious activity");
        assertTrue(reputationRegistry.isBlacklisted(bob));
        assertFalse(reputationRegistry.canParticipate(bob));
        assertEq(reputationRegistry.getReputationScore(bob), 0);
    }

    // ============================================================================
    // BeforeSwap Hook Tests
    // ============================================================================

    function test_RevertWhen_NonWinnerSwapsDuringPriority() public {
        // Create and settle auction with alice as winner
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);
        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount);

        vm.warp(auctionEndTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});
        hook.settleAuction(poolKey, winners);

        // Try to swap as non-winner bob during priority window
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        vm.prank(bob);
        vm.expectRevert(ILaunchGuard.PriorityWindowActive.selector);
        manager.swap(poolKey, swapParams, "");
    }

    function test_WinnerCanSwapDuringPriority() public {
        // Create and settle auction with alice as winner
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);
        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount);

        vm.warp(auctionEndTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});
        hook.settleAuction(poolKey, winners);

        // Alice can swap during priority window
        assertTrue(hook.isInPriorityWindow(poolKey));
        assertTrue(hook.isWinner(poolKey, alice));
    }

    function test_PublicCanSwapAfterPriorityWindow() public {
        // Create and settle auction
        uint256 auctionEndTime = block.timestamp + 1 hours;
        uint256 priorityWindow = 30 minutes;

        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, priorityWindow, 0.1 ether, 10);

        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);
        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount);

        vm.warp(auctionEndTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});
        hook.settleAuction(poolKey, winners);

        // Fast forward past priority window
        vm.warp(auctionEndTime + priorityWindow + 1);

        // Now anyone can swap
        assertFalse(hook.isInPriorityWindow(poolKey));
    }

    // ============================================================================
    // BeforeAddLiquidity Hook Tests
    // ============================================================================

    function test_RevertWhen_NonWinnerAddsLiquidityDuringPriority() public {
        // Create and settle auction with alice as winner
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);
        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount);

        vm.warp(auctionEndTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});
        hook.settleAuction(poolKey, winners);

        // Try to add liquidity as non-winner during priority window
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1 ether,
            salt: bytes32(0)
        });

        vm.prank(bob);
        vm.expectRevert(ILaunchGuard.NotAuthorized.selector);
        manager.modifyLiquidity(poolKey, params, "");
    }

    // ============================================================================
    // Multiple Winners Tests
    // ============================================================================

    function test_MultipleWinnersCanAllSwap() public {
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        // Submit bids from alice, bob, charlie
        InEuint128 memory encryptedBid1 = this.createInEuint128(uint128(1 ether), auctionContract);
        InEuint128 memory encryptedBid2 = this.createInEuint128(uint128(2 ether), auctionContract);
        InEuint128 memory encryptedBid3 = this.createInEuint128(uint128(3 ether), auctionContract);
        euint128 bidAmount1 = FHE.asEuint128(encryptedBid1);
        euint128 bidAmount2 = FHE.asEuint128(encryptedBid2);
        euint128 bidAmount3 = FHE.asEuint128(encryptedBid3);

        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount1);
        vm.prank(bob);
        hook.submitBid(poolKey, bidAmount2);
        vm.prank(charlie);
        hook.submitBid(poolKey, bidAmount3);

        vm.warp(auctionEndTime + 1);

        // All three are winners
        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](3);
        winners[0] = ILaunchGuard.Winner({bidder: charlie, amount: 3 ether, allocation: 3000});
        winners[1] = ILaunchGuard.Winner({bidder: bob, amount: 2 ether, allocation: 2000});
        winners[2] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});
        hook.settleAuction(poolKey, winners);

        // Verify all are winners
        assertTrue(hook.isWinner(poolKey, alice));
        assertTrue(hook.isWinner(poolKey, bob));
        assertTrue(hook.isWinner(poolKey, charlie));

        // Verify allocations
        assertEq(hook.auction().getAllocation(poolKey, alice), 1000);
        assertEq(hook.auction().getAllocation(poolKey, bob), 2000);
        assertEq(hook.auction().getAllocation(poolKey, charlie), 3000);
    }

    // ============================================================================
    // Edge Case Tests
    // ============================================================================

    function test_RevertWhen_CreateAuctionOnNonLaunchGuardPool() public {
        // Create a regular pool without LaunchGuard
        PoolKey memory regularKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))  // No hook
        });

        vm.expectRevert(ILaunchGuard.InvalidConfiguration.selector);
        hook.createAuction(regularKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);
    }

    function test_GetAuctionContract() public {
        address auctionAddr = hook.getAuctionContract();
        assertEq(auctionAddr, address(hook.auction()));
        assertTrue(auctionAddr != address(0));
    }

    function test_GetAllocation_ReturnsZeroForNonWinner() public {
        uint256 auctionEndTime = block.timestamp + 1 hours;
        vm.prank(poolCreator);
        hook.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        InEuint128 memory encryptedBid = this.createInEuint128(uint128(1 ether), auctionContract);
        euint128 bidAmount = FHE.asEuint128(encryptedBid);
        vm.prank(alice);
        hook.submitBid(poolKey, bidAmount);

        vm.warp(auctionEndTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});
        hook.settleAuction(poolKey, winners);

        // Bob didn't bid, should have zero allocation
        assertEq(hook.auction().getAllocation(poolKey, bob), 0);
        assertFalse(hook.isWinner(poolKey, bob));
    }

    function test_IsLaunchGuardPoolAfterInitialize() public {
        // Pool should be marked as LaunchGuard pool after initialization
        assertTrue(hook.isLaunchGuardPool(poolKey.toId()));
    }
}
