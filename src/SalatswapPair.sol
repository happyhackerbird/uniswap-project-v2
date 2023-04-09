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

    constructor(
        address _addr1,
        address _addr2
    ) ERC20("SalatswapV2 Pair", "LEAF", 18) {
        _token1 = ERC20(_addr1);
        _token2 = ERC20(_addr2);
    }

    function mint() public {
        // get deposited amounts
        uint256 balance1 = _token1.balanceOf(address(this));
        uint256 balance2 = _token2.balanceOf(address(this));
        uint256 deposit1 = balance1 - _reserve1;
        uint256 deposit2 = balance2 - _reserve2;

        // calculate liquidity
        uint256 liquidity;
        if (getTotalLiquidity() == 0) {
            // if empty, use geometric means of deposited amounts (not ether amount like v1) // TODO why
            liquidity = prbSqrt(deposit1 * deposit2) - MIN_LIQUIDITY; // see Test PriceManipulationAtInitIsExpensive
            _mint(address(0), MIN_LIQUIDITY);
        } else {
            // get the minimum to disincentivize depositing unbalanced ratios
            uint a = (deposit1 / _reserve1) * getTotalLiquidity();
            uint b = (deposit2 / _reserve2) * getTotalLiquidity();
            liquidity = a < b ? a : b;
        }
        require(liquidity > 0, "Liquidity provided is too low");

        // mint liquidity & update reserves
        _mint(msg.sender, liquidity);
        _update(balance1, balance2);
        emit Mint(msg.sender, deposit1, deposit2);
    }

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
