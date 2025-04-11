// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {RewardHook} from "../src/RewardHook.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";

contract RewardHookTest is Test, Fixtures {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using EasyPosm for IPositionManager;
    using StateLibrary for IPoolManager;

    RewardHook hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        // Creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        address flag = address(
            uint160(
                Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );

        // Assign currency0 as the target token
        address targetToken = Currency.unwrap(currency0);

        // Deploy the RewardHook with currency0 as the target token
        bytes memory constructorArgs = abi.encode(manager, targetToken);
        deployCodeTo("RewardHook.sol:RewardHook", constructorArgs, flag);
        hook = RewardHook(flag);

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
    }

   function testRewardHookAfterSwap() public {
    // Check initial balance of POINTS token
    uint256 initialPointsBalance = hook.pointsToken().balanceOf(address(this));
    assertEq(initialPointsBalance, 0);

    // Expect the AfterSwapCalled event to be emitted
    vm.expectEmit(true, false, false, true);
    emit RewardHook.AfterSwapCalled(address(this));

    // Perform a test swap
    bool zeroForOne = true;
    bytes memory hookData = abi.encode(address(this));
    int256 amountSpecified = -1e18; // negative number indicates exact input swap!
    BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, hookData);

    // Verify swap results
    assertEq(int256(swapDelta.amount0()), amountSpecified);

    // Check if POINTS tokens were minted
    uint256 finalPointsBalance = hook.pointsToken().balanceOf(address(this));
    assertEq(finalPointsBalance, 11 * 1e18); // 10 POINTS for first swap + 1 POINTS for ongoing reward
}
}