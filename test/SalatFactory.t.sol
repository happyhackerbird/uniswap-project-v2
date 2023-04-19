// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {console} from "./utils/Console.sol";
import {DSTest} from "ds-test/test.sol";
import {StdAssertions} from "lib/prb-math/lib/forge-std/src/StdAssertions.sol";
import {Vm} from "forge-std/Vm.sol";

import {SalatswapPair} from "src/SalatswapPair.sol";
import {SalatFactory} from "src/SalatFactory.sol";
import {MyToken} from "src/MyToken.sol";

contract SalatFactoryTest is DSTest, StdAssertions {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    SalatFactory internal factory;
    MyToken internal t1;
    MyToken internal t2;

    event PairCreated(
        address indexed token,
        address indexed token2,
        address pair,
        uint
    );

    constructor() public {
        factory = new SalatFactory();
        t1 = new MyToken(10);
        t2 = new MyToken(10);
    }

    function test_createPair_Basic() public {
        address addr = factory.createPair(address(t1), address(t2));
        assert(addr != address(0));
    }

    // function test_createPair_contractAtAddress() public {
    //     t1 = new MyToken(10);
    //     t2 = new MyToken(10);

    //     bytes memory arg = abi.encodePacked(address(t1), address(t2));
    //     bytes memory bytecode = type(SalatswapPair).creationCode;
    //     bytes32 salt = keccak256(abi.encodePacked(address(t1), address(t2)));
    //     address expected_addr = address(
    //         uint160(
    //             uint(
    //                 keccak256(
    //                     abi.encodePacked(
    //                         bytes1(0xff), // to avoid collisions with CREATE
    //                         address(factory),
    //                         salt,
    //                         keccak256(abi.encodePacked(bytecode, arg))
    //                     )
    //                 )
    //             )
    //         )
    //     );

    //     // vm.expectEmit(true, true, true, true);
    //     // emit PairCreated(address(t1), address(t2), address(expected_addr), 1);
    //     address addr = factory.createPair(address(t1), address(t2));
    //     assertEq(addr, expected_addr);
    // }

    function test_revert_createPair_ZeroAddress() public {
        vm.expectRevert("SalatFactory: ZERO_ADDRESS");
        factory.createPair(address(t1), address(0));
    }

    function test_revert_createPair_IdenticalTokens() public {
        vm.expectRevert("SalatFactory: IDENTICAL_TOKENS");
        factory.createPair(address(t1), address(t1));
    }

    function test_revert_createPair_Duplicates() public {
        test_createPair_Basic();
        vm.expectRevert("SalatFactory: PAIR_EXISTS");
        factory.createPair(address(t2), address(t1));
    }
}
