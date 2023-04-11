// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "solmate/tokens/ERC20.sol";
import "@prb/math/Common.sol";

contract SalatswapPair is ERC20 {
    ERC20 private _token1;
    ERC20 private _token2;
    uint256 private _reserve1;
    uint256 private _reserve2;

    uint256 constant MIN_LIQUIDITY = 1000;

    event Mint(address indexed sender, uint256 deposit1, uint256 deposit2);
    event Burn(address indexed to, uint256 amount1, uint256 amount2);

    constructor(
        address _addr1,
        address _addr2
    ) ERC20("SalatswapV2 Pair", "LEAF", 18) {
        _token1 = ERC20(_addr1);
        _token2 = ERC20(_addr2);
    }

    function mint() public returns (uint256 liquidity) {
        // get deposited amounts
        uint256 balance1 = _token1.balanceOf(address(this));
        uint256 balance2 = _token2.balanceOf(address(this));
        uint256 deposit1 = balance1 - _reserve1;
        uint256 deposit2 = balance2 - _reserve2;

        // calculate liquidity
        if (getTotalLiquidity() == 0) {
            // if empty, use geometric means of deposited amounts (not ether amount like v1) // TODO why
            liquidity = prbSqrt(deposit1 * deposit2) - MIN_LIQUIDITY; // see Test PriceManipulationAtInitIsExpensive
            _mint(address(0), MIN_LIQUIDITY);
        } else {
            // get the minimum to disincentivize depositing unbalanced ratios
            uint a = (deposit1 * getTotalLiquidity()) / _reserve1;
            uint b = (deposit2 * getTotalLiquidity()) / _reserve2;
            liquidity = a < b ? a : b;
        }
        require(liquidity > 0, "Liquidity provided is too low");

        // mint liquidity & update reserves
        _mint(msg.sender, liquidity);
        _update(balance1, balance2);
        emit Mint(msg.sender, deposit1, deposit2);
    }

    function burn(address to) public {
        // get the current token reserves
        // (uint256 balance1, uint256 balance2) = getReserves(); // shouldnt this always be the current reserves ?
        uint256 balance1 = _token1.balanceOf(address(this));
        uint256 balance2 = _token2.balanceOf(address(this));

        // get the amount of liquidity to burn
        uint256 burnLP = balanceOf[address(this)];
        require(burnLP > 0, "No liquidity to be burnt");
        uint tokenAmount1 = (burnLP * balance1) / getTotalLiquidity();
        uint tokenAmount2 = (burnLP * balance2) / getTotalLiquidity();

        // burn liquidity & update reserves
        _burn(address(this), burnLP);
        require(_token1.transfer(to, tokenAmount1));
        require(_token2.transfer(to, tokenAmount2));
        balance1 = _token1.balanceOf(address(this));
        balance2 = _token2.balanceOf(address(this));
        _update(balance1, balance2);
        emit Burn(to, tokenAmount1, tokenAmount2);
    }

    // ---------------------------------------- Helpers -----------------------------------------
    function getReserves() public view returns (uint256, uint256) {
        return (_reserve1, _reserve2);
    }

    function getTotalLiquidity() public view returns (uint256) {
        return totalSupply;
    }

    function getLiquidity(address account) public view returns (uint256) {
        return balanceOf[account];
    }

    function _update(uint256 balance1, uint256 balance2) private {
        _reserve1 = balance1;
        _reserve2 = balance2;
    }
}
