// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC721 is ERC721 {
    constructor(string memory name, string memory _symbol) ERC721(name, _symbol) {}

    function mint(uint256 tokenId) public {
        _safeMint(msg.sender, tokenId);
    }
}
