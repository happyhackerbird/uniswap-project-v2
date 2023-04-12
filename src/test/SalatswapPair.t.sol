// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";
import {console} from "./utils/Console.sol";

contract SalatswapPairTest is BaseSetup {
    uint initialLiquidity = 10 ether;
    uint minLiquidity = 1000 wei;

    event Mint(address indexed sender, uint256 deposit1, uint256 deposit2);
    event Burn(address indexed to, uint256 amount1, uint256 amount2);
    event Swap(address indexed to, uint256 amount1, uint256 amount2);

    event Transfer(address indexed from, address indexed to, uint256 amount);

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

        // vm.expectEmit(true, true, true, true);
        // emit Transfer(address(0), address(user1), 20 ether);

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

    function test_burn() public {
        uint oldLiquiditySender = dex.getLiquidity(address(this));
        uint oldLiquidityDex = dex.getTotalLiquidity();
        uint oldToken1User = token1.balanceOf(address(user1));
        uint oldToken2User = token2.balanceOf(address(user1));

        // ensure that some liquidity has been transferred
        dex.transfer(address(dex), 5 ether);
        vm.expectEmit(true, true, true, true);
        emit Burn(address(user1), 5 ether, 5 ether);
        dex.burn(address(user1));

        assertEq(dex.getLiquidity(address(this)), oldLiquiditySender - 5 ether); // liquidity of sender has been burned
        assertEq(dex.getTotalLiquidity(), oldLiquidityDex - 5 ether);
        verifyReserves(oldLiquidityDex - 5 ether, oldLiquidityDex - 5 ether);
        assertEq(token1.balanceOf(address(user1)), oldToken1User + 5 ether); // tokens have been transferred to a different user
        assertEq(token2.balanceOf(address(user1)), oldToken2User + 5 ether);
    }

    function test_revert_burn_NoLiquidity() public {
        vm.expectRevert("No liquidity to be burnt");
        dex.burn(address(this));
    }

    function test_burn_BurnAll() public {
        dex.transfer(address(dex), initialLiquidity - minLiquidity);
        dex.burn(address(this));
        assertEq(dex.getTotalLiquidity(), minLiquidity); // MIN_LIQUIDITY is always in the pool
        assertEq(dex.getLiquidity(address(this)), 0);
        verifyReserves(minLiquidity, minLiquidity); // cannot achieve zero reserve
    }

    function test_revert_BurnZero() public {
        vm.expectRevert("No liquidity to be burnt");
        dex.burn(address(this));
    }

    function test_revert_BurnBeforeMint() public {
        SalatswapPair d = new SalatswapPair(address(token1), address(token2));
        vm.expectRevert("No liquidity to be burnt");
        d.burn(address(this));
    }

    function test_burn_DifferentRatioSameUser() public {
        token1.transfer(address(dex), 5 ether); // <=== in total we have put in 15 ether worth of tokens
        token2.transfer(address(dex), 1 ether);
        dex.mint();
        uint oldLiquidityUser = dex.getLiquidity(address(this));
        uint oldToken1User = token1.balanceOf(address(this));
        (uint256 r1, uint256 r2) = dex.getReserves();
        dex.transfer(address(dex), oldLiquidityUser); // this burns all the liquidity in the pool
        dex.burn(address(this));

        assertEq(dex.getLiquidity(address(this)), 0);
        verifyReserves(1364, minLiquidity); // we make a loss of 364 wei -- these belong to the pool now
        uint returned = ((token1.balanceOf(address(this)) - oldToken1User));
        assertApproxEqRel(returned, 15 ether, 1e2); // <=== here get back almost all 15 ether (99%)
    }

    function test_burn_DifferentRatioAndUser() public {
        // same as above but with a different user to demonstrate how the liquidity is distributed in this case
        vm.startPrank(user1);
        token1.transfer(address(dex), 5 ether); // <=== here put in 5 ether worth of tokens
        token2.transfer(address(dex), 1 ether);
        dex.mint(); // <=== mint 1 LP

        uint oldLiquidityUser = dex.getLiquidity(address(user1));
        uint oldToken1User = token1.balanceOf(address(user1));

        dex.transfer(address(dex), oldLiquidityUser); // <=== and then burn all 1 LP of the user
        dex.burn(address(user1));
        vm.stopPrank();

        assertEq(dex.getLiquidity(address(user1)), 0);
        uint returned = (token1.balanceOf(address(user1)) - oldToken1User);
        assertApproxEqRel(returned, 5 ether, 8e17); // <=== here they get back only about 20% of what we put in
        assertEq(returned / 1 ether, 1); // which is about 1 ether

        uint lossOtherUser = 5 ether - returned;
        verifyReserves(10 ether + lossOtherUser, 10 ether);

        // now we show that this loss is instead distributed to the other user (who provided the first liquidity)
        uint oldToken1FirstUser = token1.balanceOf(address(this));
        uint oldToken2FirstUser = token2.balanceOf(address(this));
        dex.transfer(address(dex), initialLiquidity - minLiquidity);
        dex.burn(address(this));

        assertEq(dex.getLiquidity(address(this)), 0);
        uint lossFirstUser = 364 wei;
        verifyReserves(minLiquidity + lossFirstUser, minLiquidity); // some wei are again lost to the pool
        returned = (token1.balanceOf(address(this)) - oldToken1FirstUser);
        assertEq(
            returned,
            10 ether + lossOtherUser - lossFirstUser - minLiquidity // <=== this user gets the tokens lost to the other user!
        );
        assertEq(
            token2.balanceOf(address(this)) - oldToken2FirstUser,
            10 ether - minLiquidity
        );
    }

    // ---------------------------------------- Helpers -----------------------------------------
    function verifyReserves(uint256 _reserve1, uint256 _reserve2) internal {
        (uint256 r1, uint256 r2) = dex.getReserves();
        assertEq(r1, _reserve1);
        assertEq(r2, _reserve2);
    }
}
