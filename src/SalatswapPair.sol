// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "solmate/tokens/ERC20.sol";

// import "./libraries/Math.sol";

contract SalatswapPair is ERC20 {
    ERC20 private _token1;
    ERC20 private _token2;
    uint256 private _reserve1;
    uint256 private _reserve2;

    constructor(
        address _addr1,
        address _addr2
    ) ERC20("SalatswapV2 Pair", "SALWAP", 18) {
        _token1 = ERC20(_addr1);
        _token2 = ERC20(_addr2);
    }

    function mint() public {
        (uint256 _reserve1, uint256 _reserve2) = getReserves();
        uint256 balance1 = _token1.balanceOf(address(this));
        uint256 balance2 = _token2.balanceOf(address(this));
        uint256 deposit1 = balance1 - _reserve1;
        uint256 deposit2 = balance2 - _reserve2;
        uint256 liquidity;
    }

    function getReserves() public view returns (uint256, uint256) {
        return (_reserve1, _reserve2);
    }

    function getTotalLiquidity() public view returns (uint256) {
        return totalSupply;
    }
}
