
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20BlackPauser.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// HFUSDT
contract HFUSDT is ERC20BlackPauser {
    constructor () ERC20BlackPauser("HF USDT", "HFU"){
    }
    function mint(address account, uint256 amount)public onlyOwner{
        _mint(account, amount);
    }
}

 