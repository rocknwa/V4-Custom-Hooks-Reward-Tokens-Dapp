# RewardHook and Uniswap v4 Swap Demo

## Overview

This project integrates a custom **Reward Hook** with Uniswap v4, allowing users to earn rewards (in the form of POINTS tokens) when performing swaps involving a specified target token. The project includes both a Solidity smart contract (`RewardHook.sol`) and a React frontend to interact with the deployed contracts.

## Features

- **Reward Hook**: A Uniswap v4 hook that mints POINTS tokens to incentivize swaps involving a specific target token.
- **POINTS Token**: ERC-20 token representing rewards, deployed as part of the `RewardHook` contract.
- **React Frontend**: A user-friendly interface for interacting with the Uniswap v4 pool and performing token swaps.
- **Blockchain Integration**: Uses Ethereum and Ethers.js for seamless smart contract interactions.

---

## Smart Contract Details

### RewardHook

The `RewardHook` contract is a custom implementation of Uniswap v4's hook system, providing the following functionality:

- **Reward System**:
  - **Base Reward**: Users receive 10 POINTS tokens for their first swap involving the target token.
  - **Ongoing Reward**: Users earn 1 POINTS token for every subsequent swap involving the target token.
- **POINTS Token**: Deployed as part of the `RewardHook` contract using the `MockERC20` implementation.
- **Target Token Incentive**: Rewards are issued only for swaps involving the specified target token.

### Hook Permissions

The `RewardHook` implements the `afterSwap` hook, enabling it to execute custom logic after a swap is performed.

---

## Frontend Details

### Features

The React frontend provides the following functionality:

- **Wallet Connection**: Automatically connects to the first account on the local Ethereum node (e.g., Anvil).
- **Swap Tokens**: Allows users to perform swaps between two tokens (`Token0` and `Token1`) using Uniswap v4's `SwapRouter`.
- **POINTS Balance**: Displays the user's current POINTS token balance.
- **Transaction Details**: Shows the new token balances after a successful swap.

### Technologies Used

- **React**: For the user interface.
- **Foundry** For smart contract 
- **Ethers.js**: For interacting with smart contracts and the Ethereum blockchain.
- **CSS**: For styling the application.

---

## How It Works

### Smart Contract

1. **Deployment**:
   - The `RewardHook` contract requires the following during deployment:
     - Uniswap v4 `PoolManager` address.
     - Address of the target token to incentivize.
   - The `RewardHook` uses `CREATE2` to ensure a deterministic contract address. This address is calculated using specific flags and constructor arguments.

2. **Reward Logic**:
   - The `afterSwap` function checks if the swap involves the target token.
   - Rewards are calculated, and POINTS tokens are minted directly to the user's account.

3. **POINTS Token**:
   - Deployed as an ERC-20 token with 18 decimals.
   - Used exclusively as rewards for incentivizing swaps.

4. **Liquidity Provision**:
   - The deployment script initializes a Uniswap v4 pool and adds full-range liquidity using helper contracts.

---

### React Frontend

1. **Setup**:
   - Connects to a local Ethereum node (e.g., Anvil) using a hardcoded private key (for demonstration purposes only—**do not expose private keys in production**).

2. **Performing a Swap**:
   - Users input the amount of `Token0` to swap for `Token1`.
   - The `SwapRouter` contract is used to execute the swap, and the `RewardHook` logic is triggered.

3. **Displaying Results**:
   - The frontend fetches the updated token balances and POINTS balance after the swap.

---

## Getting Started

### Prerequisites

- **Node.js** (v18 or later)
- **WSL2** if you are using windows
- **Check Forge Installation** Ensure that you have correctly installed Foundry (Forge) Stable. You can update Foundry by running:
  ```bash
  foundryup
   ```

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/rocknwa/V4-Custom-Hooks-Reward-Tokens-Dapp.git
   cd V4-Custom-Hooks-Reward-Tokens-D
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Run tests to ensure everything is set up correctly:
   ```bash
   forge test
   ```
4. or run this command to test only the `RewardHook` contract
   ```bash
   forge test --match-path test/RewardHook.t.sol --match-contract RewardHookTest
   ```

5. Deploy contracts and configure the frontend with their addresses, you can check the `run-latest.json` in the `broadcast` folder.

---

## Deployment

### Smart Contracts

1. Start the local Ethereum node (e.g., Anvil):
   ```bash
   anvil
   ```

2. Deploy the smart contracts using the provided deployment script:
   ```bash
   forge script script/Anvil.s.sol \

    --rpc-url http://localhost:8545 \

    --private-key <test_wallet_private_key> \
    
    --broadcast 
    ```

  Or create a .env file in the root directory and store these:
  ```
 PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
 RPC_URL=http://localhost:8545
  ```
Note: The private key is from anvil, don't expose your private key for any reason!
 Run this command:
```source .env
```
Then deploy with this command:
```
forge script script/Anvil.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

3. The deployment script performs the following:
   - Deploys the `PoolManager` and `RewardHook` contracts using `CREATE2` for deterministic addresses.
   - Deploys helper contracts for managing liquidity and swaps.
   - Initializes a Uniswap v4 pool and adds full-range liquidity.
   - Performs an example swap to test the lifecycle of the `RewardHook`.

4. Update the contract addresses in the React frontend (`App.js`).

### Frontend

1. Navigate to the frontend directory:
```bash
cd frontend
```
2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the React development server:
   ```bash
   npm start
   ```

4. Open the application in your browser:
   ```
   http://localhost:3000
   ```

---

## Usage

1. **Connect to Wallet**: Connect to the default account on the local Ethereum node.
2. **Perform Swap**: Enter the amount of `Token0` to swap for `Token1` and click "Swap".
3. **View Rewards**: Check your updated POINTS token balance.


---

## Security Considerations

- **Private Keys**: Do not hardcode private keys in production. Use a secure wallet or environment variable.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **Uniswap v4**: For providing a robust decentralized trading protocol.
- **Foundry**: For seamless contract deployment and testing.
- **Ethers.js**: For blockchain integration.

---

## Contact

For support, please open an issue or reach:
- **Therock Ani**  
- Twitter: [@ani_therock](https://twitter.com/ani_therock)
- Telegram: [Tech_Scorpion](https://t.me/Tech_Scorpion)
- GitHub: [rocknwa](https://github.com/rocknwa)  
- Email: anitherock44@gmail.com


