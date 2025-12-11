// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EncryptedAuction} from "../src/EncryptedAuction.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {ILaunchGuard} from "../src/interface/ILaunchGuard.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {CoFheTest} from "@fhenixprotocol/cofhe-foundry-mocks/CoFheTest.sol";
import {FHE, euint128, InEuint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";


/**
 * @title EncryptedAuctionTest
 * @notice Comprehensive tests for EncryptedAuction contract
 */
contract EncryptedAuctionTest is Test {
    using FHE for euint128;

    EncryptedAuction public auction;
    ReputationRegistry public reputationRegistry;
    CoFheTest public CFT;

    // Test addresses
    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public dave = makeAddr("dave");
    address public eve = makeAddr("eve");

    // Test pool key
    PoolKey public poolKey;

    function setUp() public {
        CFT = new CoFheTest(true);
        reputationRegistry = new ReputationRegistry();
        auction = new EncryptedAuction(address(reputationRegistry));

        // Create test pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(makeAddr("token0")),
            currency1: Currency.wrap(makeAddr("token1")),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(makeAddr("hook"))
        });

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(dave, "Dave");
        vm.label(eve, "Eve");
    }

    // ============================================================================
    // Auction Creation Tests
    // ============================================================================

    function test_CreateAuction_Success() public {
        uint256 auctionEndTime = block.timestamp + 1 hours;
        uint256 priorityWindow = 30 minutes;
        uint256 minBid = 0.1 ether;
        uint256 maxWinners = 10;

        auction.createAuction(
            poolKey,
            auctionEndTime,
            priorityWindow,
            minBid,
            maxWinners
        );

        ILaunchGuard.AuctionConfig memory config = auction.getAuctionConfig(poolKey);
        assertEq(config.auctionEndTime, auctionEndTime);
        assertEq(config.priorityWindowDuration, priorityWindow);
        assertEq(config.minBidAmount, minBid);
        assertEq(config.maxWinners, maxWinners);
        assertTrue(config.isActive);
    }

    function test_RevertWhen_CreateAuctionTwice() public {
        uint256 auctionEndTime = block.timestamp + 1 hours;

        auction.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);

        vm.expectRevert(EncryptedAuction.AuctionAlreadyExists.selector);
        auction.createAuction(poolKey, auctionEndTime, 30 minutes, 0.1 ether, 10);
    }

    function test_RevertWhen_EndTimeInPast() public {
        vm.expectRevert(EncryptedAuction.InvalidConfiguration.selector);
        auction.createAuction(poolKey, block.timestamp - 1, 30 minutes, 0.1 ether, 10);
    }

    function test_RevertWhen_MaxWinnersZero() public {
        vm.expectRevert(EncryptedAuction.InvalidConfiguration.selector);
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 0);
    }

    // ============================================================================
    // Bid Submission Tests
    // ============================================================================

    function test_SubmitBid_Success() public {
        // Create auction
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);

        // Create encrypted bid
        vm.startPrank(alice);
        InEuint128 memory encryptedBid = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, encryptedBid);
        vm.stopPrank();

        // Verify bid was recorded
        address[] memory bidders = auction.getBidders(poolKey);
        assertEq(bidders.length, 1);
        assertEq(bidders[0], alice);
    }

    function test_SubmitMultipleBids() public {
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);

        // Alice bids
        vm.startPrank(alice);
        InEuint128 memory bidAlice = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, bidAlice);
        vm.stopPrank();

        // Bob bids
        vm.startPrank(bob);
        InEuint128 memory bidBob = CFT.createInEuint128(uint128(2 ether), address(auction));
        auction.submitBid(poolKey, bidBob);
        vm.stopPrank();

        // Charlie bids
        vm.startPrank(charlie);
        InEuint128 memory bidCharlie = CFT.createInEuint128(uint128(0.5 ether), address(auction));
        auction.submitBid(poolKey, bidCharlie);
        vm.stopPrank();

        address[] memory bidders = auction.getBidders(poolKey);
        assertEq(bidders.length, 3);
        assertEq(bidders[0], alice);
        assertEq(bidders[1], bob);
        assertEq(bidders[2], charlie);
    }

    function test_RevertWhen_BidTwice() public {
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);

        vm.startPrank(alice);
        InEuint128 memory encryptedBid1 = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, encryptedBid1);

        InEuint128 memory encryptedBid2 = CFT.createInEuint128(uint128(2 ether), address(auction));
        vm.expectRevert(EncryptedAuction.AlreadyBid.selector);
        auction.submitBid(poolKey, encryptedBid2);
        vm.stopPrank();
    }

    function test_RevertWhen_BidAfterAuctionEnds() public {
        uint256 endTime = block.timestamp + 1 hours;
        auction.createAuction(poolKey, endTime, 30 minutes, 0.1 ether, 10);

        // Warp past auction end
        vm.warp(endTime + 1);

        vm.startPrank(alice);
        InEuint128 memory encryptedBid = CFT.createInEuint128(uint128(1 ether), address(auction));
        vm.expectRevert(EncryptedAuction.AuctionEnded.selector);
        auction.submitBid(poolKey, encryptedBid);
        vm.stopPrank();
    }

    function test_RevertWhen_BidOnNonexistentAuction() public {
        vm.startPrank(alice);
        InEuint128 memory encryptedBid = CFT.createInEuint128(uint128(1 ether), address(auction));
        vm.expectRevert(EncryptedAuction.AuctionNotActive.selector);
        auction.submitBid(poolKey, encryptedBid);
        vm.stopPrank();
    }

    // ============================================================================
    // Settlement Tests
    // ============================================================================

    function test_SettleAuction_Success() public {
        // Create auction and submit bids
        uint256 endTime = block.timestamp + 1 hours;
        auction.createAuction(poolKey, endTime, 30 minutes, 0.1 ether, 10);

        vm.startPrank(alice);
        InEuint128 memory bidAlice = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, bidAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        InEuint128 memory bidBob = CFT.createInEuint128(uint128(2 ether), address(auction));
        auction.submitBid(poolKey, bidBob);
        vm.stopPrank();

        // Warp past auction end
        vm.warp(endTime + 1);

        // Settle auction
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

        auction.settleAuction(poolKey, winners);

        // Verify settlement
        assertTrue(auction.isWinner(poolKey, alice));
        assertTrue(auction.isWinner(poolKey, bob));
        assertEq(auction.getAllocation(poolKey, alice), 1000);
        assertEq(auction.getAllocation(poolKey, bob), 2000);

        ILaunchGuard.AuctionConfig memory config = auction.getAuctionConfig(poolKey);
        assertFalse(config.isActive);
    }

    function test_SettleAuction_WithMaxWinnersLimit() public {
        uint256 endTime = block.timestamp + 1 hours;
        auction.createAuction(poolKey, endTime, 30 minutes, 0.1 ether, 2); // Only 2 winners allowed

        // Submit 4 bids
        address[4] memory bidders = [alice, bob, charlie, dave];
        for (uint i = 0; i < 4; i++) {
            vm.startPrank(bidders[i]);
            InEuint128 memory bid = CFT.createInEuint128(uint128((i + 1) * 1 ether), address(auction));
            auction.submitBid(poolKey, bid);
            vm.stopPrank();
        }

        vm.warp(endTime + 1);

        // Settle with top 2 bidders
        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](2);
        winners[0] = ILaunchGuard.Winner({bidder: dave, amount: 4 ether, allocation: 4000});
        winners[1] = ILaunchGuard.Winner({bidder: charlie, amount: 3 ether, allocation: 3000});

        auction.settleAuction(poolKey, winners);

        assertTrue(auction.isWinner(poolKey, dave));
        assertTrue(auction.isWinner(poolKey, charlie));
        assertFalse(auction.isWinner(poolKey, bob));
        assertFalse(auction.isWinner(poolKey, alice));
    }

    function test_RevertWhen_SettleBeforeAuctionEnds() public {
        uint256 endTime = block.timestamp + 1 hours;
        auction.createAuction(poolKey, endTime, 30 minutes, 0.1 ether, 10);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](0);
        vm.expectRevert(EncryptedAuction.AuctionNotEnded.selector);
        auction.settleAuction(poolKey, winners);
    }

    function test_RevertWhen_SettleTwice() public {
        uint256 endTime = block.timestamp + 1 hours;
        auction.createAuction(poolKey, endTime, 30 minutes, 0.1 ether, 10);

        vm.startPrank(alice);
        InEuint128 memory bidAlice = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, bidAlice);
        vm.stopPrank();

        vm.warp(endTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});

        auction.settleAuction(poolKey, winners);

        vm.expectRevert(EncryptedAuction.AuctionNotActive.selector);
        auction.settleAuction(poolKey, winners);
    }

    // TODO: Add test for too many winners once maxWinners validation is added to settleAuction

    // ============================================================================
    // Priority Window Tests
    // ============================================================================

    function test_PriorityWindow_IsActive() public {
        uint256 endTime = block.timestamp + 1 hours;
        uint256 priorityWindow = 30 minutes;
        auction.createAuction(poolKey, endTime, priorityWindow, 0.1 ether, 10);

        vm.startPrank(alice);
        InEuint128 memory bidAlice = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, bidAlice);
        vm.stopPrank();

        vm.warp(endTime + 1);

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](1);
        winners[0] = ILaunchGuard.Winner({bidder: alice, amount: 1 ether, allocation: 1000});
        auction.settleAuction(poolKey, winners);

        // Priority window should be active
        assertTrue(auction.isInPriorityWindow(poolKey));

        // Warp to end of priority window
        vm.warp(endTime + priorityWindow + 1);
        assertFalse(auction.isInPriorityWindow(poolKey));
    }

    function test_PriorityWindow_MultipleWinners() public {
        uint256 endTime = block.timestamp + 1 hours;
        auction.createAuction(poolKey, endTime, 30 minutes, 0.1 ether, 10);

        // Submit multiple bids
        address[5] memory bidders = [alice, bob, charlie, dave, eve];
        for (uint i = 0; i < 5; i++) {
            vm.startPrank(bidders[i]);
            InEuint128 memory bid = CFT.createInEuint128(uint128((i + 1) * 1 ether), address(auction));
            auction.submitBid(poolKey, bid);
            vm.stopPrank();
        }

        vm.warp(endTime + 1);

        // Top 3 winners
        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](3);
        winners[0] = ILaunchGuard.Winner({bidder: eve, amount: 5 ether, allocation: 5000});
        winners[1] = ILaunchGuard.Winner({bidder: dave, amount: 4 ether, allocation: 4000});
        winners[2] = ILaunchGuard.Winner({bidder: charlie, amount: 3 ether, allocation: 3000});

        auction.settleAuction(poolKey, winners);

        // Verify winners
        assertTrue(auction.isWinner(poolKey, eve));
        assertTrue(auction.isWinner(poolKey, dave));
        assertTrue(auction.isWinner(poolKey, charlie));
        assertFalse(auction.isWinner(poolKey, bob));
        assertFalse(auction.isWinner(poolKey, alice));

        // Verify allocations
        assertEq(auction.getAllocation(poolKey, eve), 5000);
        assertEq(auction.getAllocation(poolKey, dave), 4000);
        assertEq(auction.getAllocation(poolKey, charlie), 3000);
        assertEq(auction.getAllocation(poolKey, bob), 0);
        assertEq(auction.getAllocation(poolKey, alice), 0);
    }

    // ============================================================================
    // View Function Tests
    // ============================================================================

    function test_GetBidders_EmptyAuction() public {
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);

        address[] memory bidders = auction.getBidders(poolKey);
        assertEq(bidders.length, 0);
    }

    function test_GetBidders_WithBids() public {
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);

        address[3] memory testBidders = [alice, bob, charlie];
        for (uint i = 0; i < 3; i++) {
            vm.startPrank(testBidders[i]);
            InEuint128 memory bid = CFT.createInEuint128(uint128(1 ether), address(auction));
            auction.submitBid(poolKey, bid);
            vm.stopPrank();
        }

        address[] memory bidders = auction.getBidders(poolKey);
        assertEq(bidders.length, 3);
        assertEq(bidders[0], alice);
        assertEq(bidders[1], bob);
        assertEq(bidders[2], charlie);
    }

    function test_IsWinner_BeforeSettlement() public {
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);

        vm.startPrank(alice);
        InEuint128 memory bidAlice = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, bidAlice);
        vm.stopPrank();

        assertFalse(auction.isWinner(poolKey, alice));
    }

    function test_GetAllocation_BeforeSettlement() public {
        auction.createAuction(poolKey, block.timestamp + 1 hours, 30 minutes, 0.1 ether, 10);

        vm.startPrank(alice);
        InEuint128 memory bidAlice = CFT.createInEuint128(uint128(1 ether), address(auction));
        auction.submitBid(poolKey, bidAlice);
        vm.stopPrank();

        assertEq(auction.getAllocation(poolKey, alice), 0);
    }
}
