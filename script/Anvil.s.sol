// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "v4-core/src/test/PoolDonateTest.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Counter} from "../src/Counter.sol";
import {RewardHook} from "../src/RewardHook.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {EasyPosm} from "../test/utils/EasyPosm.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {DeployPermit2} from "../test/utils/forks/DeployPermit2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPositionDescriptor} from "v4-periphery/src/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "v4-periphery/src/interfaces/external/IWETH9.sol";

/// @notice Forge script for deploying v4 & hooks to **anvil**
contract CounterScript is Script, DeployPermit2 {
    using EasyPosm for IPositionManager;

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant TOKEN = address(0x0165878A594ca255338adfa4d48449f69242Eb8F); //address of token0 if you run the script for the first time
    IPoolManager manager;
    IPositionManager posm;
    PoolModifyLiquidityTest lpRouter;
    PoolSwapTest swapRouter;

    MockERC20 token0; 
    MockERC20 token1;


    function setUp() public {}

    function run() public {
  
        vm.broadcast();
        manager = deployPoolManager();

        // hook contracts must have specific flags encoded in the address
        // Define the permissions for the hook
        uint160 permissions = uint160(
            Hooks.AFTER_SWAP_FLAG // We're only implementing afterSwap
        );

        // Deploy the tokens
        vm.startBroadcast();
        (token0, token1) = deployTokens();
        vm.stopBroadcast();
          
        // Calculate the salt and expected address for the RewardHook
        (address expectedHookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            permissions,
            type(RewardHook).creationCode,
            abi.encode(address(manager), token0) // Constructor arguments
        );

        // -----------------------------
        // Deploy the hook using CREATE2
        // -----------------------------
        vm.broadcast();
        RewardHook rewardHook = new RewardHook{salt: salt}(manager, address(token0));
        require(address(rewardHook) == expectedHookAddress, "RewardHookScript: Hook address mismatch");

        // Additional helpers for interacting with the pool
        vm.startBroadcast();
        posm = deployPosm(manager);
        (lpRouter, swapRouter, ) = deployRouters(manager);
        vm.stopBroadcast();

        // Test the lifecycle (create pool, add liquidity, swap)
        vm.startBroadcast();
        testLifecycle(address(rewardHook));
        vm.stopBroadcast();
    }

    // -----------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------

    function deployPoolManager() internal returns (IPoolManager) {
        return IPoolManager(address(new PoolManager(address(0))));
    }

    function deployRouters(IPoolManager _manager)
        internal
        returns (PoolModifyLiquidityTest _lpRouter, PoolSwapTest _swapRouter, PoolDonateTest _donateRouter)
    {
        _lpRouter = new PoolModifyLiquidityTest(_manager);
        _swapRouter = new PoolSwapTest(_manager);
        _donateRouter = new PoolDonateTest(_manager);
    }

    function deployPosm(IPoolManager poolManager) public returns (IPositionManager) {
        anvilPermit2();
        return IPositionManager(
            new PositionManager(poolManager, permit2, 300_000, IPositionDescriptor(address(0)), IWETH9(address(0)))
        );
    }

    function approvePosmCurrency(IPositionManager _posm, Currency currency) internal {
        // Because POSM uses permit2, we must execute 2 permits/approvals.
        // 1. First, the caller must approve permit2 on the token.
        IERC20(Currency.unwrap(currency)).approve(address(permit2), type(uint256).max);

        // 2. Then, the caller must approve POSM as a spender of permit2
        permit2.approve(Currency.unwrap(currency), address(_posm), type(uint160).max, type(uint48).max);
    }

    function deployTokens() internal returns (MockERC20 _token0, MockERC20 _token1) {
        MockERC20 tokenA = new MockERC20("MockA", "A", 18);
        MockERC20 tokenB = new MockERC20("MockB", "B", 18);
        if (uint160(address(tokenA)) < uint160(address(tokenB))) {
            _token0 = tokenA;
            _token1 = tokenB;
        } else {
            _token0 = tokenB;
            _token1 = tokenA;
        }

    }

    function testLifecycle(address hook) internal {
        token0.mint(msg.sender, 100_000 ether);
        token1.mint(msg.sender, 100_000 ether);

        // Initialize the pool
        int24 tickSpacing = 60;
        PoolKey memory poolKey = PoolKey(
            Currency.wrap(address(token0)),
            Currency.wrap(address(token1)),
            3000,
            tickSpacing,
            IHooks(hook)
        );
        manager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Approve the tokens to the routers
        token0.approve(address(lpRouter), type(uint256).max);
        token1.approve(address(lpRouter), type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        approvePosmCurrency(posm, Currency.wrap(address(token0)));
        approvePosmCurrency(posm, Currency.wrap(address(token1)));

        // Add full range liquidity to the pool
        int24 tickLower = TickMath.minUsableTick(tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(tickSpacing);
        _exampleAddLiquidity(poolKey, tickLower, tickUpper);

        // Swap some tokens
        _exampleSwap(poolKey);
    }

    function _exampleAddLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper) internal {
        // Provisions full-range liquidity twice. Two different periphery contracts used for example purposes.
        IPoolManager.ModifyLiquidityParams memory liqParams = IPoolManager.ModifyLiquidityParams(
            tickLower,
            tickUpper,
            100 ether,
            0
        );
        lpRouter.modifyLiquidity(poolKey, liqParams, "");
        posm.mint(
            poolKey,
            tickLower,
            tickUpper,
            100e18,
            10_000e18,
            10_000e18,
            msg.sender,
            block.timestamp + 300,
            ""
        );
    }

    function _exampleSwap(PoolKey memory poolKey) internal {
        bool zeroForOne = true;
        int256 amountSpecified = 1 ether;

        // Encode hookData with the user address
        bytes memory hookData = abi.encode(msg.sender);
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Pass hookData to swap
        swapRouter.swap(poolKey, params, testSettings, hookData);
    }
}
