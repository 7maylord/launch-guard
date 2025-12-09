// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ILaunchGuard} from "../interface/ILaunchGuard.sol";
import {ILaunchGuardAVS} from "./ILaunchGuardAVS.sol";

/**
 * @title LaunchGuardServiceManager
 * @notice Manages the LaunchGuard AVS - operator registration, task distribution, and consensus
 * @dev This is the core AVS contract that coordinates decentralized auction settlement
 */
contract LaunchGuardServiceManager is ILaunchGuardAVS {

    // ============ Constants ============

    uint256 public constant MINIMUM_STAKE = 0.01 ether;// for production, set to 1 ether
    uint256 public constant SLASH_AMOUNT = 0.001 ether;// for production, set to 0.1 ether
    uint8 public constant DEFAULT_QUORUM_THRESHOLD = 67; // 67% of operators must agree
    uint256 public constant CHALLENGE_WINDOW = 50400; // ~7 days in blocks

    // ============ State Variables ============

    address public immutable owner;
    address public auctionContract;

    // Operator registry
    mapping(address => OperatorInfo) public operators;
    address[] public operatorList;
    uint256 public totalActiveOperators;

    // Task management
    mapping(uint32 => Task) public tasks;
    mapping(uint32 => TaskResponse[]) public taskResponses;
    mapping(uint32 => mapping(bytes32 => uint256)) public responseVotes; // taskId => winnersRoot => voteCount
    mapping(uint32 => bool) public taskCompleted;
    uint32 public nextTaskId;

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedCaller();
        _;
    }

    modifier onlyAuctionContract() {
        if (msg.sender != auctionContract) revert UnauthorizedCaller();
        _;
    }

    modifier onlyRegisteredOperator() {
        if (!isOperator(msg.sender)) revert OperatorNotRegistered();
        _;
    }

    // ============ Constructor ============

    constructor(address _owner) {
        owner = _owner;
        nextTaskId = 1;
    }

    /**
     * @notice Set the auction contract address
     * @param _auctionContract Address of EncryptedAuction contract
     */
    function setAuctionContract(address _auctionContract) external onlyOwner {
        auctionContract = _auctionContract;
    }

    // ============ Operator Management ============

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function registerOperator() external payable override {
        if (operators[msg.sender].operatorAddress != address(0)) {
            revert OperatorAlreadyRegistered();
        }
        if (msg.value < MINIMUM_STAKE) {
            revert InsufficientStake();
        }

        operators[msg.sender] = OperatorInfo({
            operatorAddress: msg.sender,
            isActive: true,
            stake: msg.value,
            taskResponses: 0,
            slashedAmount: 0
        });

        operatorList.push(msg.sender);
        totalActiveOperators++;

        emit OperatorRegistered(msg.sender, msg.value);
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function deregisterOperator() external override onlyRegisteredOperator {
        OperatorInfo storage op = operators[msg.sender];
        op.isActive = false;
        totalActiveOperators--;

        // Return stake minus any slashed amount
        uint256 returnAmount = op.stake - op.slashedAmount;
        op.stake = 0;

        emit OperatorDeregistered(msg.sender);

        (bool success, ) = msg.sender.call{value: returnAmount}("");
        require(success, "Transfer failed");
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function isOperator(address operator) public view override returns (bool) {
        return operators[operator].isActive;
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function getOperatorInfo(address operator) external view override returns (OperatorInfo memory) {
        return operators[operator];
    }

    // ============ Task Management ============

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function createTask(
        PoolKey calldata poolKey,
        uint256 totalBidders
    ) external override onlyAuctionContract returns (uint32 taskId) {
        if (totalActiveOperators == 0) revert OperatorNotRegistered();

        taskId = nextTaskId++;
        bytes32 poolId = _getPoolId(poolKey);

        tasks[taskId] = Task({
            taskId: taskId,
            poolId: poolId,
            auctionEndTime: block.timestamp,
            totalBidders: totalBidders,
            taskCreatedBlock: uint32(block.number),
            quorumThresholdPercentage: DEFAULT_QUORUM_THRESHOLD
        });

        emit TaskCreated(taskId, poolId, totalBidders);
        return taskId;
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function respondToTask(
        uint32 taskId,
        ILaunchGuard.Winner[] calldata winners,
        bytes32 winnersRoot
    ) external override onlyRegisteredOperator {
        Task storage task = tasks[taskId];
        if (task.taskId == 0) revert TaskDoesNotExist();
        if (taskCompleted[taskId]) revert TaskAlreadyCompleted();

        // Verify operator hasn't already responded
        TaskResponse[] storage responses = taskResponses[taskId];
        for (uint256 i = 0; i < responses.length; i++) {
            if (responses[i].operator == msg.sender) {
                revert InvalidResponse();
            }
        }

        // Store response (without full winners array to save gas)
        TaskResponse memory response = TaskResponse({
            taskId: taskId,
            operator: msg.sender,
            winnersRoot: winnersRoot,
            winnersCount: winners.length,
            signedAt: block.timestamp
        });

        responses.push(response);
        responseVotes[taskId][winnersRoot]++;
        operators[msg.sender].taskResponses++;

        emit TaskResponded(taskId, msg.sender, winnersRoot);

        // Auto-complete if quorum reached
        if (hasReachedQuorum(taskId)) {
            _completeTask(taskId);
        }
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function completeTask(uint32 taskId) external override {
        if (!hasReachedQuorum(taskId)) revert QuorumNotReached();
        _completeTask(taskId);
    }

    /**
     * @notice Internal function to complete a task
     */
    function _completeTask(uint32 taskId) internal {
        if (taskCompleted[taskId]) revert TaskAlreadyCompleted();

        Task storage task = tasks[taskId];
        taskCompleted[taskId] = true;

        // Find consensus response (most votes)
        bytes32 consensusRoot = _findConsensusRoot(taskId);
        uint256 winnersCount = _getWinnersCountForRoot(taskId, consensusRoot);

        emit TaskCompleted(taskId, task.poolId, winnersCount);

        // Note: Actual settlement would be called here in production
        // This requires calling back to EncryptedAuction.settleAuction() with the winners
        // The winners array would need to be passed from off-chain or reconstructed
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function getTask(uint32 taskId) external view override returns (Task memory) {
        return tasks[taskId];
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function hasReachedQuorum(uint32 taskId) public view override returns (bool) {
        Task storage task = tasks[taskId];
        if (task.taskId == 0) return false;

        TaskResponse[] storage responses = taskResponses[taskId];
        uint256 requiredVotes = (totalActiveOperators * task.quorumThresholdPercentage) / 100;

        // Check if any response has enough votes
        bytes32 topRoot = _findConsensusRoot(taskId);
        return responseVotes[taskId][topRoot] >= requiredVotes;
    }

    /**
     * @notice Find the winners root with most votes
     */
    function _findConsensusRoot(uint32 taskId) internal view returns (bytes32) {
        TaskResponse[] storage responses = taskResponses[taskId];
        bytes32 topRoot;
        uint256 topVotes = 0;

        for (uint256 i = 0; i < responses.length; i++) {
            bytes32 root = responses[i].winnersRoot;
            uint256 votes = responseVotes[taskId][root];
            if (votes > topVotes) {
                topVotes = votes;
                topRoot = root;
            }
        }

        return topRoot;
    }

    /**
     * @notice Get winners count for a specific root
     */
    function _getWinnersCountForRoot(
        uint32 taskId,
        bytes32 winnersRoot
    ) internal view returns (uint256) {
        TaskResponse[] storage responses = taskResponses[taskId];

        for (uint256 i = 0; i < responses.length; i++) {
            if (responses[i].winnersRoot == winnersRoot) {
                return responses[i].winnersCount;
            }
        }

        return 0;
    }

    // ============ Slashing ============

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function slashOperator(
        address operator,
        uint256 amount,
        string calldata reason
    ) external override onlyOwner {
        _slashOperator(operator, amount, reason);
    }

    /**
     * @notice Internal slash operator function
     */
    function _slashOperator(
        address operator,
        uint256 amount,
        string memory reason
    ) internal {
        OperatorInfo storage op = operators[operator];
        if (!op.isActive) revert OperatorNotRegistered();

        uint256 slashAmount = amount > op.stake ? op.stake : amount;
        op.stake -= slashAmount;
        op.slashedAmount += slashAmount;

        emit OperatorSlashed(operator, slashAmount, reason);

        // Send slashed funds to owner (treasury)
        (bool success, ) = owner.call{value: slashAmount}("");
        require(success, "Slash transfer failed");
    }

    /**
     * @inheritdoc ILaunchGuardAVS
     */
    function challengeResponse(
        uint32 taskId,
        address operator,
        bytes calldata proof
    ) external override onlyOwner {
        Task storage task = tasks[taskId];
        if (task.taskId == 0) revert TaskDoesNotExist();

        // Check challenge is within window
        if (block.number > task.taskCreatedBlock + CHALLENGE_WINDOW) {
            revert InvalidResponse();
        }

        // Verify operator submitted a response
        TaskResponse[] storage responses = taskResponses[taskId];
        bool found = false;
        for (uint256 i = 0; i < responses.length; i++) {
            if (responses[i].operator == operator) {
                found = true;
                break;
            }
        }

        if (!found) revert InvalidResponse();

        // In production: Verify proof and slash if malicious
        // For now: Simple slash - call internal version
        _slashOperator(operator, SLASH_AMOUNT, "Invalid task response");
    }

    // ============ Helper Functions ============

    /**
     * @notice Compute pool ID from PoolKey
     */
    function _getPoolId(PoolKey calldata poolKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(poolKey));
    }

    /**
     * @notice Get all responses for a task
     */
    function getTaskResponses(uint32 taskId) external view returns (TaskResponse[] memory) {
        return taskResponses[taskId];
    }

    /**
     * @notice Get number of operators
     */
    function getOperatorCount() external view returns (uint256) {
        return operatorList.length;
    }

    /**
     * @notice Get all operators
     */
    function getAllOperators() external view returns (address[] memory) {
        return operatorList;
    }

    /**
     * @notice Get active operators count
     */
    function getActiveOperatorsCount() external view returns (uint256) {
        return totalActiveOperators;
    }
}
