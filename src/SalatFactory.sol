// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./SalatswapPair.sol";

contract SalatFactory {
    event PairCreated(
        address indexed token,
        address indexed token2,
        address pair,
        uint
    );

    // stores tokens mapped to pair contract
    mapping(address => mapping(address => address)) public pairs;
    // store all pairs created by the factory (cannot iterator over mapping)
    address[] public allPairs;

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(
        address token1,
        address token2
    ) public returns (address pair) {
        // tokens cannot be identical
        require(token1 != token2, "SalatFactory: IDENTICAL_ADDRESSES");

        // sort by address to check for duplicates
        (address t1, address t2) = token1 < token2
            ? (token1, token2)
            : (token2, token1);
        require(pairs[t1][t2] == address(0), "SalatFactory: PAIR_EXISTS");

        // cannot have a zero address
        require(t1 != address(0), "SalatFactory: ZERO_ADDRESS");

        /* deploy pair contract with CREATE2 opcode
        CREATE2 is an opcode that allows to generate an address deterministically
        (as opposed to CREATE which depends on the sender's nonce)
        CREATE2 requires the bytecode and salt (sequence of bytes provided by the sender) 
        Newer versions of Solidity now support salted contract creation with CREATE2, so we don't have to get the creation bytecode manually */

        // get a unique salt for the token pair
        bytes32 salt = keccak256(abi.encodePacked(t1, t2));

        SalatswapPair pairContract = new SalatswapPair{salt: salt}(t1, t2);
        pair = address(pairContract);

        // store the pair address & emit event
        pairs[t1][t2] = pair;
        pairs[t2][t1] = pair;
        allPairs.push(pair);
        emit PairCreated(t1, t2, pair, allPairs.length);
    }
}
