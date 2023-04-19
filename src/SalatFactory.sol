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

    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

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
        CREATE2 requires the bytecode and salt (sequence of bytes provided by the sender) */

        // retrieve the creation bytecode, the code of the constructor that is run upon contract creation and generates the runtime code
        bytes memory bytecode = type(SalatswapPair).creationCode;
        // get a unique salt and therefore address for the token pair
        bytes32 salt = keccak256(abi.encodePacked(t1, t2));
        //
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // initialize the pair contract's token addresses
        SalatswapPair(pair).initialize(t1, t2);

        // store the pair address & emit event
        pairs[t1][t2] = pair;
        pairs[t2][t1] = pair;
        allPairs.push(pair);
        emit PairCreated(t1, t2, pair, allPairs.length);
    }
}
