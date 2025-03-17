// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// This contract requires the ALPHA/WPLS liquidity pair to be manually created on PulseX V2 before taxed transfers can occur.
// Note: The Uniswap V2 interface (IUniswapV2Router02.sol) has been modified as follows:
// - Renamed WETH() to WPLS() to align with PulseChain’s native token
// - Added SPDX license identifier to resolve compiler warnings

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract AlphaToken is ERC20, Ownable {
    uint256 public constant TOTAL_TAX_PERCENT = 5; // Total tax (all for liquidity)
    uint256 public immutable taxEndTime; // Timestamp when tax period ends
    uint256 public constant TAX_DURATION = 1 hours; // 1 hour tax period
    uint256 private constant INITIAL_SUPPLY = 1_000_000; // 1M ALPHA tokens
    
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public constant ROUTER = 0x165C3410fC91EF562C50559f7d2289fEbed552d9; // PulseX V2 Router

    mapping(address => bool) public isTaxExempt;
    bool private swapping;

    // Events for tracking
    event LiquidityAdded(uint256 tokenAmount, uint256 wplsAmount);
    event TaxCollected(address indexed from, uint256 amount);

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

    // Override _update with tax logic and exemptions
    function _update(address from, address to, uint256 amount) internal virtual override {
        // If tax period is over, use default ERC20 behavior
        if (block.timestamp > taxEndTime) {
            super._update(from, to, amount);
            return;
        }

        // Exempt msg.sender, router, and contract from tax
        if (isTaxExempt[from] || isTaxExempt[to] || swapping) {
            super._update(from, to, amount);
            return;
        }

        // Tax logic for non-exempt addresses during tax period
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

    // Internal function to add liquidity
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
            owner(), // LP tokens to owner
            block.timestamp
        );

        emit LiquidityAdded(amountToken, wplsBalance);
    }

    // Helper function to check remaining tax time
    function getRemainingTaxTime() external view returns (uint256) {
        return block.timestamp >= taxEndTime ? 0 : taxEndTime - block.timestamp;
    }

    // Allow contract to receive WPLS
    receive() external payable {}

    // Recover non-native tokens sent to contract
    function recoverTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "Cannot recover native token");
        IERC20(token).transfer(msg.sender, amount);
    }
}
