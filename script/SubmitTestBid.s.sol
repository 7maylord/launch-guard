// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {LaunchGuardHook} from "../src/LaunchGuardHook.sol";
import {InEuint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title SubmitTestBid
 * @notice Submit a test bid to the LaunchGuard auction
 * @dev On Sepolia, FHE is mocked - this demonstrates the flow
 */
contract SubmitTestBid is Script {
    function run() external {
        address launchGuardHook = vm.envAddress("LAUNCHGUARD_HOOK");
        address currency0 = vm.envAddress("CURRENCY0");
        address currency1 = vm.envAddress("CURRENCY1");
        uint256 bidderPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("========================================");
        console2.log("Submit Test Bid to LaunchGuard Auction");
        console2.log("========================================\n");
        console2.log("Hook:", launchGuardHook);
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

        // Mock encrypted bid amount (0.05 ETH)
        // In production on Fhenix, this would be encrypted with FHE
        // On Sepolia, the FHE precompiles are mocked
        uint256 bidAmount = 0.05 ether;
        console2.log("\nBid Amount:", bidAmount, "wei (0.05 ETH)");
        console2.log("Note: On Sepolia, FHE is mocked for testing");

        // Create InEuint128 struct for the encrypted amount
        // This is a simplified version - real FHE would generate proper encrypted data
        InEuint128 memory encryptedAmount = InEuint128({
            ctHash: uint256(bidAmount), // Mock: use bid amount as hash
            securityZone: 0,
            utype: 7, // euint128
            signature: ""
        });

        vm.startBroadcast(bidderPrivateKey);

        console2.log("\nSubmitting bid...");

        // Get the EncryptedAuction contract from the hook
        address auctionContract = address(LaunchGuardHook(launchGuardHook).auction());
        console2.log("Auction Contract:", auctionContract);

        // Submit bid through the auction contract
        // Note: We need to call the auction contract directly
        (bool success, bytes memory data) = auctionContract.call(
            abi.encodeWithSignature(
                "submitBid((address,address,uint24,int24,address),(bytes))",
                poolKey,
                encryptedAmount
            )
        );

        if (success) {
            console2.log("[SUCCESS] Bid submitted!");
        } else {
            console2.log("[FAILED] Bid submission failed");
            if (data.length > 0) {
                console2.log("Error data:", string(data));
            }
        }

        vm.stopBroadcast();

        console2.log("\n========================================");
        console2.log("Bid Summary");
        console2.log("========================================");
        console2.log("Bidder:", vm.addr(bidderPrivateKey));
        console2.log("Amount:", bidAmount, "wei");
        console2.log("Status:", success ? "Submitted" : "Failed");

        console2.log("\n========================================");
        console2.log("Next Steps");
        console2.log("========================================");
        console2.log("1. Submit more bids from different addresses");
        console2.log("2. Wait for auction to end");
        console2.log("3. Operators settle auction");
        console2.log("4. Winners can trade during priority window");
    }
}
