// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./BaseSetup.t.sol";
import {console} from "./utils/Console.sol";

// Test the basic functionality of the Pair contract here (excluding price oracle tests)
contract SalatswapPairTest is BaseSetup {
    uint initialLiquidity = 10 ether;
    uint firstTokenBalance = 4000 ether - initialLiquidity;

    event Minted(address indexed sender, uint256 deposit1, uint256 deposit2);
    event Burned(address indexed to, uint256 amount1, uint256 amount2);
    event Swapped(address indexed to, uint256 amount1, uint256 amount2);
    event Synced(uint112 reserve1, uint112 reserve2);

    function setUp() public override {
        BaseSetup.setUp();
        _initializeDex(dex, initialLiquidity, initialLiquidity, address(this));
    }

    function test_mint_MintInitialAndMinimumLiquidity() public {
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

    function test_mint_MintAfterInitialLiquidity() public {
        vm.startPrank(user1);
        token1.transfer(address(dex), 20 ether);
        token2.transfer(address(dex), 20 ether);
        vm.expectEmit(true, true, true, true);
        emit Minted(address(user1), 20 ether, 20 ether);
        dex.mint(address(user1));
        vm.stopPrank();

        assertEq(dex.getLiquidity(address(user1)), 20 ether);
        _verifyReserves(30 ether, 30 ether);
        assertEq(dex.getTotalLiquidity(), 30 ether);
        assertEq(token1.balanceOf(address(user1)), 1000 ether - 20 ether);
        assertEq(token2.balanceOf(address(user1)), 1000 ether - 20 ether);
    }

    function test_revert_mint_Underflow() public {
        // with underflow if L < MIN_LIQUIDITY
        // SalatswapPair d = new SalatswapPair(address(token1), address(token2));
        // token1.transfer(address(d), 100 wei);
        // token2.transfer(address(d), 100 wei);
        // vm.expectRevert("");
        // d.mint(address(this));
    }

    function test_revert_mint_InsufficientLiquidity() public {
        //if L = MIN_LIQUIDITY
        SalatswapPair d2 = new SalatswapPair(address(token1), address(token2));
        token1.transfer(address(d2), 1000 wei);
        token2.transfer(address(d2), 1000 wei);
        vm.expectRevert("Liquidity provided is too low");
        d2.mint(address(this));
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

    function test_burn_BurnAll() public {
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

    function test_revert_burn_BurnZero() public {
        vm.expectRevert("No liquidity to be burnt");
        dex.burn(address(this));
    }

    function test_revert_burn_BurnBeforeMinted() public {
        SalatswapPair d = new SalatswapPair(address(token1), address(token2));
        vm.expectRevert("No liquidity to be burnt");
        d.burn(address(this));
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

    function test_sync() public {
        token1.transfer(address(dex), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit Synced(11 ether, 9.1 ether);
        dex.swap(0, 0.9 ether, address(this));
        _verifyReserves(11 ether, 9.1 ether);

        dex.transfer(address(dex), 3 ether);
        vm.expectEmit(true, true, true, true);
        emit Synced(7.7 ether, 6.37 ether);
        dex.burn(address(this));
    }

    function test_ReserveStorage() public {
        // bytes32 storage_token1 = vm.load(address(dex), bytes32(uint256(6)));
        // bytes32 storage_token2 = vm.load(address(dex), bytes32(uint256(7)));
        bytes32 storage_Reserves = vm.load(address(dex), bytes32(uint256(8)));
        assertEq(
            storage_Reserves,
            hex"000000010000000000008ac7230489e800000000000000008ac7230489e80000"
            // timestamp, reserve2, reserve1 (little endian format)
        );
    }
}
