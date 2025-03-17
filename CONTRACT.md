AlphaToken Contract Details
===========================

This document describes each component of the `AlphaToken` smart contract, an ERC20 token designed for PulseChain with a 5% tax for the first hour after deployment, used to add liquidity to the ALPHA/WPLS pair on PulseX V2. The contract is written in Solidity 0.8.26 and integrates OpenZeppelin and Uniswap V2 libraries.

SPDX License and Pragma
-----------------------

    
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.26;
        

*   **License**: MIT, allowing open use and modification.
*   **Solidity Version**: 0.8.26, the latest stable version as of March 2025, with built-in overflow checks and gas optimizations.

Imports
-------

    
    import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
        

*   `ERC20.sol`: Provides the standard ERC20 token implementation from OpenZeppelin v5.x.
*   `Ownable.sol`: Adds ownership functionality with `onlyOwner` modifier and `owner()` getter.
*   `IUniswapV2Router02.sol`: Interface for interacting with PulseX V2 (Uniswap V2 fork), modified to use `WPLS()` instead of `WETH()`.

Contract Declaration and Constants
----------------------------------

    
    contract AlphaToken is ERC20, Ownable {
        uint256 public constant TOTAL_TAX_PERCENT = 5; // Total tax (all for liquidity)
        uint256 public immutable taxEndTime; // Timestamp when tax period ends
        uint256 public constant TAX_DURATION = 1 hours; // 1 hour tax period
        uint256 private constant INITIAL_SUPPLY = 1_000_000; // 1M ALPHA tokens
        
        IUniswapV2Router02 public immutable uniswapV2Router;
        address public immutable uniswapV2Pair;
        address public constant ROUTER = 0x165C3410fC91EF562C50559f7d2289fEbed552d9; // PulseX V2 Router
        

*   **Inheritance**: Extends `ERC20` for token functionality and `Ownable` for ownership.
*   `TOTAL_TAX_PERCENT`: 5% tax rate applied to transfers during the first hour.
*   `taxEndTime`: Immutable timestamp (deployment time + 1 hour) when tax ends.
*   `TAX_DURATION`: Fixed 1-hour period (3600 seconds) using Solidity’s time units.
*   `INITIAL_SUPPLY`: 1M tokens minted at deployment, private to prevent external access.
*   `uniswapV2Router`: Immutable reference to PulseX V2 router at `0x165C3410fC91EF562C50559f7d2289fEbed552d9`.
*   `uniswapV2Pair`: Immutable address of the ALPHA/WPLS pair, created in the constructor.
