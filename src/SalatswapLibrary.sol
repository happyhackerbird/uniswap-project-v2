// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {SalatswapPair} from "./SalatswapPair.sol";
import {SalatswapFactory} from "./SalatswapFactory.sol";

library SalatswapLibrary {
    // calculate address as how it would be generated with CREATE2 thereby avoiding external calls (gas)
    function pairFor(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal view returns (address pair) {
        // in the factory contract we sorted the tokens before creating the pair
        // (address token1, address token2) = sortTokens(tokenA, tokenB);
        // pair = address(
        //     uint160(
        //         uint256(
        //             keccak256(
        //                 abi.encodePacked(
        //                     hex"ff",
        //                     factoryAddress,
        //                     keccak256(abi.encodePacked(token1, token2)), // salt
        //                     keccak256(type(SalatswapPair).creationCode) // bytecode
        //                 )
        //             )
        //         )
        //     )
        // ); // DOES NOT WORK, therefore using the expensive way - TODO
        pair = SalatswapFactory(factoryAddress).pairs(tokenA, tokenB);
    }

    // get the reserves of a pair and sort them
    function getReserves(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal view returns (uint reserveA, uint reserveB) {
        (address token1, ) = sortTokens(tokenA, tokenB);
        // fetch the reserves
        (uint reserve1, uint reserve2, ) = SalatswapPair(
            pairFor(factoryAddress, tokenA, tokenB)
        ).getReserves();
        // return the reserves according to how we sorted the tokens
        (reserveA, reserveB) = tokenA == token1
            ? (reserve1, reserve2)
            : (reserve2, reserve1);
    }

    // sort the tokens by address
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // get a price quote for the specified amount given the current reserves
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) internal pure returns (uint amountB) {
        require(amountA > 0, "SalatswapLibrary: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "SalatswapLibrary: INSUFFICIENT_LIQUIDITY"
        );
        amountB = (amountA * reserveB) / reserveA; // same as in Uniswap V1
        // if the ratio between the reserves changes it will affect the quote
        // eg reserveA > reserveB makes makes amountB smaller
    }
}
