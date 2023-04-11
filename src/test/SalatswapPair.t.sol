// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";
import {console} from "./utils/Console.sol";

contract SalatswapPairTest is BaseSetup {
    event Mint(address indexed sender, uint256 deposit1, uint256 deposit2);
    uint initialLiquidity = 10 ether;
    uint minLiquidity = 1000 wei;

    function setUp() public {
        token1.transfer(address(dex), initialLiquidity);
        token2.transfer(address(dex), initialLiquidity);
        dex.mint();
    }

    function test_mint_MintInitialAndMinimumLiquidity() public {
        // test the setup
        assertEq(
            dex.getLiquidity(address(this)),
            initialLiquidity - minLiquidity
        );
        verifyReserves(initialLiquidity, initialLiquidity);
        assertEq(dex.getTotalLiquidity(), initialLiquidity);
    }

    function test_mint_MintAfterInitialLiquidity() public {
        vm.expectEmit(true, true, true, true);
        emit Mint(address(user1), 20 ether, 20 ether);

        vm.startPrank(user1);
        token1.transfer(address(dex), 20 ether);
        token2.transfer(address(dex), 20 ether);
        dex.mint();
        assertEq(dex.getLiquidity(address(user1)), 20 ether);
        vm.stopPrank();

        verifyReserves(30 ether, 30 ether);
        assertEq(dex.getTotalLiquidity(), 30 ether);
    }

    function test_mint_DisincentivizeUnbalancedRatios() public {
        vm.expectEmit(true, true, true, true);
        emit Mint(address(user1), 18 ether, 22 ether);
        verifyReserves(initialLiquidity, initialLiquidity);

        vm.startPrank(user1);
        token1.transfer(address(dex), 18 ether);
        token2.transfer(address(dex), 22 ether);
        dex.mint();
        assertEq(dex.getLiquidity(address(user1)), 18 ether); // we will only get 18 ether of liquidity
        vm.stopPrank();

        verifyReserves(28 ether, 32 ether);
        assertEq(dex.getTotalLiquidity(), 28 ether);
    }

    function test_revert_mint_Underflow() public {
        // // with underflow if L < MIN_LIQUIDITY
        // SalatswapPair d = new SalatswapPair(address(token1), address(token2));
        // token1.transfer(address(d), 100 wei);
        // token2.transfer(address(d), 100 wei);
        // vm.expectRevert();
        // d.mint();
    }

    function test_revert_mint_InsufficientLiquidity() public {
        //if L = MIN_LIQUIDITY
        SalatswapPair d2 = new SalatswapPair(address(token1), address(token2));
        token1.transfer(address(d2), 1000 wei);
        token2.transfer(address(d2), 1000 wei);
        vm.expectRevert("Liquidity provided is too low");
        d2.mint();
    }

    function test_mint_UnbalancedRatioAtInit() public {
        // show how MIN_LIQUIDITY in theory prevents price manipulation at init
        // trying to manipulate the price by depositing ratio such that one token would be more expensive
        SalatswapPair d1 = new SalatswapPair(address(token1), address(token2));
        SalatswapPair d2 = new SalatswapPair(address(token1), address(token2));
        uint weakToken = 1001 wei;
        uint strongToken = 1 wei;
        token1.transfer(address(d1), weakToken);
        token2.transfer(address(d1), strongToken);
        // vm.expectRevert("Liquidity provided is too low");
        // d1.mint(); // does not succeed due to MIN_LIQUIDITY

        token1.transfer(address(d2), weakToken * weakToken); // a factor of MIN_LIQUIDITY more have to be deposited
        token2.transfer(address(d2), strongToken);
        d2.mint();
        assertEq(d2.getTotalLiquidity(), weakToken);
    }

    // ---------------------------------------- Helpers -----------------------------------------
    function verifyReserves(uint256 _reserve1, uint256 _reserve2) internal {
        (uint256 r1, uint256 r2) = dex.getReserves();
        assertEq(r1, _reserve1);
        assertEq(r2, _reserve2);
    }
}
