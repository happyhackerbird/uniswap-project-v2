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
    }

    function test_createPair() public {
        t1 = new MyToken(10);
        t2 = new MyToken(10);
        address addr = factory.createPair(address(t1), address(t2));
    }

    function test_contractAtAddress() public {
        t1 = new MyToken(10);
        t2 = new MyToken(10);

        bytes memory arg = abi.encodePacked(address(t1), address(t2));
        bytes memory bytecode = type(SalatswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(address(t1), address(t2)));
        address expected_addr = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff), // to avoid collisions with CREATE
                            address(factory),
                            salt,
                            keccak256(abi.encodePacked(bytecode, arg))
                        )
                    )
                )
            )
        );

        // vm.expectEmit(true, true, true, true);
        // emit PairCreated(address(t1), address(t2), address(expected_addr), 1);
        address addr = factory.createPair(address(t1), address(t2));
        assertEq(addr, expected_addr);
    }
}
