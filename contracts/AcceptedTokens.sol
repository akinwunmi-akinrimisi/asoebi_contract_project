// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AcceptedTokens is Ownable(msg.sender) {
    // ======  ERRORS =====
    error ZeroAddress_AcceptedToken();
    error TokenAlreadyAdded(address tokenAddress);
    error TokenDoesNotExist(address tokenAddress);

    // ===== EVENTS =====
    event TokenAdded(address indexed tokenaddress);
    event TokenRemoved(address indexed tokenaddress);

    // ERC20 TOken => bool
    mapping(address => bool) public isAcceptable;

    function add(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), ZeroAddress_AcceptedToken());
        require(!isAcceptable[tokenAddress], TokenAlreadyAdded(tokenAddress));
        isAcceptable[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }

    function remove(address tokenAddress) external onlyOwner {
        require(isAcceptable[tokenAddress], TokenDoesNotExist(tokenAddress));
        isAcceptable[tokenAddress] = false;
        emit TokenRemoved(tokenAddress);
    }
}
