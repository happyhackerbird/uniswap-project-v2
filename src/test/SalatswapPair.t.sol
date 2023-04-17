// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";
import {console} from "./utils/Console.sol";
import {UQ112x112} from "src/libraries/UQ112x112.sol";

contract SalatswapPairTest is BaseSetup {
    using UQ112x112 for uint224;

    uint initialLiquidity = 10 ether;
    uint minLiquidity = 1000 wei;
    uint firstTokenBalance = 4000 ether - initialLiquidity;

    event Minted(address indexed sender, uint256 deposit1, uint256 deposit2);
    event Burned(address indexed to, uint256 amount1, uint256 amount2);
    event Swapped(address indexed to, uint256 amount1, uint256 amount2);

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        vm.warp(0); // reset block timestamp
        token1.transfer(address(dex), initialLiquidity);
        token2.transfer(address(dex), initialLiquidity);
        dex.mint();
    }

    function test_mint_MintedInitialAndMinimumLiquidity() public {
        // test the setup
        assertEq(
            dex.getLiquidity(address(this)),
            initialLiquidity - minLiquidity
        );
        _verifyReserves(initialLiquidity, initialLiquidity);
        assertEq(dex.getTotalLiquidity(), initialLiquidity);
        assertEq(token1.balanceOf(address(this)), firstTokenBalance);
        assertEq(token2.balanceOf(address(this)), firstTokenBalance);
    }

    function test_mint_MintedAfterInitialLiquidity() public {
        vm.expectEmit(true, true, true, true);
        emit Minted(address(user1), 20 ether, 20 ether);

        // vm.expectEmit(true, true, true, true);
        // emit Transfer(address(0), address(user1), 20 ether);

        vm.startPrank(user1);
        token1.transfer(address(dex), 20 ether);
        token2.transfer(address(dex), 20 ether);
        dex.mint();
        vm.stopPrank();

        assertEq(dex.getLiquidity(address(user1)), 20 ether);
        _verifyReserves(30 ether, 30 ether);
        assertEq(dex.getTotalLiquidity(), 30 ether);
        assertEq(token1.balanceOf(address(user1)), 1000 ether - 20 ether);
        assertEq(token2.balanceOf(address(user1)), 1000 ether - 20 ether);
    }

    function test_mint_DisincentivizeUnbalancedRatios() public {
        vm.expectEmit(true, true, true, true);
        emit Minted(address(user1), 18 ether, 22 ether);
        _verifyReserves(initialLiquidity, initialLiquidity);

        vm.startPrank(user1);
        token1.transfer(address(dex), 18 ether);
        token2.transfer(address(dex), 22 ether);
        dex.mint();
        vm.stopPrank();

        assertEq(dex.getLiquidity(address(user1)), 18 ether); // we will only get 18 ether of liquidity
        _verifyReserves(28 ether, 32 ether);
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

    function test_burn_Basic() public {
        uint oldLiquiditySender = dex.getLiquidity(address(this));
        uint oldLiquidityDex = dex.getTotalLiquidity();

        // ensure that some liquidity has been transferred
        dex.transfer(address(dex), 5 ether);
        vm.expectEmit(true, true, true, true);
        emit Burned(address(this), 5 ether, 5 ether);
        dex.burn(address(this));

        assertEq(dex.getLiquidity(address(this)), oldLiquiditySender - 5 ether); // liquidity of sender has been burned
        assertEq(dex.getTotalLiquidity(), oldLiquidityDex - 5 ether);
        _verifyReserves(oldLiquidityDex - 5 ether, oldLiquidityDex - 5 ether);
        assertEq(token1.balanceOf(address(this)), firstTokenBalance + 5 ether); // basic scenario where tokens are transferred to same user
        assertEq(token2.balanceOf(address(this)), firstTokenBalance + 5 ether);
    }

    function test_revert_burn_NoLiquidity() public {
        vm.expectRevert("No liquidity to be burnt");
        dex.burn(address(this));
    }

    function test_burn_BurnedAll() public {
        dex.transfer(address(dex), initialLiquidity - minLiquidity);
        vm.expectEmit(true, true, true, true);
        emit Burned(
            address(this),
            initialLiquidity - minLiquidity,
            initialLiquidity - minLiquidity
        );
        dex.burn(address(this));
        assertEq(dex.getTotalLiquidity(), minLiquidity); // MIN_LIQUIDITY is always in the pool
        assertEq(dex.getLiquidity(address(this)), 0);
        _verifyReserves(minLiquidity, minLiquidity); // cannot achieve zero reserve by burning
        assertEq(
            token1.balanceOf(address(this)),
            firstTokenBalance + initialLiquidity - minLiquidity
        );
        assertEq(
            token2.balanceOf(address(this)),
            firstTokenBalance + initialLiquidity - minLiquidity
        );
    }

    function test_revert_burn_BurnedZero() public {
        vm.expectRevert("No liquidity to be burnt");
        dex.burn(address(this));
    }

    function test_revert_burn_BurnedBeforeMinted() public {
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
        // (uint256 r1, uint256 r2) = dex.getReserves();
        dex.transfer(address(dex), oldLiquidityUser); // this burns all the liquidity in the pool
        dex.burn(address(this));

        assertEq(dex.getLiquidity(address(this)), 0);
        _verifyReserves(1364, minLiquidity); // we make a loss of 364 wei -- these belong to the pool now
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
        _verifyReserves(10 ether + lossOtherUser, 10 ether);

        // now we show that this loss is instead distributed to the other user (who provided the first liquidity)
        uint oldToken1FirstUser = firstTokenBalance;
        uint oldToken2FirstUser = firstTokenBalance;
        dex.transfer(address(dex), initialLiquidity - minLiquidity);
        dex.burn(address(this));

        assertEq(dex.getLiquidity(address(this)), 0);
        uint lossFirstUser = 364 wei;
        _verifyReserves(minLiquidity + lossFirstUser, minLiquidity); // some wei are again lost to the pool
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

    function test_swap_Basic() public {
        uint256 amountOut = 0.9 ether;

        token1.transfer(address(dex), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit Swapped(address(this), 0, 0.9 ether);
        dex.swap(0, amountOut, address(this));

        assertEq(token1.balanceOf(address(this)), firstTokenBalance - 1 ether);
        assertEq(
            token2.balanceOf(address(this)),
            firstTokenBalance + amountOut
        );
        assertEq(dex.getTotalLiquidity(), initialLiquidity);
        _verifyReserves(11 ether, 9.1 * 1 ether);
    }

    function test_swap_BasicWithSlippage() public {
        uint256 amountOut = 5 ether;
        token2.transfer(address(dex), 10 ether); // we need to account for a lot of slippage bc the reserve is not that big

        vm.expectEmit(true, true, true, true);
        emit Swapped(address(this), 5 ether, 0);
        dex.swap(amountOut, 0, address(this));

        assertEq(token1.balanceOf(address(this)), firstTokenBalance + 5 ether);
        assertEq(token2.balanceOf(address(this)), firstTokenBalance - 10 ether);
        assertEq(dex.getTotalLiquidity(), initialLiquidity);
        _verifyReserves(5 ether, 20 ether);
    }

    function test_swap_Bidirectional() public {
        token1.transfer(address(dex), 1 ether); // internally calculates 10.93* 9.15 ether  > 11*10 = 110 ether
        vm.expectEmit(true, true, true, true);
        emit Swapped(address(this), 0.07 ether, 0.85 ether);
        dex.swap(0.07 ether, 0.85 ether, address(this));

        assertEq(
            token1.balanceOf(address(this)),
            firstTokenBalance - 1 ether + 0.07 ether
        );
        assertEq(
            token2.balanceOf(address(this)),
            firstTokenBalance + 0.85 ether
        );
        assertEq(dex.getTotalLiquidity(), initialLiquidity);
        _verifyReserves(10.93 ether, 9.15 * 1 ether);
    }

    function test_revert_swap_ZeroOutput() public {
        vm.expectRevert("Output amount insufficient");
        dex.swap(0, 0, address(this));
    }

    function test_revert_swap_LiquidityInsufficient() public {
        vm.expectRevert("Liquidity insufficient");
        dex.swap(11 ether, 9 ether, address(this));
    }

    function test_CumulativePrices() public {
        // block.timestamp is at 0
        uint256 cumulativePrice1;
        uint256 cumulativePrice2;
        // get the current exchange rate after the first liquidity deposit
        (uint256 firstPrice1, uint256 firstPrice2) = _getMarginalRate();
        // cumulative prices will still be 0 because there is no past exchange event
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            0,
            0,
            firstPrice1,
            firstPrice2,
            0
        );

        // let some time elapse, so we will update the price if we force a sync
        vm.warp(1);
        // update the cumulative prices
        dex.sync();
        // calculate new prices and verify them against the contract
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            firstPrice1,
            firstPrice2,
            1
        );

        vm.warp(2);
        dex.sync();
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            firstPrice1,
            firstPrice2,
            1
        );
    }

    // ---------------------------------------- Helpers -----------------------------------------
    function _verifyReserves(uint256 reserve1, uint256 reserve2) internal {
        (uint112 r1, uint112 r2, ) = dex.getReserves();
        assertEq(r1, uint112(reserve1));
        assertEq(r2, uint112(reserve2));
    }

    function _getMarginalRate()
        internal
        returns (uint256 price1, uint256 price2)
    {
        (uint112 r1, uint112 r2, ) = dex.getReserves();
        price1 = r1 > 0 ? (uint(UQ112x112.encode(r2).uqdiv(r1))) : 0;
        price2 = r2 > 0 ? (uint(UQ112x112.encode(r1).uqdiv(r2))) : 0;
    }

    // calculate cumulative price change and verify it with the contract's values
    function _cumulativePrice(
        uint256 oldPrice1,
        uint256 oldPrice2,
        uint256 marginalRate1,
        uint256 marginalRate2,
        uint32 time
    ) internal returns (uint256 cumulativePrice1, uint256 cumulativePrice2) {
        (cumulativePrice1, cumulativePrice2) = (
            oldPrice1 + marginalRate1 * time,
            oldPrice2 + marginalRate2 * time
        );
        assertEq(dex.price1CumulativeLast(), cumulativePrice1);
        assertEq(dex.price2CumulativeLast(), cumulativePrice2);
    }

    // function (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
    // cumulativePrice1,
    // cumulativePrice2,
    //     uint256 cumulativePrice1,
    //     uint256 cumulativePrice2,
    //     uint32 blockTimestamp
    // ) internal {
    //     assertEq(dex.price1CumulativeLast(), cumulativePrice1);
    //     assertEq(dex.price2CumulativeLast(), cumulativePrice2);
    //     (, , uint32 blockTimestampLast) = dex.getReserves();
    //     assertEq(blockTimestampLast, blockTimestamp);
    // }
}
