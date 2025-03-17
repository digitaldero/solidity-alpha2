# AlphaToken Smart Contract

`AlphaToken` is an ERC20 token designed for deployment on PulseChain, featuring a 5% tax on transfers for the first hour after deployment. The tax is used to add liquidity to the ALPHA/WPLS pair on PulseX V2, a Uniswap V2 fork. After the tax period ends, it functions as a standard ERC20 token. This contract is built with Solidity 0.8.26 and integrates OpenZeppelin and Uniswap V2 libraries.

## Overview

- **Token Name**: Alpha
- **Symbol**: ALPHA
- **Initial Supply**: 1,000,000 tokens (1M ALPHA)
- **Tax**: 5% on transfers for the first hour, applied to add liquidity
- **Tax Exemptions**: `msg.sender`, PulseX V2 router, and the contract itself
- **Tax Duration**: 1 hour after deployment
- **Liquidity**: Taxed tokens are swapped and paired with WPLS on PulseX V2
- **PulseChain**: Compatible with PulseX V2 router at `0x165C3410fC91EF562C50559f7d2289fEbed552d9`

## Prerequisites

- **Network**: PulseChain (Chain ID: 369)
- **PulseX V2 Router**: `0x165C3410fC91EF562C50559f7d2289fEbed552d9`
- **Dependencies**:
  - `@openzeppelin/contracts` (v5.x)
  - `@uniswap/v2-periphery` (Uniswap V2 interfaces, modified for PulseChain with `WPLS()` instead of `WETH()`)
- **Tools**: Hardhat, Truffle, or Remix for compilation and deployment
- **Initial Liquidity**: ALPHA/WPLS pair must be manually created on PulseX V2 post-deployment

## Installation

1. Install dependencies:
   ```bash
   npm install @openzeppelin/contracts @uniswap/v2-periphery
