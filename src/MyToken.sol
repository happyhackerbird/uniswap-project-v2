// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "solmate/tokens/ERC20.sol";

contract MyToken is ERC20 {
    constructor(uint256 _supply) ERC20("LillyToken", "LT", 18) {
        _mint(msg.sender, _supply * 10 ** 18);
    }
}
