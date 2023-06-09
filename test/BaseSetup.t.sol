// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {StdAssertions} from "lib/prb-math/lib/forge-std/src/StdAssertions.sol";
import {Vm} from "forge-std/Vm.sol";
import {Utilities} from "./utils/Utilities.sol";

import {MyToken} from "src/MyToken.sol";
import {SalatswapPair} from "src/SalatswapPair.sol";

abstract contract BaseSetup is DSTest, StdAssertions {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;

    address internal user2;
    address internal user1;
    // setup the deployer so we dont have to constantly switch to a user
    address internal deployer;

    SalatswapPair public dex;
    MyToken public token1;
    MyToken public token2;
    uint minLiquidity = 1000 wei;

    function setUp() public virtual {
        utils = new Utilities();
        users = utils.createUsers(5);
        user1 = users[0];
        vm.label(user1, "Alice");
        user2 = users[1];
        vm.label(user2, "Bob");
        deployer = address(this);

        token1 = new MyToken(5000);
        token2 = new MyToken(5000);
        dex = new SalatswapPair(address(token1), address(token2));

        token1.transfer(user1, 1000 ether);
        token2.transfer(user1, 1000 ether);

        // token.transfer(user1, 5000 ether);
        // token.transfer(user2, 5000 ether);
        // token.transfer(deployer, 5000 ether);
        // vm.deal(user1, 5000 ether);
        // vm.deal(user2, 5000 ether);
        // vm.deal(deployer, 5000 ether);

        // token.approve(address(dex), 5000 ether);
        // vm.prank(user1);
        // token.approve(address(dex), 5000 ether);
        // vm.prank(user2);
        // token.approve(address(dex), 5000 ether);
    }

    function _initializeDex(
        SalatswapPair d,
        uint256 initialLiquidity1,
        uint256 initialLiquidity2,
        address to
    ) internal {
        token1.transfer(address(d), initialLiquidity1);
        token2.transfer(address(d), initialLiquidity2);
        dex.mint(to);
    }

    function _verifyReserves(uint256 reserve1, uint256 reserve2) internal {
        (uint112 r1, uint112 r2, ) = dex.getReserves();
        assertEq(r1, uint112(reserve1));
        assertEq(r2, uint112(reserve2));
    }
}
