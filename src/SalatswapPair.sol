// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "solmate/tokens/ERC20.sol";
import "@prb/math/Common.sol";
import {console} from "test/utils/Console.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";
import "./interfaces/IERC20.sol";

contract SalatswapPair is ERC20 {
    using UQ112x112 for uint224;

    uint256 constant MIN_LIQUIDITY = 1000;

    address public token1;
    address public token2;

    // switch to uint112 type to use UQ112x112.sol
    uint112 private _reserve1;
    uint112 private _reserve2;
    uint32 private _blockTimestampLast; // last time an exchange occurred
    // --- these three variables are all in one storage slot

    uint256 public price1CumulativeLast;
    uint256 public price2CumulativeLast;

    event Minted(address indexed sender, uint256 deposit1, uint256 deposit2);
    event Burned(address indexed to, uint256 amount1, uint256 amount2);
    event Swapped(address indexed to, uint256 amount1, uint256 amount2);
    event Synced(uint112 reserve1, uint112 reserve2);

    constructor(
        address addr1,
        address addr2
    ) ERC20("SalatswapV2 Pair", "LEAF", 18) {
        token1 = addr1;
        token2 = addr2;
    }

    function mint() public returns (uint256 liquidity) {
        // get deposited amounts
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 balance2 = IERC20(token2).balanceOf(address(this));
        (uint112 reserve1, uint112 reserve2, ) = getReserves(); // is the third value read and then dropped - in this case save gas by assigning it and passing to the _update to save another storage read
        uint256 deposit1 = balance1 - reserve1;
        uint256 deposit2 = balance2 - reserve2;

        // calculate liquidity
        if (getTotalLiquidity() == 0) {
            // if empty, use geometric means of deposited amounts (not ether amount like v1) // TODO why
            liquidity = prbSqrt(deposit1 * deposit2) - MIN_LIQUIDITY; // see Test UnbalancedRatioAtInit
            _mint(address(0), MIN_LIQUIDITY);
        } else {
            // get the minimum to disincentivize depositing unbalanced ratios
            uint a = (deposit1 * getTotalLiquidity()) / reserve1;
            uint b = (deposit2 * getTotalLiquidity()) / reserve2;
            liquidity = a < b ? a : b;
        }
        require(liquidity > 0, "Liquidity provided is too low");

        // mint liquidity & update reserves
        _mint(msg.sender, liquidity);
        _update(balance1, balance2, reserve1, reserve2);
        emit Minted(msg.sender, deposit1, deposit2);
    }

    function burn(address to) public {
        // get the current token reserves
        // (uint256 balance1, uint256 balance2) = getReserves(); // shouldnt this always be the current reserves ?
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 balance2 = IERC20(token2).balanceOf(address(this));

        // get the amount of liquidity to burn
        uint256 burnLP = balanceOf[address(this)];
        require(burnLP > 0, "No liquidity to be burnt");
        uint tokenAmount1 = (burnLP * balance1) / getTotalLiquidity();
        uint tokenAmount2 = (burnLP * balance2) / getTotalLiquidity();

        // burn liquidity & update reserves
        _burn(address(this), burnLP);
        _safeTransfer(token1, to, tokenAmount1);
        _safeTransfer(token2, to, tokenAmount2);
        balance1 = IERC20(token1).balanceOf(address(this));
        balance2 = IERC20(token2).balanceOf(address(this));
        (uint112 reserve1, uint112 reserve2, ) = getReserves();
        _update(balance1, balance2, reserve1, reserve2);
        emit Burned(to, tokenAmount1, tokenAmount2);
    }

    function swap(uint256 amount1, uint256 amount2, address to) public {
        (uint112 reserve1, uint112 reserve2, ) = getReserves();

        // ensure validity of specified output amounts
        require(amount1 > 0 || amount2 > 0, "Output amount insufficient");
        require(
            amount1 <= reserve1 && amount2 <= reserve2,
            "Liquidity insufficient"
        );

        // calculate token balances
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) - amount1;
        uint256 balance2 = IERC20(token2).balanceOf(address(this)) - amount2;
        // apply constant product formula
        require(
            balance1 * balance2 >= reserve1 * uint256(reserve2),
            "Invalid trade"
        );

        // update reserves & transfer amounts
        _update(balance1, balance2, reserve1, reserve2);
        if (amount1 > 0) _safeTransfer(token1, to, amount1);
        if (amount2 > 0) _safeTransfer(token2, to, amount2);
        emit Swapped(to, amount1, amount2);
    }

    // force reserves to match current token balances
    function sync() public {
        _update(
            IERC20(token1).balanceOf(address(this)),
            IERC20(token2).balanceOf(address(this)),
            _reserve1,
            _reserve2
        );
    }

    // ---------------------------------------- Helpers -----------------------------------------
    function getReserves() public view returns (uint112, uint112, uint32) {
        return (_reserve1, _reserve2, _blockTimestampLast);
    }

    function getTotalLiquidity() public view returns (uint256) {
        return totalSupply;
    }

    function getLiquidity(address account) public view returns (uint256) {
        return balanceOf[account];
    }

    function _update(
        uint256 balance1,
        uint256 balance2,
        uint112 reserve1,
        uint112 reserve2
    ) private {
        // prevent overflow of conversion to uint112
        require(
            balance1 <= type(uint112).max && balance2 <= type(uint112).max,
            "Balance overflows"
        );

        // unchecked block because we don't want overflows to revert the execution
        unchecked {
            // determine if its the first exchange transaction in a block
            uint32 blockTimestamp = uint32(block.timestamp);
            uint32 timeElapsed = blockTimestamp - _blockTimestampLast;

            // if so, update the cost accumulators
            if (timeElapsed > 0 && reserve1 > 0 && reserve2 > 0) {
                // each cost accumulator is updated with the product of marginal exchange rate and time
                // marginal price is the price without slippage and fees
                // then to get the average price, read them out at two different points in time and divide by the time difference
                price1CumulativeLast +=
                    uint(UQ112x112.encode(reserve2).uqdiv(reserve1)) *
                    timeElapsed;
                price2CumulativeLast +=
                    uint(UQ112x112.encode(reserve1).uqdiv(reserve2)) *
                    timeElapsed;
            }
            _blockTimestampLast = blockTimestamp;
        }
        uint112 r1 = uint112(balance1);
        uint112 r2 = uint112(balance2);
        _reserve1 = r1;
        _reserve2 = r2;
        emit Synced(r1, r2);
    }

    function _safeTransfer(
        address tokenAddress,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = tokenAddress.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer failed"
        );
    }
}
