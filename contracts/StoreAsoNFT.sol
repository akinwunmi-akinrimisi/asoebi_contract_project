// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AsoEbiNFT {
    struct Design {
        string ipfsCID;
        address designer;
        uint price;
    }

    address public owner;
    mapping(uint => Design) public designs;

    event DesignCreated(uint indexed designId, address indexed designer, string ipfsCID, uint price);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender; 
    }

    function createDesign(uint designId, string memory ipfsCID, uint price) public onlyOwner {
        require(price > 0, "Price must be greater than zero");
        require(bytes(ipfsCID).length > 0, "IPFS hash is required");

        designs[designId] = Design(ipfsCID, msg.sender, price);
        emit DesignCreated(designId, msg.sender, ipfsCID, price);
    }

    function getDesign(uint designId) public view returns (string memory, address, uint) {
        Design memory design = designs[designId];
        require(design.designer != address(0), "Design does not exist");
        return (design.ipfsCID, design.designer, design.price);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        owner = newOwner;
    }
}
