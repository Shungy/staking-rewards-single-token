pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "openzeppelin/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
    constructor() ERC20("TestToken", "TEST", 18) {
        _mint(msg.sender, 10_000_000e18);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
