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

    // ---------------------------------- LIQUIDITY ---------------------------------- //
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired, // amount the liquidity provider wants to deposit, as well as maximum amount to be deposited
        uint256 amountBDesired,
        uint256 amountAMin, // amount without which transaction cannot take place (specify 0 to skip)
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
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
                    "SalatswapRouter: INSUFFICIENT_B_AMOUNT"
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
                    "SalatswapRouter: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB) {
        address pair = SalatswapLibrary.pairFor(
            address(factory),
            tokenA,
            tokenB
        );
        // transfer liquidity tokens to the exchange
        SalatswapPair(pair).transferFrom(msg.sender, pair, liquidity);
        // burn the liquidity
        (uint amount1, uint amount2) = SalatswapPair(pair).burn(to);
        // sort the amounts by the token address to be able to compare them
        (address token1, ) = SalatswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token1
            ? (amount1, amount2)
            : (amount2, amount1);
        require(
            amountA >= amountAMin,
            "SalatswapRouter: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "SalatswapRouter: INSUFFICIENT_B_AMOUNT"
        );
    }

    // ---------------------------------- SWAPPING ---------------------------------- //

    // swap an exact input amount for a minimum output amount
    // it makes chained swaps along a specified path
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path, //sequence of token addresses along which to swap
        address to // final amount sent here
    ) public returns (uint256[] memory amounts) {
        // first get the calculated amounts along the path
        amounts = SalatswapLibrary.getAmountsOut(
            address(factory),
            amountIn,
            path
        );
        // check if the last output amount is big enough
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "SalatswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        // initialize the swap by transferring the first amount (amountIn) to the first pair
        _safeTransferFrom(
            path[0],
            msg.sender,
            SalatswapLibrary.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );
        // then continue to swap along the path
        _swap(amounts, path, to);
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address to
    ) internal {
        for (uint i; i < path.length - 1; i++) {
            // get the pair
            (address input, address output) = (path[i], path[i + 1]);
            // sort tokens
            (address token1, ) = SalatswapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount1Out, uint amount2Out) = input == token1
                ? (uint(0), amountOut)
                : (amountOut, uint(0));
            // if we are not yet at the end of the path, the address to which to transfer the the tokens is the contract of the next token pair
            address _to = i < path.length - 2
                ? SalatswapLibrary.pairFor(
                    address(factory),
                    output,
                    path[i + 2]
                )
                : to;
            // call swap on the pair of the current iteration
            SalatswapPair(
                SalatswapLibrary.pairFor(address(factory), input, output)
            ).swap(amount1Out, amount2Out, _to);
        }
    }

    // ---------------------------------- HELPERS ---------------------------------- //

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
