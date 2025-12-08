// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

import {LaunchGuardHook} from "../src/LaunchGuardHook.sol";
import {HybridFHERC20} from "../src/HybridFHERC20.sol";

/**
 * @title CreateTestPool
 * @notice Creates test tokens and initializes a Uniswap v4 pool with LaunchGuard
 * @dev Complete setup for testing LaunchGuard auction system using HybridFHERC20
 */
contract CreateTestPool is Script {
    using PoolIdLibrary for PoolKey;

    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER");
        address launchGuardHook = vm.envAddress("LAUNCHGUARD_HOOK");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("========================================");
        console2.log("LaunchGuard Pool Creation");
        console2.log("========================================\n");
        console2.log("Pool Manager:", poolManager);
        console2.log("LaunchGuard Hook:", launchGuardHook);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy test tokens using HybridFHERC20
        console2.log("\n1. Deploying test tokens (HybridFHERC20)...");

        // MyToken - The new token being launched with FHE support
        HybridFHERC20 myToken = new HybridFHERC20("MyToken", "MTK");
        console2.log("   MyToken:", address(myToken));

        // WETH - Wrapped ETH (or use existing WETH on network) with FHE support
        HybridFHERC20 weth = new HybridFHERC20("Wrapped Ether", "WETH");
        console2.log("   WETH:", address(weth));

        // Mint tokens for testing
        address deployer = vm.addr(deployerPrivateKey);
        myToken.mint(deployer, 1_000_000 ether);  // 1M tokens
        weth.mint(deployer, 100 ether);           // 100 WETH
        console2.log("   Minted tokens to deployer:", deployer);

        // 2. Sort tokens (Uniswap v4 requirement: currency0 < currency1)
        console2.log("\n2. Sorting tokens for pool key...");
        (Currency currency0, Currency currency1) = address(myToken) < address(weth)
            ? (Currency.wrap(address(myToken)), Currency.wrap(address(weth)))
            : (Currency.wrap(address(weth)), Currency.wrap(address(myToken)));

        console2.log("   Currency0:", Currency.unwrap(currency0));
        console2.log("   Currency1:", Currency.unwrap(currency1));

        // 3. Create PoolKey with LaunchGuard hook
        console2.log("\n3. Creating pool key...");
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,                              // 0.3% fee
            tickSpacing: 60,
            hooks: IHooks(launchGuardHook)
        });

        PoolId poolId = PoolIdLibrary.toId(poolKey);
        console2.log("   Pool ID:", uint256(PoolId.unwrap(poolId)));

        // 4. Initialize pool with LaunchGuard enabled
        console2.log("\n4. Initializing pool...");

        // sqrtPriceX96 for 1:1 price ratio
        // Formula: sqrt(price) * 2^96
        // For 1:1 ratio: sqrt(1) * 2^96 = 2^96
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96

        // Initialize pool (LaunchGuard is enabled via beforeInitialize hook)
        IPoolManager(poolManager).initialize(poolKey, sqrtPriceX96);
        console2.log("   Pool initialized at 1:1 price ratio");

        // 5. Approve tokens for pool manager
        console2.log("\n5. Approving tokens...");
        myToken.approve(poolManager, type(uint256).max);
        weth.approve(poolManager, type(uint256).max);
        console2.log("   Tokens approved for PoolManager");

        vm.stopBroadcast();

        // 6. Print summary
        console2.log("\n========================================");
        console2.log("Pool Creation Summary");
        console2.log("========================================");
        console2.log("MyToken:", address(myToken));
        console2.log("WETH:", address(weth));
        console2.log("Currency0:", Currency.unwrap(currency0));
        console2.log("Currency1:", Currency.unwrap(currency1));
        console2.log("Pool ID:", uint256(PoolId.unwrap(poolId)));
        console2.log("LaunchGuard Enabled: YES");

        console2.log("\n========================================");
        console2.log("Next Steps");
        console2.log("========================================");
        console2.log("1. Create auction for this pool");
        console2.log("2. Users submit encrypted bids");
        console2.log("3. Operators settle auction");
        console2.log("4. Winners trade during priority window");
        console2.log("5. Public trading opens");

        // Save pool info
        savePoolInfo(
            address(myToken),
            address(weth),
            Currency.unwrap(currency0),
            Currency.unwrap(currency1),
            poolId
        );

        console2.log("\n[SUCCESS] Pool created with LaunchGuard!");
    }

    function savePoolInfo(
        address myToken,
        address weth,
        address currency0,
        address currency1,
        PoolId poolId
    ) internal {
        console2.log("\nSave this to pool-info.json:");
        console2.log(string(abi.encodePacked(
            '{\n',
            '  "myToken": "', vm.toString(myToken), '",\n',
            '  "weth": "', vm.toString(weth), '",\n',
            '  "currency0": "', vm.toString(currency0), '",\n',
            '  "currency1": "', vm.toString(currency1), '",\n',
            '  "poolId": "', vm.toString(uint256(PoolId.unwrap(poolId))), '"\n',
            '}'
        )));
    }
}
