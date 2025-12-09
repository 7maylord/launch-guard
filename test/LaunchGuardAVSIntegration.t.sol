// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {LaunchGuardServiceManager} from "../src/avs/LaunchGuardServiceManager.sol";
import {ILaunchGuardAVS} from "../src/avs/ILaunchGuardAVS.sol";
import {EncryptedAuction} from "../src/EncryptedAuction.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {ILaunchGuard} from "../src/interface/ILaunchGuard.sol";
import {InEuint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title LaunchGuardAVSIntegration
 * @notice Comprehensive integration tests for LaunchGuard AVS
 * @dev Tests the full flow: FHE encryption → Operator decryption → AVS consensus → Settlement
 */
contract LaunchGuardAVSIntegrationTest is Test {

    // Contracts
    LaunchGuardServiceManager public serviceManager;
    EncryptedAuction public auction;
    ReputationRegistry public reputation;

    // Test accounts
    address public owner;
    address public operator1;
    address public operator2;
    address public operator3;
    address public bidder1;
    address public bidder2;
    address public bidder3;

    // Test pool
    PoolKey public testPool;

    // Constants
    uint256 constant OPERATOR_STAKE = 2 ether;
    uint256 constant AUCTION_DURATION = 1 hours;
    uint256 constant PRIORITY_WINDOW = 5 minutes;
    uint256 constant MIN_BID = 0.01 ether;
    uint256 constant MAX_WINNERS = 10;

    // Events to test
    event OperatorRegistered(address indexed operator, uint256 stake);
    event TaskCreated(uint32 indexed taskId, bytes32 indexed poolId, uint256 totalBidders);
    event TaskResponded(uint32 indexed taskId, address indexed operator, bytes32 winnersRoot);
    event TaskCompleted(uint32 indexed taskId, bytes32 indexed poolId, uint256 winnersCount);
    event AuctionSettled(bytes32 indexed poolId, uint256 totalBids, uint256 winnersCount);

    // Receive function to accept ETH from slashing
    receive() external payable {}

    function setUp() public {
        // Setup accounts
        owner = address(this);
        operator1 = makeAddr("operator1");
        operator2 = makeAddr("operator2");
        operator3 = makeAddr("operator3");
        bidder1 = makeAddr("bidder1");
        bidder2 = makeAddr("bidder2");
        bidder3 = makeAddr("bidder3");

        // Deploy contracts
        reputation = new ReputationRegistry();
        serviceManager = new LaunchGuardServiceManager(owner);
        auction = new EncryptedAuction(address(reputation));

        // Link contracts
        auction.setServiceManager(address(serviceManager));
        serviceManager.setAuctionContract(address(auction));

        // Setup test pool
        testPool = PoolKey({
            currency0: Currency.wrap(address(0x1)),
            currency1: Currency.wrap(address(0x2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0x3))
        });

        // Fund operators
        vm.deal(operator1, 10 ether);
        vm.deal(operator2, 10 ether);
        vm.deal(operator3, 10 ether);
    }

    // ========== Operator Registration Tests ==========

    function test_OperatorRegistration() public {
        vm.prank(operator1);
        vm.expectEmit(true, false, false, true);
        emit OperatorRegistered(operator1, OPERATOR_STAKE);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();

        assertTrue(serviceManager.isOperator(operator1));
        assertEq(serviceManager.getActiveOperatorsCount(), 1);

        ILaunchGuardAVS.OperatorInfo memory info = serviceManager.getOperatorInfo(operator1);
        assertEq(info.stake, OPERATOR_STAKE);
        assertTrue(info.isActive);
    }

    function test_RevertWhen_InsufficientStake() public {
        vm.prank(operator1);
        vm.expectRevert(ILaunchGuardAVS.InsufficientStake.selector);
        serviceManager.registerOperator{value: 0.5 ether}();
    }

    function test_RevertWhen_AlreadyRegistered() public {
        vm.prank(operator1);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();

        vm.prank(operator1);
        vm.expectRevert(ILaunchGuardAVS.OperatorAlreadyRegistered.selector);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();
    }

    function test_OperatorDeregistration() public {
        // Register
        vm.prank(operator1);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();

        uint256 balanceBefore = operator1.balance;

        // Deregister
        vm.prank(operator1);
        serviceManager.deregisterOperator();

        assertFalse(serviceManager.isOperator(operator1));
        assertEq(serviceManager.getActiveOperatorsCount(), 0);
        assertEq(operator1.balance, balanceBefore + OPERATOR_STAKE);
    }

    // ========== Task Creation Tests ==========

    function test_TaskCreation() public {
        // Register operators
        registerOperators();

        // Create auction
        auction.createAuction(
            testPool,
            block.timestamp + AUCTION_DURATION,
            PRIORITY_WINDOW,
            MIN_BID,
            MAX_WINNERS
        );

        // Fast forward past auction end
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // Create task
        bytes32 poolId = getPoolId(testPool);
        vm.expectEmit(true, true, false, true);
        emit TaskCreated(1, poolId, 0);

        auction.createSettlementTask(testPool);

        ILaunchGuardAVS.Task memory task = serviceManager.getTask(1);
        assertEq(task.taskId, 1);
        assertEq(task.poolId, poolId);
        assertEq(task.totalBidders, 0);
    }

    function test_RevertWhen_CreateTaskWithoutOperators() public {
        // Try to create task without any operators registered
        auction.createAuction(
            testPool,
            block.timestamp + AUCTION_DURATION,
            PRIORITY_WINDOW,
            MIN_BID,
            MAX_WINNERS
        );

        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        vm.expectRevert(ILaunchGuardAVS.OperatorNotRegistered.selector);
        auction.createSettlementTask(testPool);
    }

    // ========== Task Response Tests ==========

    function test_OperatorRespondToTask() public {
        // Setup: Register operators and create task
        registerOperators();
        uint32 taskId = createTestTask();

        // Create mock winners
        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](2);
        winners[0] = ILaunchGuard.Winner({
            bidder: bidder1,
            amount: 1 ether,
            allocation: 0.5 ether
        });
        winners[1] = ILaunchGuard.Winner({
            bidder: bidder2,
            amount: 0.8 ether,
            allocation: 0.4 ether
        });

        bytes32 winnersRoot = keccak256(abi.encode(winners));

        // Operator responds
        vm.prank(operator1);
        vm.expectEmit(true, true, false, true);
        emit TaskResponded(taskId, operator1, winnersRoot);

        serviceManager.respondToTask(taskId, winners, winnersRoot);

        ILaunchGuardAVS.TaskResponse[] memory responses = serviceManager.getTaskResponses(taskId);
        assertEq(responses.length, 1);
        assertEq(responses[0].operator, operator1);
        assertEq(responses[0].winnersRoot, winnersRoot);
    }

    function test_RevertWhen_NonOperatorResponds() public {
        registerOperators();
        uint32 taskId = createTestTask();

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](0);
        bytes32 winnersRoot = keccak256(abi.encode(winners));

        vm.prank(makeAddr("nonOperator"));
        vm.expectRevert(ILaunchGuardAVS.OperatorNotRegistered.selector);
        serviceManager.respondToTask(taskId, winners, winnersRoot);
    }

    function test_RevertWhen_OperatorRespondsTwice() public {
        registerOperators();
        uint32 taskId = createTestTask();

        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](0);
        bytes32 winnersRoot = keccak256(abi.encode(winners));

        // First response
        vm.prank(operator1);
        serviceManager.respondToTask(taskId, winners, winnersRoot);

        // Second response
        vm.prank(operator1);
        vm.expectRevert(ILaunchGuardAVS.InvalidResponse.selector);
        serviceManager.respondToTask(taskId, winners, winnersRoot);
    }

    // ========== Consensus Tests ==========

    function test_QuorumReached() public {
        registerOperators();
        uint32 taskId = createTestTask();

        ILaunchGuard.Winner[] memory winners = createMockWinners();
        bytes32 winnersRoot = keccak256(abi.encode(winners));

        // 2 out of 3 operators agree (67% quorum)
        vm.prank(operator1);
        serviceManager.respondToTask(taskId, winners, winnersRoot);

        assertFalse(serviceManager.hasReachedQuorum(taskId));

        vm.prank(operator2);
        vm.expectEmit(true, true, false, true);
        emit TaskCompleted(taskId, getPoolId(testPool), winners.length);

        serviceManager.respondToTask(taskId, winners, winnersRoot);

        assertTrue(serviceManager.hasReachedQuorum(taskId));
    }

    function test_QuorumNotReachedWithDifferentRoots() public {
        registerOperators();
        uint32 taskId = createTestTask();

        ILaunchGuard.Winner[] memory winners1 = createMockWinners();
        ILaunchGuard.Winner[] memory winners2 = createAlternateWinners();

        bytes32 root1 = keccak256(abi.encode(winners1));
        bytes32 root2 = keccak256(abi.encode(winners2));

        // Operators disagree
        vm.prank(operator1);
        serviceManager.respondToTask(taskId, winners1, root1);

        vm.prank(operator2);
        serviceManager.respondToTask(taskId, winners2, root2);

        assertFalse(serviceManager.hasReachedQuorum(taskId));
    }

    // ========== Slashing Tests ==========

    function test_SlashOperator() public {
        vm.prank(operator1);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();

        uint256 slashAmount = 0.1 ether;

        vm.expectEmit(true, false, false, true);
        emit ILaunchGuardAVS.OperatorSlashed(operator1, slashAmount, "Test slash");

        serviceManager.slashOperator(operator1, slashAmount, "Test slash");

        ILaunchGuardAVS.OperatorInfo memory info = serviceManager.getOperatorInfo(operator1);
        assertEq(info.stake, OPERATOR_STAKE - slashAmount);
        assertEq(info.slashedAmount, slashAmount);
    }

    function test_ChallengeResponse() public {
        registerOperators();
        uint32 taskId = createTestTask();

        ILaunchGuard.Winner[] memory winners = createMockWinners();
        bytes32 winnersRoot = keccak256(abi.encode(winners));

        vm.prank(operator1);
        serviceManager.respondToTask(taskId, winners, winnersRoot);

        uint256 stakeBefore = serviceManager.getOperatorInfo(operator1).stake;

        // Challenge the response
        bytes memory proof = abi.encode("malicious proof");
        serviceManager.challengeResponse(taskId, operator1, proof);

        uint256 stakeAfter = serviceManager.getOperatorInfo(operator1).stake;
        assertEq(stakeBefore - stakeAfter, serviceManager.SLASH_AMOUNT());
    }

    // ========== Full Integration Test ==========

    function test_FullAuctionFlow() public {
        console.log("=== Full LaunchGuard AVS Integration Test ===");

        // 1. Register operators
        console.log("Step 1: Registering 3 operators...");
        registerOperators();
        assertEq(serviceManager.getActiveOperatorsCount(), 3);

        // 2. Create auction
        console.log("Step 2: Creating auction...");
        auction.createAuction(
            testPool,
            block.timestamp + AUCTION_DURATION,
            PRIORITY_WINDOW,
            MIN_BID,
            MAX_WINNERS
        );

        // 3. Submit bids (simulated)
        console.log("Step 3: Simulating bids...");
        // In real scenario, bidders would submit encrypted bids
        // For test, we'll just create the task

        // 4. Fast forward past auction end
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // 5. Create settlement task
        console.log("Step 4: Creating settlement task...");
        auction.createSettlementTask(testPool);

        // 6. Operators decrypt and respond
        console.log("Step 5: Operators responding with decrypted results...");
        ILaunchGuard.Winner[] memory winners = createMockWinners();
        bytes32 winnersRoot = keccak256(abi.encode(winners));

        vm.prank(operator1);
        serviceManager.respondToTask(1, winners, winnersRoot);

        vm.prank(operator2);
        serviceManager.respondToTask(1, winners, winnersRoot);

        // 7. Verify consensus reached
        console.log("Step 6: Verifying consensus...");
        assertTrue(serviceManager.hasReachedQuorum(1));

        // 8. Settle auction (would be called by AVS)
        console.log("Step 7: Settling auction...");
        vm.prank(operator1);
        auction.settleAuction(testPool, winners);

        console.log("=== Test Complete ===");
    }

    // ========== Helper Functions ==========

    function registerOperators() internal {
        vm.prank(operator1);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();

        vm.prank(operator2);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();

        vm.prank(operator3);
        serviceManager.registerOperator{value: OPERATOR_STAKE}();
    }

    function createTestTask() internal returns (uint32) {
        auction.createAuction(
            testPool,
            block.timestamp + AUCTION_DURATION,
            PRIORITY_WINDOW,
            MIN_BID,
            MAX_WINNERS
        );

        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        auction.createSettlementTask(testPool);

        return 1; // First task ID
    }

    function createMockWinners() internal view returns (ILaunchGuard.Winner[] memory) {
        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](2);
        winners[0] = ILaunchGuard.Winner({
            bidder: bidder1,
            amount: 1 ether,
            allocation: 0.6 ether
        });
        winners[1] = ILaunchGuard.Winner({
            bidder: bidder2,
            amount: 0.8 ether,
            allocation: 0.4 ether
        });
        return winners;
    }

    function createAlternateWinners() internal view returns (ILaunchGuard.Winner[] memory) {
        ILaunchGuard.Winner[] memory winners = new ILaunchGuard.Winner[](2);
        winners[0] = ILaunchGuard.Winner({
            bidder: bidder2,
            amount: 1.1 ether,
            allocation: 0.7 ether
        });
        winners[1] = ILaunchGuard.Winner({
            bidder: bidder3,
            amount: 0.9 ether,
            allocation: 0.3 ether
        });
        return winners;
    }

    function getPoolId(PoolKey memory poolKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(poolKey));
    }
}
