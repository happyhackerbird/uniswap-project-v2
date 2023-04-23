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

    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token1, address token2) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
