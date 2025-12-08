// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

import {LaunchGuardHook} from "../src/LaunchGuardHook.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";

/**
 * @title DeployLaunchGuardProper
 * @notice Proper deployment using HookMiner for salt mining
 * @dev Mines salt to deploy hook at address with correct flags
 */
contract DeployLaunchGuardProper is Script {

    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("========================================");
        console2.log("LaunchGuard Proper Deployment");
        console2.log("========================================\n");
        console2.log("Pool Manager:", poolManager);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ReputationRegistry
        console2.log("\n1. Deploying ReputationRegistry...");
        ReputationRegistry reputationRegistry = new ReputationRegistry();
        console2.log("   ReputationRegistry:", address(reputationRegistry));

        // 2. Define hook flags matching getHookPermissions()
        console2.log("\n2. Mining salt for hook address...");
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG
        );
        console2.log("   Required flags:", flags);

        // 3. Mine salt for hook address
        bytes memory constructorArgs = abi.encode(poolManager, address(reputationRegistry));

        console2.log("   Mining (this may take a minute)...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(LaunchGuardHook).creationCode,
            constructorArgs
        );

        console2.log("   Found valid address:", hookAddress);
        console2.log("   Salt:", uint256(salt));

        // 4. Deploy LaunchGuardHook with mined salt
        console2.log("\n3. Deploying LaunchGuardHook...");
        LaunchGuardHook hook = new LaunchGuardHook{salt: salt}(
            IPoolManager(poolManager),
            address(reputationRegistry)
        );
        console2.log("   LaunchGuardHook:", address(hook));

        // 5. Verify address matches
        require(address(hook) == hookAddress, "Hook address mismatch!");

        // 6. Get auction contract address
        address auctionContract = hook.getAuctionContract();
        console2.log("   EncryptedAuction:", auctionContract);

        vm.stopBroadcast();

        // 7. Print summary
        console2.log("\n========================================");
        console2.log("Deployment Summary");
        console2.log("========================================");
        console2.log("ReputationRegistry:", address(reputationRegistry));
        console2.log("LaunchGuardHook:", address(hook));
        console2.log("EncryptedAuction:", auctionContract);
        console2.log("Owner:", reputationRegistry.owner());

        console2.log("\n========================================");
        console2.log("Next Steps");
        console2.log("========================================");
        console2.log("1. Authorize operators in EncryptedAuction");
        console2.log("2. Create pool with LaunchGuardHook");
        console2.log("3. Create auction for the pool");
        console2.log("4. Start AVS operators");

        console2.log("\n[SUCCESS] Deployment complete!");
        console2.log("\nSave these addresses to deployments.json manually:");
        console2.log(string(abi.encodePacked(
            '{\n',
            '  "reputationRegistry": "', vm.toString(address(reputationRegistry)), '",\n',
            '  "launchGuardHook": "', vm.toString(address(hook)), '",\n',
            '  "encryptedAuction": "', vm.toString(auctionContract), '"\n',
            '}'
        )));
    }
}
