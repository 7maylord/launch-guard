// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReputationRegistry
 * @notice Manages user reputation for LaunchGuard auctions
 * @dev Tracks blacklisted addresses and community members with bonuses
 */
contract ReputationRegistry is Ownable {
    
    // ============ State Variables ============
    
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isCommunityMember;
    mapping(address => uint256) public reputationScore;
    
    uint256 public constant COMMUNITY_BONUS = 10; // 10% bonus
    uint256 public constant BASE_SCORE = 100;
    
    // ============ Events ============
    
    event AddressBlacklisted(address indexed user, string reason);
    event AddressUnblacklisted(address indexed user);
    event CommunityMemberAdded(address indexed user);
    event CommunityMemberRemoved(address indexed user);
    event ReputationUpdated(address indexed user, uint256 newScore);
    
    // ============ Errors ============
    
    error AlreadyBlacklisted();
    error NotBlacklisted();
    error AlreadyCommunityMember();
    error NotCommunityMember();
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {}
    
    // ============ Admin Functions ============
    
    /**
     * @notice Blacklist an address from participating in auctions
     * @param user Address to blacklist
     * @param reason Reason for blacklisting
     */
    function blacklist(address user, string calldata reason) external onlyOwner {
        if (isBlacklisted[user]) revert AlreadyBlacklisted();
        
        isBlacklisted[user] = true;
        reputationScore[user] = 0;
        
        emit AddressBlacklisted(user, reason);
    }
    
    /**
     * @notice Remove address from blacklist
     * @param user Address to unblacklist
     */
    function unblacklist(address user) external onlyOwner {
        if (!isBlacklisted[user]) revert NotBlacklisted();
        
        isBlacklisted[user] = false;
        reputationScore[user] = BASE_SCORE;
        
        emit AddressUnblacklisted(user);
    }
    
    /**
     * @notice Add address as community member
     * @param user Address to add
     */
    function addCommunityMember(address user) external onlyOwner {
        if (isCommunityMember[user]) revert AlreadyCommunityMember();
        
        isCommunityMember[user] = true;
        reputationScore[user] = BASE_SCORE + COMMUNITY_BONUS;
        
        emit CommunityMemberAdded(user);
    }
    
    /**
     * @notice Remove community member status
     * @param user Address to remove
     */
    function removeCommunityMember(address user) external onlyOwner {
        if (!isCommunityMember[user]) revert NotCommunityMember();
        
        isCommunityMember[user] = false;
        reputationScore[user] = BASE_SCORE;
        
        emit CommunityMemberRemoved(user);
    }
    
    /**
     * @notice Batch blacklist multiple addresses
     * @param users Array of addresses to blacklist
     * @param reason Reason for blacklisting
     */
    function batchBlacklist(address[] calldata users, string calldata reason) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            if (!isBlacklisted[users[i]]) {
                isBlacklisted[users[i]] = true;
                reputationScore[users[i]] = 0;
                emit AddressBlacklisted(users[i], reason);
            }
        }
    }
    
    /**
     * @notice Batch add community members
     * @param users Array of addresses to add
     */
    function batchAddCommunityMembers(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            if (!isCommunityMember[users[i]]) {
                isCommunityMember[users[i]] = true;
                reputationScore[users[i]] = BASE_SCORE + COMMUNITY_BONUS;
                emit CommunityMemberAdded(users[i]);
            }
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Check if user can participate in auctions
     * @param user Address to check
     * @return bool True if user can participate
     */
    function canParticipate(address user) external view returns (bool) {
        return !isBlacklisted[user];
    }
    
    /**
     * @notice Get reputation score for user
     * @param user Address to check
     * @return uint256 Reputation score
     */
    function getReputationScore(address user) external view returns (uint256) {
        if (isBlacklisted[user]) return 0;
        if (reputationScore[user] == 0) return BASE_SCORE;
        return reputationScore[user];
    }
    
    /**
     * @notice Get allocation bonus for community members
     * @param user Address to check
     * @return uint256 Bonus percentage (0 if not community member)
     */
    function getCommunityBonus(address user) external view returns (uint256) {
        return isCommunityMember[user] ? COMMUNITY_BONUS : 0;
    }
}
