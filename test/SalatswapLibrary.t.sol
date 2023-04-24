// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {SalatswapLibrary} from "src/SalatswapLibrary.sol";
import {SalatswapFactory} from "src/SalatswapFactory.sol";
import {SalatswapPair} from "src/SalatswapPair.sol";
import {MyToken} from "src/MyToken.sol";

contract SalatswapLibraryTest is DSTest {
    SalatswapFactory internal factory;
    MyToken internal tokenA;
    MyToken internal tokenB;
    SalatswapPair internal pair;

    function setUp() public {
        factory = new SalatswapFactory();
        tokenA = new MyToken(10);
        tokenB = new MyToken(10);
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        pair = SalatswapPair(pairAddress);
    }

    function test_pairFor() public {
        address pairAddress = SalatswapLibrary.pairFor(
            address(factory),
            address(tokenA),
            address(tokenB)
        );
        assertEq(pairAddress, factory.pairs(address(tokenA), address(tokenB)));
    }

    function test_getReserves() public {
        tokenA.transfer(address(pair), 4 ether);
        tokenB.transfer(address(pair), 5 ether);
        pair.mint(address(this));
        (uint256 reserveA, uint256 reserveB) = SalatswapLibrary.getReserves(
            address(factory),
            address(tokenA),
            address(tokenB)
        );
        assertEq(reserveA, 4 ether); // reserves will be sorted according the token address
        assertEq(reserveB, 5 ether);
    }

    function test_quote() public {
        uint quote = SalatswapLibrary.quote(1.5 ether, 2 ether, 2 ether);
        assertEq(quote, 1.5 ether);

        quote = SalatswapLibrary.quote(1 ether, 1 ether, 2 ether);
        assertEq(quote, 2 ether);

        quote = SalatswapLibrary.quote(1 ether, 2 ether, 1 ether);
        assertEq(quote, 0.5 ether);
    }
}
