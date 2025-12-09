// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

import {LaunchGuardHook} from "../src/LaunchGuardHook.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {EncryptedAuction} from "../src/EncryptedAuction.sol";
import {LaunchGuardServiceManager} from "../src/avs/LaunchGuardServiceManager.sol";

/**
 * @title DeployLaunchGuardAVS
 * @notice Complete deployment with EigenLayer AVS integration
 * @dev Deploys all contracts including ServiceManager for AVS
 */
contract DeployLaunchGuardAVS is Script {

    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("========================================");
        console2.log("LaunchGuard AVS Deployment");
        console2.log("========================================\n");
        console2.log("Pool Manager:", poolManager);
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy ReputationRegistry
        console2.log("\n[1/5] Deploying ReputationRegistry...");
        ReputationRegistry reputationRegistry = new ReputationRegistry();
        console2.log("      Address:", address(reputationRegistry));

        // Step 2: Deploy LaunchGuardServiceManager (AVS)
        console2.log("\n[2/5] Deploying LaunchGuardServiceManager (AVS)...");
        LaunchGuardServiceManager serviceManager = new LaunchGuardServiceManager(deployer);
        console2.log("      Address:", address(serviceManager));
        console2.log("      Owner:", deployer);
        console2.log("      Min Stake:", serviceManager.MINIMUM_STAKE() / 1e18, "ETH");
        console2.log("      Quorum:", uint256(serviceManager.DEFAULT_QUORUM_THRESHOLD()), "%");

        // Step 3: Mine salt for LaunchGuardHook address
        console2.log("\n[3/5] Mining salt for LaunchGuardHook address...");
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG
        );
        console2.log("      Required flags:", flags);

        bytes memory constructorArgs = abi.encode(poolManager, address(reputationRegistry));

        console2.log("      Mining... (this may take 1-2 minutes)");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(LaunchGuardHook).creationCode,
            constructorArgs
        );

        console2.log("      Found valid address:", hookAddress);
        console2.log("      Salt:", uint256(salt));

        // Step 4: Deploy LaunchGuardHook (which creates EncryptedAuction)
        console2.log("\n[4/5] Deploying LaunchGuardHook...");
        LaunchGuardHook hook = new LaunchGuardHook{salt: salt}(
            IPoolManager(poolManager),
            address(reputationRegistry)
        );
        console2.log("      LaunchGuardHook:", address(hook));

        require(address(hook) == hookAddress, "Hook address mismatch!");

        // Get the auction contract created by the hook
        address auctionContract = address(hook.auction());
        console2.log("      EncryptedAuction:", auctionContract);

        // Step 5: Link EncryptedAuction <-> ServiceManager
        console2.log("\n[5/5] Linking EncryptedAuction <-> ServiceManager...");
        hook.setServiceManager(address(serviceManager));
        console2.log("      Auction -> ServiceManager: linked");

        serviceManager.setAuctionContract(auctionContract);
        console2.log("      ServiceManager -> Auction: linked");

        vm.stopBroadcast();

        // 8. Print summary
        console2.log("\n========================================");
        console2.log("Deployment Summary");
        console2.log("========================================");
        console2.log("ReputationRegistry:", address(reputationRegistry));
        console2.log("ServiceManager (AVS):", address(serviceManager));
        console2.log("LaunchGuardHook:", address(hook));
        console2.log("EncryptedAuction:", auctionContract);
        console2.log("Owner:", deployer);

        console2.log("\n========================================");
        console2.log("Configuration for Operators");
        console2.log("========================================");
        console2.log("SERVICE_MANAGER_ADDRESS=", address(serviceManager));
        console2.log("AUCTION_ADDRESS=", auctionContract);
        console2.log("REPUTATION_ADDRESS=", address(reputationRegistry));
        console2.log("STAKE_AMOUNT=2  # ETH");

        console2.log("\n========================================");
        console2.log("Next Steps");
        console2.log("========================================");
        console2.log("1. Register operators with ServiceManager (stake >= 1 ETH)");
        console2.log("2. Create pool with LaunchGuardHook");
        console2.log("3. Create auction for the pool");
        console2.log("4. Start AVS operators with .env configuration above");
        console2.log("5. After auction ends, call createSettlementTask()");

        console2.log("\n[SUCCESS] AVS Deployment complete!");

        // Print JSON for easy config update
        console2.log("\nUpdate frontend/lib/config.ts with:");
        console2.log(string(abi.encodePacked(
            '{\n',
            '  "reputationRegistry": "', vm.toString(address(reputationRegistry)), '",\n',
            '  "serviceManager": "', vm.toString(address(serviceManager)), '",\n',
            '  "launchGuardHook": "', vm.toString(address(hook)), '",\n',
            '  "encryptedAuction": "', vm.toString(auctionContract), '"\n',
            '}'
        )));
    }
}
