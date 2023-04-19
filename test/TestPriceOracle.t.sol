// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {TestsRatiosAndPrices} from "./RatiosAndPrices.t.sol";
import {UQ112x112} from "src/libraries/UQ112x112.sol";
import {console} from "./utils/Console.sol";

// Test the price oracle
contract PriceOracleTest is TestsRatiosAndPrices {
    using UQ112x112 for uint224;

    uint[] internal _pricePoints; // holds prices at time points t3, t5, t7, t8

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

    function test_TradeWithCurrentPrice() public {
        // we get a wrong price here -- this should be a price of 1 each at the start
        (uint256 priceToken2, uint256 priceToken1) = _getMarginalRate();
        uint out = 2 ether;
        uint price = out * priceToken2;
        token1.transfer(address(dex), out);
        // dex.swap(0, price, address(this));
    }

    function test_GetAveragePrice() public {
        // get the average price of token 1

        test_CumulativePricesAfterPriceChange();

        // to do so, take the difference in cumulative prices at to points in time and divide by the time between them
        uint256 averagePricet5t3 = (_pricePoints[1] - _pricePoints[0]) / 2;
        uint256 averagePricet7t5 = (_pricePoints[2] - _pricePoints[1]) / 2;
        uint256 averagePricet8t7 = (_pricePoints[3] - _pricePoints[2]) / 2;

        uint256 averagePrice = (averagePricet5t3 +
            averagePricet7t5 +
            averagePricet8t7) / 3;
    }

    function test_CumulativePricesAfterPriceChange() public {
        uint256 cumulativePrice1;
        uint256 cumulativePrice2;
        (uint256 firstPrice1, uint256 firstPrice2) = _getMarginalRate();
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            0,
            0,
            firstPrice1,
            firstPrice2,
            0
        );

        // ----------------- Trading -----------------
        // let transaction be in a new block
        vm.warp(3);
        token1.transfer(address(dex), 1 ether);
        // within swap, another price point based on the old reserves is added
        dex.swap(0, 0.9 ether, address(this));
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            firstPrice1,
            firstPrice2,
            3
        );
        _pricePoints.push(cumulativePrice1);

        // get the price with the new reserves
        (uint256 secondPrice1, uint256 secondPrice2) = _getMarginalRate();
        // let some time elapse, so we will update the price if we force a sync
        vm.warp(4);
        dex.sync();
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            secondPrice1,
            secondPrice2,
            1
        );

        // ----------------- Minting -----------------
        vm.warp(5);
        token1.transfer(address(dex), 5 ether);
        token2.transfer(address(dex), 5 ether);
        dex.mint();
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            secondPrice1,
            secondPrice2,
            1
        );
        _pricePoints.push(cumulativePrice1);

        (uint256 thirdPrice1, uint256 thirdPrice2) = _getMarginalRate();
        vm.warp(6);
        dex.sync();
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            thirdPrice1,
            thirdPrice2,
            1
        );

        // ----------------- Burning -----------------
        vm.warp(7);
        dex.transfer(address(dex), 10 ether);
        dex.burn(address(this));
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            thirdPrice1,
            thirdPrice2,
            1
        );
        _pricePoints.push(cumulativePrice1);

        (uint256 fourthPrice1, uint256 fourthPrice2) = _getMarginalRate();
        vm.warp(8);
        dex.sync();
        (cumulativePrice1, cumulativePrice2) = _cumulativePrice(
            cumulativePrice1,
            cumulativePrice2,
            fourthPrice1,
            fourthPrice2,
            1
        );
        _pricePoints.push(cumulativePrice1);
    }

    // ---------------------------------------- Helpers -----------------------------------------
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
}
