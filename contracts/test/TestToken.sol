// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
    constructor() ERC20("TestToken", "TEST", 18) {
        _mint(msg.sender, 10_000_000e18);
    }

    function mint(address to, uint amount) external onlyOwner {
        _mint(to, amount);
    }
}
