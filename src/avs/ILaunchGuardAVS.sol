// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ILaunchGuard} from "../interface/ILaunchGuard.sol";

/**
 * @title ILaunchGuardAVS
 * @notice Interface for LaunchGuard AVS (Actively Validated Service)
 * @dev Defines the AVS-specific functions for operator management and task coordination
 */
interface ILaunchGuardAVS {

    // ============ Structs ============

    /**
     * @notice Task for operators to decrypt and settle an auction
     * @param taskId Unique identifier for the task
     * @param poolId Pool identifier (hash of PoolKey)
     * @param auctionEndTime When the auction ended
     * @param totalBidders Number of bidders in the auction
     * @param taskCreatedBlock Block number when task was created
     * @param quorumThresholdPercentage Percentage of operators needed to agree (e.g., 67 = 67%)
     */
    struct Task {
        uint32 taskId;
        bytes32 poolId;
        uint256 auctionEndTime;
        uint256 totalBidders;
        uint32 taskCreatedBlock;
        uint8 quorumThresholdPercentage;
    }

    /**
     * @notice Response from an operator for a settlement task
     * @param taskId The task being responded to
     * @param operator Address of the responding operator
     * @param winnersRoot Merkle root of the winners list for verification
     * @param winnersCount Number of winners proposed
     * @param signedAt Block number when response was signed
     */
    struct TaskResponse {
        uint32 taskId;
        address operator;
        bytes32 winnersRoot;
        uint256 winnersCount;
        uint256 signedAt;
    }

    /**
     * @notice Operator information
     * @param operatorAddress Address of the operator
     * @param isActive Whether operator is currently active
     * @param stake Amount of stake (for slashing)
     * @param taskResponses Number of tasks responded to
     * @param slashedAmount Total amount slashed
     */
    struct OperatorInfo {
        address operatorAddress;
        bool isActive;
        uint256 stake;
        uint256 taskResponses;
        uint256 slashedAmount;
    }

    // ============ Events ============

    event TaskCreated(uint32 indexed taskId, bytes32 indexed poolId, uint256 totalBidders);
    event TaskResponded(uint32 indexed taskId, address indexed operator, bytes32 winnersRoot);
    event TaskCompleted(uint32 indexed taskId, bytes32 indexed poolId, uint256 winnersCount);
    event OperatorRegistered(address indexed operator, uint256 stake);
    event OperatorDeregistered(address indexed operator);
    event OperatorSlashed(address indexed operator, uint256 amount, string reason);

    // ============ Errors ============

    error OperatorNotRegistered();
    error OperatorAlreadyRegistered();
    error InsufficientStake();
    error TaskDoesNotExist();
    error TaskAlreadyCompleted();
    error InvalidResponse();
    error QuorumNotReached();
    error UnauthorizedCaller();

    // ============ Operator Management ============

    /**
     * @notice Register as an operator with stake
     * @dev Operator must provide minimum stake
     */
    function registerOperator() external payable;

    /**
     * @notice Deregister as an operator and withdraw stake
     * @dev Can only deregister if no pending tasks
     */
    function deregisterOperator() external;

    /**
     * @notice Check if address is a registered operator
     * @param operator Address to check
     * @return bool True if registered and active
     */
    function isOperator(address operator) external view returns (bool);

    /**
     * @notice Get operator information
     * @param operator Address of operator
     * @return OperatorInfo Operator details
     */
    function getOperatorInfo(address operator) external view returns (OperatorInfo memory);

    // ============ Task Management ============

    /**
     * @notice Create a new settlement task for operators
     * @param poolKey The pool that needs settlement
     * @param totalBidders Number of bidders to decrypt
     * @return taskId The created task ID
     */
    function createTask(
        PoolKey calldata poolKey,
        uint256 totalBidders
    ) external returns (uint32 taskId);

    /**
     * @notice Submit response to a settlement task
     * @param taskId The task being responded to
     * @param winners Proposed winners with allocations
     * @param winnersRoot Merkle root for verification
     */
    function respondToTask(
        uint32 taskId,
        ILaunchGuard.Winner[] calldata winners,
        bytes32 winnersRoot
    ) external;

    /**
     * @notice Aggregate responses and complete task if quorum reached
     * @param taskId The task to complete
     */
    function completeTask(uint32 taskId) external;

    /**
     * @notice Get task details
     * @param taskId Task identifier
     * @return Task Task information
     */
    function getTask(uint32 taskId) external view returns (Task memory);

    /**
     * @notice Check if task has reached quorum
     * @param taskId Task identifier
     * @return bool True if quorum reached
     */
    function hasReachedQuorum(uint32 taskId) external view returns (bool);

    // ============ Slashing ============

    /**
     * @notice Slash an operator for malicious behavior
     * @param operator Address to slash
     * @param amount Amount to slash
     * @param reason Reason for slashing
     */
    function slashOperator(
        address operator,
        uint256 amount,
        string calldata reason
    ) external;

    /**
     * @notice Challenge a task response
     * @param taskId Task to challenge
     * @param operator Operator who submitted incorrect response
     * @param proof Proof of incorrect behavior
     */
    function challengeResponse(
        uint32 taskId,
        address operator,
        bytes calldata proof
    ) external;
}
