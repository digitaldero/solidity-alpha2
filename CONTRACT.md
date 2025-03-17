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
*   `ROUTER`: Hardcoded PulseX V2 router address.

State Variables
---------------

    
        mapping(address => bool) public isTaxExempt;
        bool private swapping;
        

*   `isTaxExempt`: Public mapping to track tax-exempt addresses (e.g., deployer, router, contract).
*   `swapping`: Private flag to prevent reentrancy during liquidity addition.

Events
------

    
        event LiquidityAdded(uint256 tokenAmount, uint256 wplsAmount);
        event TaxCollected(address indexed from, uint256 amount);
        

*   `LiquidityAdded`: Emitted when liquidity is added, logging ALPHA and WPLS amounts.
*   `TaxCollected`: Emitted when tax is collected, indexing the sender and amount.

Constructor
-----------

    
        constructor(address initialOwner) 
            ERC20("Alpha", "ALPHA") 
            Ownable(initialOwner)
        {
            taxEndTime = block.timestamp + TAX_DURATION;
            _mint(initialOwner, INITIAL_SUPPLY * 10**decimals());
    
            // Initialize Uniswap V2 Router and Pair
            uniswapV2Router = IUniswapV2Router02(ROUTER);
            uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
                .createPair(address(this), uniswapV2Router.WPLS());
    
            // Set tax exemptions
            isTaxExempt[msg.sender] = true;
            isTaxExempt[address(router)] = true;
            isTaxExempt[address(this)] = true;
        }
        

*   **Parameters**: Takes `initialOwner` as the deployer’s address.
*   **Initialization**:
    *   Sets token name ("Alpha") and symbol ("ALPHA") via `ERC20` constructor.
    *   Sets ownership to `initialOwner` via `Ownable` constructor.
    *   Calculates `taxEndTime` as deployment time + 1 hour.
    *   Mints 1M tokens (adjusted for 18 decimals) to `initialOwner`.
    *   Initializes `uniswapV2Router` with the PulseX V2 router address.
    *   Creates the ALPHA/WPLS pair via the factory, storing it in `uniswapV2Pair`.
    *   Exempts `msg.sender` (deployer), router, and contract from tax.

Transfer Logic (`_update`)
--------------------------

    
        function _update(address from, address to, uint256 amount) internal virtual override {
            if (block.timestamp > taxEndTime) {
                super._update(from, to, amount);
                return;
            }
    
            if (isTaxExempt[from] || isTaxExempt[to] || swapping) {
                super._update(from, to, amount);
                return;
            }
    
            uint256 taxAmount = (amount * TOTAL_TAX_PERCENT) / 100;
            uint256 amountAfterTax;
            unchecked { amountAfterTax = amount - taxAmount; }
    
            super._update(from, to, amountAfterTax);
    
            if (taxAmount > 0) {
                super._update(from, address(this), taxAmount);
                emit TaxCollected(from, taxAmount);
                swapping = true;
                _addLiquidity(taxAmount);
                swapping = false;
            }
        }
        

*   **Purpose**: Overrides OpenZeppelin’s `_update` to implement tax logic.
*   **Flow**:
    1.  **Tax Period Check**: If past `taxEndTime`, uses default ERC20 transfer logic.
    2.  **Exemption Check**: If `from`, `to`, or `swapping` is exempt, skips tax.
    3.  **Tax Calculation**: Applies 5% tax, calculates amount after tax (optimized with `unchecked`).
    4.  **Transfer**: Sends `amountAfterTax` to recipient, `taxAmount` to contract.
    5.  **Liquidity**: If tax is collected, adds liquidity and emits `TaxCollected`.
*   **Reentrancy**: `swapping` flag prevents reentrancy during `_addLiquidity`.

Liquidity Addition (`_addLiquidity`)
------------------------------------

    
        function _addLiquidity(uint256 tokenAmount) private {
            uint256 tokenForWpls = tokenAmount / 2;
            uint256 tokenForLp;
            unchecked { tokenForLp = tokenAmount - tokenForWpls; }
    
            _approve(address(this), address(uniswapV2Router), tokenForWpls);
    
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = uniswapV2Router.WPLS();
    
            uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenForWpls,
                0,
                path,
                address(this),
                block.timestamp
            );
    
            uint256 wplsBalance = IERC20(uniswapV2Router.WPLS()).balanceOf(address(this));
            _approve(address(this), address(uniswapV2Router), tokenForLp);
            IERC20(uniswapV2Router.WPLS()).approve(address(uniswapV2Router), wplsBalance);
    
            (uint256 amountToken,,) = uniswapV2Router.addLiquidity(
                address(this),
                uniswapV2Router.WPLS(),
                tokenForLp,
                wplsBalance,
                0,
                0,
                owner(),
                block.timestamp
            );
    
            emit LiquidityAdded(amountToken, wplsBalance);
        }
        

*   **Purpose**: Converts taxed tokens into ALPHA/WPLS liquidity.
*   **Steps**:
    1.  Splits `tokenAmount` into half for swapping (`tokenForWpls`) and half for pairing (`tokenForLp`).
    2.  Approves router to spend `tokenForWpls`.
    3.  Swaps half to WPLS using `swapExactTokensForTokensSupportingFeeOnTransferTokens`.
    4.  Approves router to spend remaining ALPHA and received WPLS.
    5.  Adds liquidity to ALPHA/WPLS pair, sending LP tokens to `owner()`.
    6.  Emits `LiquidityAdded` with amounts.
*   **Notes**: Uses `WPLS()` from the router, no slippage protection (min amounts set to 0).

Helper Function (`getRemainingTaxTime`)
---------------------------------------

    
        function getRemainingTaxTime() external view returns (uint256) {
            return block.timestamp >= taxEndTime ? 0 : taxEndTime - block.timestamp;
        }
        

*   **Purpose**: Returns seconds remaining in the tax period (0 if ended).
*   **Visibility**: External, view-only for gas efficiency.

Fallback Function (`receive`)
-----------------------------

    
        receive() external payable {}
        

*   **Purpose**: Allows the contract to receive WPLS (unwrapped PLS) during swaps.

Token Recovery (`recoverTokens`)
--------------------------------

    
        function recoverTokens(address token, uint256 amount) external onlyOwner {
            require(token != address(this), "Cannot recover native token");
            IERC20(token).transfer(msg.sender, amount);
        }
        

*   **Purpose**: Allows the owner to recover non-ALPHA tokens sent to the contract.
*   **Restriction**: Prevents recovering ALPHA tokens, onlyOwner access.
