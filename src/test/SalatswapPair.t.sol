// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";
import {console} from "./utils/Console.sol";
import {DSTest} from "ds-test/test.sol";

contract SalatswapPairTest is BaseSetup {
    function test_setUp_mint() public {
        assertEq(dex.getLiquidity(address(this)), 10 ether - 1000);
        verifyReserves(10 ether, 10 ether);
        assertEq(dex.getTotalLiquidity(), 10 ether);
    }

    function setUp() public {
        token1.transfer(address(dex), 10 ether);
        token2.transfer(address(dex), 10 ether);
        dex.mint();
    }

    // ---------------------------------------- Helpers -----------------------------------------
    function verifyReserves(uint256 _reserve1, uint256 _reserve2) internal {
        (uint256 r1, uint256 r2) = dex.getReserves();
        assertEq(r1, _reserve1);
        assertEq(r2, _reserve2);
    }
}
