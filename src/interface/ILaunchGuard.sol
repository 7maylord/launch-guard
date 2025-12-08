// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {euint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/**
 * @title ILaunchGuard
 * @notice Interface for LaunchGuard encrypted auction system
 */
interface ILaunchGuard {
    
    // ============ Structs ============
    
    struct AuctionConfig {
        uint256 auctionEndTime;
        uint256 priorityWindowDuration;
        uint256 minBidAmount;
        uint256 maxWinners;
        bool isActive;
    }
    
    struct Bid {
        address bidder;
        euint128 encryptedAmount;
        uint256 timestamp;
        bool isWinner;
        bool hasExecuted;
    }
    
    struct Winner {
        address bidder;
        uint256 amount;
        uint256 allocation;
    }
    
    // ============ Events ============
    
    event AuctionCreated(
        PoolKey indexed poolKey,
        uint256 auctionEndTime,
        uint256 priorityWindowDuration,
        uint256 minBidAmount,
        uint256 maxWinners
    );
    
    event BidSubmitted(
        PoolKey indexed poolKey,
        address indexed bidder,
        euint128 encryptedAmount,
        uint256 timestamp
    );
    
    event AuctionSettled(
        PoolKey indexed poolKey,
        uint256 totalBids,
        uint256 winnersCount
    );
    
    event WinnerExecuted(
        PoolKey indexed poolKey,
        address indexed winner,
        uint256 amount
    );
    
    event PoolOpenedToPublic(
        PoolKey indexed poolKey,
        uint256 timestamp
    );
    
    // ============ Errors ============
    
    error AuctionNotActive();
    error AuctionEnded();
    error AuctionNotEnded();
    error BidTooLow();
    error NotWinner();
    error PriorityWindowExpired();
    error PriorityWindowActive();
    error AlreadyExecuted();
    error NotAuthorized();
    error InvalidConfiguration();
    
    // ============ Functions ============
    
    function createAuction(
        PoolKey calldata poolKey,
        uint256 auctionEndTime,
        uint256 priorityWindowDuration,
        uint256 minBidAmount,
        uint256 maxWinners
    ) external;
    
    function submitBid(
        PoolKey calldata poolKey,
        euint128 encryptedAmount
    ) external;
    
    function settleAuction(
        PoolKey calldata poolKey,
        Winner[] calldata winners
    ) external;
    
    function executePrioritySwap(
        PoolKey calldata poolKey
    ) external;
    
    function isInPriorityWindow(PoolKey calldata poolKey) external view returns (bool);
    
    function getAuctionConfig(PoolKey calldata poolKey) external view returns (AuctionConfig memory);
    
    function getBid(PoolKey calldata poolKey, address bidder) external view returns (Bid memory);
    
    function isWinner(PoolKey calldata poolKey, address bidder) external view returns (bool);
}
