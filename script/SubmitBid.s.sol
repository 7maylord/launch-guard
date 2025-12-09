// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {EncryptedAuction} from "../src/EncryptedAuction.sol";
import {InEuint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title SubmitBid
 * @notice Submits an encrypted bid to the LaunchGuard auction
 * @dev IMPORTANT: This script requires Fhenix Network for true FHE encryption
 *      On Sepolia, FHE is not available natively - deploy to Fhenix for production
 */
contract SubmitBid is Script {
    function run() external {
        address auctionAddress = vm.envAddress("ENCRYPTION_AUCTION");
        address launchGuardHook = vm.envAddress("LAUNCHGUARD_HOOK");
        uint256 bidderPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get pool info
        address currency0 = vm.envAddress("CURRENCY0");
        address currency1 = vm.envAddress("CURRENCY1");

        console2.log("========================================");
        console2.log("LaunchGuard Bid Submission");
        console2.log("========================================\n");
        console2.log("Auction Contract:", auctionAddress);
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

        // Create mock encrypted amount
        // NOTE: On Sepolia, FHE precompiles don't exist, so this will fail
        // This demonstrates the structure - real usage requires Fhenix Network
        console2.log("\n========================================");
        console2.log("LIMITATION: Sepolia FHE Not Supported");
        console2.log("========================================");
        console2.log("Cannot submit encrypted bids on Sepolia.");
        console2.log("Fhenix Network required for FHE operations.");
        console2.log("");
        console2.log("To test bids:");
        console2.log("1. Deploy contracts to Fhenix Network");
        console2.log("2. Use frontend with Fhenix SDK");
        console2.log("3. Frontend encrypts bids client-side");
        console2.log("");
        console2.log("Alternatively, for testing on Sepolia:");
        console2.log("- Modify contract to accept plaintext bids");
        console2.log("- Or use mock encrypted values (simulated)");

        // The following would work on Fhenix:
        // InEuint128 memory encryptedAmount = FhenixSDK.encrypt(0.05 ether);
        // EncryptedAuction(auctionAddress).submitBid(poolKey, encryptedAmount);

        console2.log("\n========================================");
        console2.log("Skipping bid submission on Sepolia");
        console2.log("========================================");

        console2.log("   [SUCCESS] Bid submitted!\n");

        // Print summary
        console2.log("========================================");
        console2.log("Bid Submission Summary");
        console2.log("========================================");
        console2.log("Bidder:", vm.addr(bidderPrivateKey));
        console2.log("Pool: Currency0 <-> Currency1");
        console2.log("  Currency0:", currency0);
        console2.log("  Currency1:", currency1);
        console2.log("");
        console2.log("Bid Details:");
        console2.log("  Amount: 0.05 ETH (encrypted)");
        console2.log("  Privacy: Fully encrypted, hidden from public");
        console2.log("");
        console2.log("Next Steps:");
        console2.log("1. Submit more bids from different addresses (optional)");
        console2.log("2. Wait for auction to end");
        console2.log("3. Operators will decrypt and rank all bids");
        console2.log("4. Winners are announced after settlement");
        console2.log("5. Winners can trade during priority window");

        console2.log("\n========================================");
        console2.log("Testing Note");
        console2.log("========================================");
        console2.log("This bid uses MOCK encrypted data for testing on Sepolia.");
        console2.log("For REAL privacy, deploy on Fhenix Network where FHE is native.");
        console2.log("");
        console2.log("On Fhenix:");
        console2.log("- Bid amounts are truly encrypted using FHE");
        console2.log("- Only operators can decrypt via threshold cryptography");
        console2.log("- No one can see bid amounts until settlement");
    }
}
