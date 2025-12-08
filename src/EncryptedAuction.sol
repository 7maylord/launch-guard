// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FHE, InEuint128, euint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ILaunchGuard} from "./interface/ILaunchGuard.sol";
import {ReputationRegistry} from "./ReputationRegistry.sol";

/**
 * @title EncryptedAuction
 * @notice Manages encrypted bidding auctions using Fhenix FHE
 * @dev Handles bid submission, storage, and winner settlement
 */
contract EncryptedAuction {
    
    using FHE for euint128;
    
    // ============ State Variables ============
    
    ReputationRegistry public immutable reputationRegistry;
    
    // Pool => Auction Config
    mapping(bytes32 => ILaunchGuard.AuctionConfig) public auctions;
    
    // Pool => Bidder => Bid
    mapping(bytes32 => mapping(address => ILaunchGuard.Bid)) public bids;
    
    // Pool => Array of bidders
    mapping(bytes32 => address[]) public bidders;
    
    // Pool => Bidder => Is Winner
    mapping(bytes32 => mapping(address => bool)) public winners;
    
    // Pool => Winner allocations (decrypted amounts)
    mapping(bytes32 => mapping(address => uint256)) public allocations;
    
    // Authorized operators for settlement
    mapping(address => bool) public authorizedOperators;
    
    address public immutable owner;
    
    // ============ Events ============
    
    event AuctionCreated(
        bytes32 indexed poolId,
        uint256 auctionEndTime,
        uint256 priorityWindowDuration,
        uint256 minBidAmount,
        uint256 maxWinners
    );
    
    event BidSubmitted(
        bytes32 indexed poolId,
        address indexed bidder,
        uint256 timestamp
    );
    
    event AuctionSettled(
        bytes32 indexed poolId,
        uint256 totalBids,
        uint256 winnersCount
    );
    
    event OperatorAuthorized(address indexed operator);
    event OperatorRevoked(address indexed operator);
    
    // ============ Errors ============
    
    error AuctionAlreadyExists();
    error AuctionNotActive();
    error AuctionEnded();
    error AuctionNotEnded();
    error BidTooLow();
    error UserBlacklisted();
    error NotAuthorized();
    error InvalidConfiguration();
    error AlreadyBid();
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }
    
    modifier onlyAuthorizedOperator() {
        if (!authorizedOperators[msg.sender]) revert NotAuthorized();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _reputationRegistry) {
        owner = msg.sender;
        reputationRegistry = ReputationRegistry(_reputationRegistry);
        authorizedOperators[msg.sender] = true;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Authorize an operator for settlement
     * @param operator Address to authorize
     */
    function authorizeOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = true;
        emit OperatorAuthorized(operator);
    }
    
    /**
     * @notice Revoke operator authorization
     * @param operator Address to revoke
     */
    function revokeOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = false;
        emit OperatorRevoked(operator);
    }
    
    // ============ Auction Functions ============
    
    /**
     * @notice Create a new auction for a pool
     * @param poolKey The Uniswap v4 pool key
     * @param auctionEndTime Timestamp when auction ends
     * @param priorityWindowDuration Duration of priority trading window
     * @param minBidAmount Minimum bid amount
     * @param maxWinners Maximum number of winners
     */
    function createAuction(
        PoolKey calldata poolKey,
        uint256 auctionEndTime,
        uint256 priorityWindowDuration,
        uint256 minBidAmount,
        uint256 maxWinners
    ) external onlyOwner {
        bytes32 poolId = _getPoolId(poolKey);
        
        if (auctions[poolId].isActive) revert AuctionAlreadyExists();
        if (auctionEndTime <= block.timestamp) revert InvalidConfiguration();
        if (maxWinners == 0) revert InvalidConfiguration();
        
        auctions[poolId] = ILaunchGuard.AuctionConfig({
            auctionEndTime: auctionEndTime,
            priorityWindowDuration: priorityWindowDuration,
            minBidAmount: minBidAmount,
            maxWinners: maxWinners,
            isActive: true
        });
        
        emit AuctionCreated(poolId, auctionEndTime, priorityWindowDuration, minBidAmount, maxWinners);
    }
    
    /**
     * @notice Submit an encrypted bid
     * @param poolKey The pool to bid on
     * @param encryptedAmount Encrypted bid amount
     */
    function submitBid(
        PoolKey calldata poolKey,
        InEuint128 calldata encryptedAmount
    ) external {
        bytes32 poolId = _getPoolId(poolKey);
        ILaunchGuard.AuctionConfig memory auction = auctions[poolId];
        
        // Validation
        if (!auction.isActive) revert AuctionNotActive();
        if (block.timestamp >= auction.auctionEndTime) revert AuctionEnded();
        if (!reputationRegistry.canParticipate(msg.sender)) revert UserBlacklisted();
        if (bids[poolId][msg.sender].bidder != address(0)) revert AlreadyBid();
        
        // Convert to euint128
        euint128 amount = FHE.asEuint128(encryptedAmount);
        
        // Store bid
        bids[poolId][msg.sender] = ILaunchGuard.Bid({
            bidder: msg.sender,
            encryptedAmount: amount,
            timestamp: block.timestamp,
            isWinner: false,
            hasExecuted: false
        });
        
        bidders[poolId].push(msg.sender);
        
        // Allow contract to access encrypted amount
        FHE.allowThis(amount);
        
        emit BidSubmitted(poolId, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Settle auction with decrypted winners
     * @dev Called by authorized operators after threshold decryption
     * @param poolKey The pool to settle
     * @param winnerList Array of winners with decrypted amounts
     */
    function settleAuction(
        PoolKey calldata poolKey,
        ILaunchGuard.Winner[] calldata winnerList
    ) external onlyAuthorizedOperator {
        bytes32 poolId = _getPoolId(poolKey);
        ILaunchGuard.AuctionConfig memory auction = auctions[poolId];
        
        if (!auction.isActive) revert AuctionNotActive();
        if (block.timestamp < auction.auctionEndTime) revert AuctionNotEnded();
        
        // Mark winners
        for (uint256 i = 0; i < winnerList.length; i++) {
            address bidder = winnerList[i].bidder;
            winners[poolId][bidder] = true;
            allocations[poolId][bidder] = winnerList[i].allocation;
            bids[poolId][bidder].isWinner = true;
        }
        
        emit AuctionSettled(poolId, bidders[poolId].length, winnerList.length);
    }
    
    /**
     * @notice Mark a winner's swap as executed
     * @param poolKey The pool
     * @param winner The winner address
     */
    function markExecuted(PoolKey calldata poolKey, address winner) external {
        bytes32 poolId = _getPoolId(poolKey);
        bids[poolId][winner].hasExecuted = true;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Check if address is a winner
     * @param poolKey The pool
     * @param bidder Address to check
     */
    function isWinner(PoolKey calldata poolKey, address bidder) external view returns (bool) {
        return winners[_getPoolId(poolKey)][bidder];
    }
    
    /**
     * @notice Check if in priority window
     * @param poolKey The pool
     */
    function isInPriorityWindow(PoolKey calldata poolKey) external view returns (bool) {
        bytes32 poolId = _getPoolId(poolKey);
        ILaunchGuard.AuctionConfig memory auction = auctions[poolId];
        
        if (!auction.isActive) return false;
        if (block.timestamp < auction.auctionEndTime) return false;
        
        uint256 priorityEnd = auction.auctionEndTime + auction.priorityWindowDuration;
        return block.timestamp < priorityEnd;
    }
    
    /**
     * @notice Get auction configuration
     * @param poolKey The pool
     */
    function getAuctionConfig(PoolKey calldata poolKey) external view returns (ILaunchGuard.AuctionConfig memory) {
        return auctions[_getPoolId(poolKey)];
    }
    
    /**
     * @notice Get bid for a user
     * @param poolKey The pool
     * @param bidder The bidder address
     */
    function getBid(PoolKey calldata poolKey, address bidder) external view returns (ILaunchGuard.Bid memory) {
        return bids[_getPoolId(poolKey)][bidder];
    }
    
    /**
     * @notice Get all bidders for a pool
     * @param poolKey The pool
     */
    function getBidders(PoolKey calldata poolKey) external view returns (address[] memory) {
        return bidders[_getPoolId(poolKey)];
    }
    
    /**
     * @notice Get winner allocation
     * @param poolKey The pool
     * @param bidder The bidder address
     */
    function getAllocation(PoolKey calldata poolKey, address bidder) external view returns (uint256) {
        return allocations[_getPoolId(poolKey)][bidder];
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Generate pool ID from pool key
     * @param poolKey The pool key
     */
    function _getPoolId(PoolKey calldata poolKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(poolKey));
    }
}
