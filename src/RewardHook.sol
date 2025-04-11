// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract RewardHook is BaseHook {
    using CurrencyLibrary for Currency;

    // The POINTS token
    MockERC20 public pointsToken;

    // Address of the target token (the one we want to incentivize swaps for)
    address public targetToken;

    // Mapping to keep track of whether the POINTS token has been minted to a user
    mapping(address => bool) public hasReceivedPoints;

    constructor(
        IPoolManager _poolManager,
        address _targetToken
    ) BaseHook(_poolManager) {
        targetToken = _targetToken;

        // Deploy the POINTS token
        pointsToken = new MockERC20("Points Token", "POINTS", 18);
    }

    // Specify which hook functions we're implementing
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true, // We're implementing afterSwap
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    event AfterSwapCalled(address user);

    // Hook function called after a swap
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        address user = abi.decode(hookData, (address));

        // Check if the swap involves the target token
        bool involvesTargetToken = (
            Currency.unwrap(key.currency0) == targetToken ||
            Currency.unwrap(key.currency1) == targetToken
        );

        uint256 totalReward = 0;

        if (involvesTargetToken) {
            if (!hasReceivedPoints[user]) {
                // Base reward for first swap
                totalReward += calculateBaseReward();
                hasReceivedPoints[user] = true;
            }

            // Ongoing reward for every swap
            totalReward += calculateRewardSecondary();

            // Mint the total reward to the user
            pointsToken.mint(user, totalReward);
        }

        emit AfterSwapCalled(user);

        // Return the function selector and a default value
        return (BaseHook.afterSwap.selector, 0);
    }

    // Function to calculate the base reward amount
    function calculateBaseReward() internal pure returns (uint256) {
        // Base reward: 10 POINTS tokens for first swap
        return 10 * 1e18; // 10 POINTS tokens with 18 decimals
    }

    // Function to calculate the ongoing reward amount
    function calculateRewardSecondary() internal pure returns (uint256) {
        // Ongoing reward for swaps
        return 1 * 1e18; // 1 POINTS token with 18 decimals
    }
}