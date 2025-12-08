// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {LaunchGuardHook} from "../src/LaunchGuardHook.sol";

/**
 * @title CreateAuction
 * @notice Creates an auction for a Uniswap v4 pool with LaunchGuard
 * @dev Run after CreateTestPool to set up the complete auction system
 */
contract CreateAuction is Script {
    function run() external {
        address launchGuardHook = vm.envAddress("LAUNCHGUARD_HOOK");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get pool info from previous script
        address currency0 = vm.envAddress("CURRENCY0");
        address currency1 = vm.envAddress("CURRENCY1");

        console2.log("========================================");
        console2.log("LaunchGuard Auction Creation");
        console2.log("========================================\n");
        console2.log("LaunchGuard Hook:", launchGuardHook);
        console2.log("Currency0:", currency0);
        console2.log("Currency1:", currency1);

        // Create PoolKey
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(launchGuardHook)
        });

        // Auction parameters
        uint256 auctionEndTime = block.timestamp + 1 hours;     // Auction ends in 1 hour
        uint256 priorityWindow = 5 minutes;                      // Winners get 5 min priority
        uint256 minBid = 0.01 ether;                             // Minimum bid: 0.01 ETH
        uint256 maxWinners = 100;                                // Top 100 bidders win

        console2.log("\n1. Auction Configuration:");
        console2.log("   Auction End:", auctionEndTime);
        console2.log("   Priority Window:", priorityWindow, "seconds");
        console2.log("   Min Bid:", minBid);
        console2.log("   Max Winners:", maxWinners);

        vm.startBroadcast(deployerPrivateKey);

        // Create auction
        console2.log("\n2. Creating auction...");
        LaunchGuardHook(launchGuardHook).createAuction(
            poolKey,
            auctionEndTime,
            priorityWindow,
            minBid,
            maxWinners
        );

        vm.stopBroadcast();

        console2.log("   [SUCCESS] Auction created!\n");

        // Print summary
        console2.log("========================================");
        console2.log("Auction Summary");
        console2.log("========================================");
        console2.log("Pool: Currency0 <-> Currency1");
        console2.log("  Currency0:", currency0);
        console2.log("  Currency1:", currency1);
        console2.log("");
        console2.log("Auction Period: NOW -> +1 hour");
        console2.log("Priority Trading: After settlement -> +5 minutes");
        console2.log("Min Bid: 0.01 ETH");
        console2.log("Winners: Top 100 bidders");

        console2.log("\n========================================");
        console2.log("Next Steps - Submit Encrypted Bids");
        console2.log("========================================");
        console2.log("");
        console2.log("Users can now submit encrypted bids:");
        console2.log("");
        console2.log("cast send", launchGuardHook, "\\");
        console2.log('  "submitBid((address,address,uint24,int24,address),bytes,bytes)" \\');
        console2.log("  \"($CURRENCY0,$CURRENCY1,3000,60,", launchGuardHook, ")\" \\");
        console2.log("  $ENCRYPTED_AMOUNT \\");
        console2.log("  $ENCRYPTED_PROOF \\");
        console2.log("  --private-key $BIDDER_KEY \\");
        console2.log("  --rpc-url $RPC_URL");
        console2.log("");
        console2.log("After auction ends:");
        console2.log("1. Operators settle auction (decrypt & rank bids)");
        console2.log("2. Winners can trade during priority window");
        console2.log("3. Public trading opens");

        console2.log("\n========================================");
        console2.log("Testing - Simulate Bids (Frontend)");
        console2.log("========================================");
        console2.log("");
        console2.log("For encrypted bid testing, use the frontend:");
        console2.log("1. cd frontend");
        console2.log("2. Update lib/config.ts with deployed addresses");
        console2.log("3. npm run dev");
        console2.log("4. Connect wallet and submit test bids");
        console2.log("");
        console2.log("The frontend handles FHE encryption automatically!");

        // Save auction config
        saveAuctionConfig(
            launchGuardHook,
            currency0,
            currency1,
            auctionEndTime,
            priorityWindow,
            minBid,
            maxWinners
        );
    }

    function saveAuctionConfig(
        address hook,
        address currency0,
        address currency1,
        uint256 endTime,
        uint256 window,
        uint256 minBid,
        uint256 maxWinners
    ) internal view {
        console2.log("\nSave this to auction-config.json:");
        console2.log(string(abi.encodePacked(
            '{\\n',
            '  "hook": "', vm.toString(hook), '",\\n',
            '  "currency0": "', vm.toString(currency0), '",\\n',
            '  "currency1": "', vm.toString(currency1), '",\\n',
            '  "auctionEndTime": ', vm.toString(endTime), ',\\n',
            '  "priorityWindow": ', vm.toString(window), ',\\n',
            '  "minBid": "', vm.toString(minBid), '",\\n',
            '  "maxWinners": ', vm.toString(maxWinners), '\\n',
            '}'
        )));
    }
}
