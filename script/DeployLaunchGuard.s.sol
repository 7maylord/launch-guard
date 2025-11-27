// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {LaunchGuardHook} from "../src/LaunchGuardHook.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {EncryptedAuction} from "../src/EncryptedAuction.sol";

/**
 * @title DeployLaunchGuard
 * @notice Deployment script for LaunchGuard system
 * @dev Deploys ReputationRegistry and LaunchGuardHook
 */
contract DeployLaunchGuard is Script {
    
    function run() external {
        // Get deployment parameters from environment
        address poolManager = vm.envAddress("POOL_MANAGER");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("Deploying LaunchGuard...");
        console2.log("Pool Manager:", poolManager);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy ReputationRegistry
        console2.log("\n1. Deploying ReputationRegistry...");
        ReputationRegistry reputationRegistry = new ReputationRegistry();
        console2.log("ReputationRegistry deployed at:", address(reputationRegistry));
        
        // 2. Calculate hook address with correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG
        );
        
        console2.log("\n2. Calculating hook address...");
        console2.log("Required flags:", flags);
        
        // 3. Deploy LaunchGuardHook to calculated address
        console2.log("\n3. Deploying LaunchGuardHook...");
        LaunchGuardHook hook = new LaunchGuardHook{salt: bytes32(0)}(
            IPoolManager(poolManager),
            address(reputationRegistry)
        );
        console2.log("LaunchGuardHook deployed at:", address(hook));
        
        // 4. Get auction contract address
        address auctionContract = hook.getAuctionContract();
        console2.log("EncryptedAuction deployed at:", auctionContract);
        
        // 5. Verify deployment
        console2.log("\n4. Verifying deployment...");
        require(address(hook) != address(0), "Hook deployment failed");
        require(auctionContract != address(0), "Auction deployment failed");
        require(address(reputationRegistry) != address(0), "Reputation deployment failed");
        
        console2.log("\n[SUCCESS] Deployment successful!");
        console2.log("\n=== Contract Addresses ===");
        console2.log("ReputationRegistry:", address(reputationRegistry));
        console2.log("LaunchGuardHook:", address(hook));
        console2.log("EncryptedAuction:", auctionContract);
        
        console2.log("\n=== Next Steps ===");
        console2.log("1. Update operator .env with contract addresses");
        console2.log("2. Authorize operators in EncryptedAuction");
        console2.log("3. Create pool with LaunchGuard enabled");
        console2.log("4. Create auction for the pool");
        
        vm.stopBroadcast();
        
        // Save deployment info
        saveDeploymentInfo(
            address(reputationRegistry),
            address(hook),
            auctionContract
        );
    }
    
    function saveDeploymentInfo(
        address reputationRegistry,
        address launchGuardHook,
        address encryptedAuction
    ) internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "reputationRegistry": "', vm.toString(reputationRegistry), '",\n',
            '  "launchGuardHook": "', vm.toString(launchGuardHook), '",\n',
            '  "encryptedAuction": "', vm.toString(encryptedAuction), '"\n',
            '}'
        ));
        
        vm.writeFile("deployments.json", json);
        console2.log("\nDeployment info saved to deployments.json");
    }
}
