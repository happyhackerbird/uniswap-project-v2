// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {SalatswapFactory} from "./SalatswapFactory.sol";
import {SalatswapLibrary} from "./SalatswapLibrary.sol";
import {SalatswapPair} from "./SalatswapPair.sol";

contract SalatswapRouter {
    SalatswapFactory factory;

    constructor(address factoryAddress) {
        factory = SalatswapFactory(factoryAddress);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired, // amount the liquidity provider wants to deposit, as well as maximum amount to be deposited
        uint256 amountBDesired,
        uint256 amountAMin, // amount without which transaction cannot take place (specify 0 to skip)
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // calculate amounts to be deposited that will maintain ratio between reserves
        (amountA, amountB) = _getLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        // get address of pair
        address pair = SalatswapLibrary.pairFor(
            address(factory),
            tokenA,
            tokenB
        );

        // transfer the tokens to the exchange and mint the liquidity
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = SalatswapPair(pair).mint(to);
    }

    // calculate the amount of tokens to deposit that maintains ratio between reserves
    // refer back to Uniswap V1 calculation
    function _getLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired, // maximum amount to be deposited
        uint256 amountBDesired,
        uint256 amountAMin, // minimum amounts
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        // create the exchange contract if the trading pair doesnt exist
        if (factory.pairs(tokenA, tokenB) == address(0)) {
            factory.createPair(tokenA, tokenB);
        }
        // get the reserves of the exchange contract
        (uint256 reserveA, uint256 reserveB) = SalatswapLibrary.getReserves(
            address(factory),
            tokenA,
            tokenB
        );

        // if reserves are empty, we just deposit the desired amount
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // get a price quote for the desired amount
            uint256 amountBOptimal = SalatswapLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                // if the price quote is less than the maximum amount, use it
                // since it means that tokenB's price is higher than the provider thought and less deposit is required
                // (conversely if the quote is too high, then a higher deposit would be required)

                // ensure that the quote is within the minimum amount
                // this is specified bedause the liquidity provider wants to limit the transaction to an exchange rate that's close to the current one
                // if there is too much fluctuation in price, cancel so that they can manually decide what to do
                // since it could fluctuate further while the tx sits in the mempool
                require(
                    amountBOptimal >= amountBMin,
                    "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // else get another quote using tokenB as input
                uint amountAOptimal = SalatswapLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                // if this quote is also too high, revert because for both tokens a higher deposit would be required
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _safeTransferFrom(
        address tokenAddress,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = tokenAddress.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer failed"
        );
    }
}
