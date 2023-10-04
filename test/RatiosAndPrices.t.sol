// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";

// All tests for how the contract handles unbalanced ratios + for price calculations
abstract contract TestsRatiosAndPrices is BaseSetup {
    uint initialLiquidity = 10 ether;

    function setUp() public virtual override {
        BaseSetup.setUp();
        vm.warp(0); // reset block timestamp
        _initializeDex(dex, initialLiquidity, initialLiquidity, address(this));
    }
}

contract MinLiquidityTest is TestsRatiosAndPrices {
    SalatswapPair d1;
    SalatswapPair d2;

    function setUp() public override {
        BaseSetup.setUp();
        d1 = dex;
        d2 = new SalatswapPair(address(token1), address(token2));
    }

    function test_mint_UnbalancedRatioAtInit() public {
        // show how MIN_LIQUIDITY in theory prevents price manipulation at init
        // trying to manipulate the price by depositing ratio such that one token would be more expensive
        uint weakToken = 1001 wei;
        uint strongToken = 1 wei;
        token1.transfer(address(d1), weakToken);
        token2.transfer(address(d1), strongToken);
        // vm.expectRevert("Liquidity provided is too low");
        // d1.mint(address(this)); // does not succeed due to MIN_LIQUIDITY

        token1.transfer(address(d2), weakToken * weakToken); // a factor of MIN_LIQUIDITY more have to be deposited
        token2.transfer(address(d2), strongToken);
        d2.mint(address(this));
        assertEq(d2.getTotalLiquidity(), weakToken);
    }
}

contract UnbalancedRatiosTest is TestsRatiosAndPrices {
    event Minted(address indexed sender, uint256 deposit1, uint256 deposit2);

    function test_mint_DisincentivizeUnbalancedRatios() public {
        _verifyReserves(initialLiquidity, initialLiquidity);

        vm.startPrank(user1);
        token1.transfer(address(dex), 18 ether);
        token2.transfer(address(dex), 22 ether);

        vm.expectEmit(true, true, true, true);
        emit Minted(address(user1), 18 ether, 22 ether);
        dex.mint(address(user1));
        vm.stopPrank();

        assertEq(dex.getLiquidity(address(user1)), 18 ether); // we will only get 18 ether of liquidity
        _verifyReserves(28 ether, 32 ether);
        assertEq(dex.getTotalLiquidity(), 28 ether);
    }

    function test_burn_DifferentRatioAndUser() public {
        // same as above but with a different user to demonstrate how the liquidity is distributed in this case
        vm.startPrank(user1);
        token1.transfer(address(dex), 5 ether); // <=== here put in 5 ether worth of tokens
        token2.transfer(address(dex), 1 ether);
        dex.mint(address(user1)); // <=== mint 1 LP

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
        uint oldToken1FirstUser = 4000 ether - initialLiquidity;
        uint oldToken2FirstUser = 4000 ether - initialLiquidity;
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

    function test_burn_DifferentRatioSameUser() public {
        token1.transfer(address(dex), 5 ether); // <=== in total we have put in 15 ether worth of tokens
        token2.transfer(address(dex), 1 ether);
        dex.mint(address(this));
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
}
