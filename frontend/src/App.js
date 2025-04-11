import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import './App.css';

// Import ABIs
import PoolManager_ABI from './abis/PoolManager.json';
import SwapRouter_ABI from './abis/SwapRouter.json';
import RewardHook_ABI from './abis/RewardHook.json';
import MockERC20_ABI from './abis/MockERC20.json';

function App() {
  // State variables
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState('');
  const [token0Address, setToken0Address] = useState('');
  const [token1Address, setToken1Address] = useState('');
  const [poolManagerAddress, setPoolManagerAddress] = useState('');
  const [swapRouterAddress, setSwapRouterAddress] = useState('');
  const [rewardHookAddress, setRewardHookAddress] = useState('');
  const [pointsTokenAddress, setPointsTokenAddress] = useState('');
  const [pointsBalance, setPointsBalance] = useState('');
  const [amountIn, setAmountIn] = useState('');
  const [swapResult, setSwapResult] = useState(null);

  useEffect(() => {
    const init = async () => {
      // Connect to the local Anvil node
      const provider = await new ethers.JsonRpcProvider('http://localhost:8545');
      setProvider(provider);

      // Use the first account provided by Anvil
      const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; //in a real project don't expose private keys!
      const wallet = await new ethers.Wallet(privateKey, provider);
      setSigner(wallet);
      setAccount(wallet.address);

      // Addresses of deployed contracts when you run script for the first time using anvil
      const poolManagerAddress = '0x5fbdb2315678afecb367f032d93f642f64180aa3';
      const swapRouterAddress = '0xdc64a140aa3e981100a9beca4e685f962f0cf6c9';
      const rewardHookAddress = '0xb3a4a38934711f34d4cd86ce5b573fe055b10040';
      const token0Address = '0x0165878a594ca255338adfa4d48449f69242eb8f';
      const token1Address = '0xa513e6e4b8f2a923d98304ec87f64353c4d5c853';

      setPoolManagerAddress(poolManagerAddress);
      setSwapRouterAddress(swapRouterAddress);
      setRewardHookAddress(rewardHookAddress);
      setToken0Address(token0Address);
      setToken1Address(token1Address);

      // Create contract instances
      const rewardHook = await new ethers.Contract(rewardHookAddress, RewardHook_ABI.abi, wallet);
      const pointsTokenAddress = await rewardHook.pointsToken();
      if (!pointsTokenAddress) {
        console.error("Failed to retrieve points token address");
        return;
      }
      setPointsTokenAddress(pointsTokenAddress);
      console.log("SwapRouter Address:", swapRouterAddress);
      console.log("RewardHook Address:", rewardHookAddress);
      console.log("Token0 Address:", token0Address);
      console.log("Token1 Address:", token1Address);


      const pointsToken = await new ethers.Contract(pointsTokenAddress, MockERC20_ABI.abi, wallet);
      const balance = await pointsToken.balanceOf(wallet.address);
      console.log(ethers.formatEther(balance));
      setPointsBalance(ethers.formatEther(balance));
    };

    init();
  }, []);

  // Function to perform the swap
  const performSwap = async () => {
    if (!provider || !signer) return;

    const token0 = await new ethers.Contract(token0Address, MockERC20_ABI.abi, signer);
    const token1 = await new ethers.Contract(token1Address, MockERC20_ABI.abi, signer);
    const swapRouter = await new ethers.Contract(swapRouterAddress, SwapRouter_ABI.abi, signer);

    // Approve tokens
    const approveTx = await token0.approve(swapRouterAddress, ethers.MaxUint256);
    await approveTx.wait();

    // Prepare swap parameters
    const zeroForOne = true;
    const amountSpecified = await ethers.parseEther(amountIn);
    const swapParams = {
      zeroForOne: zeroForOne,
      amountSpecified: amountSpecified,
      sqrtPriceLimitX96: zeroForOne
        ? ethers.toBigInt('4295128740')
        : ethers.toBigInt('1461446703485210103287273052203988822378723970341'),
    };

    const testSettings = {
      takeClaims: false,
      settleUsingBurn: false,
    };

    const poolKey = {
      currency0: token0Address,
      currency1: token1Address,
      fee: 3000,
      tickSpacing: 60,
      hooks: rewardHookAddress,
    };

    const hookData = await ethers.AbiCoder.defaultAbiCoder().encode(['address'], [account]);

    // Perform the swap
    try {
      const tx = await swapRouter.swap(poolKey, swapParams, testSettings, hookData);
      await tx.wait();

      // Get new balances
      const newBalance0 = await token0.balanceOf(account);
      const newBalance1 = await token1.balanceOf(account);

      const pointsToken = await new ethers.Contract(pointsTokenAddress, MockERC20_ABI.abi, signer);
      const newPointsBalance = await pointsToken.balanceOf(account);

      setPointsBalance(ethers.formatEther(newPointsBalance));
      setSwapResult({
        newBalance0: ethers.formatEther(newBalance0),
        newBalance1: ethers.formatEther(newBalance1),
      });
    } catch (error) {
      console.error('Swap failed:', error);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Uniswap v4 Swap Demo with Reward Hook</h1>
        {account && <p>Connected as: {account}</p>}
        {pointsTokenAddress && <p>Your POINTS Balance: {pointsBalance}</p>}
        <div>
          <h2>Swap Tokens</h2>
          <input
            type="text"
            placeholder="Amount of Token0 to swap"
            value={amountIn}
            onChange={(e) => setAmountIn(e.target.value)}
          />
          <button onClick={performSwap}>Swap</button>
          {swapResult && (
            <div>
              <p>New Token0 Balance: {swapResult.newBalance0}</p>
              <p>New Token1 Balance: {swapResult.newBalance1}</p>
            </div>
          )}
        </div>
      </header>
    </div>
  );
}

export default App;