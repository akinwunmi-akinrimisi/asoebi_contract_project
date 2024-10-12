// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.27;


/**
 * @title Escrow
 * @author Damboy0
 * @dev Handles escrow for orders and auctions.
 */
contract Escrow {
    address public owner;
    uint public feePercentage;

    // Mapping of escrowed funds for orders
    mapping (address => mapping (address => uint)) public orderEscrow;

    // Mapping of escrowed funds for auctions
    mapping (address => mapping (address => uint)) public auctionEscrow;

    // Mapping of escrowed NFTs for auctions
    mapping (address => mapping (address => address[])) public nftEscrow;

    // Mapping of escrowed amounts for auctions
    mapping (address => mapping (address => uint[])) public amountEscrow;

    // Mapping of escrowed token addresses for auctions
    mapping (address => mapping (address => address[])) public tokenEscrow;

    // ===== EVENTS =====
    event DepositForOrder(address indexed buyer, address indexed seller, uint amount);
    event DepositForAuction(address indexed buyer, address indexed seller, address nft, address token, uint amount);
    event ReleaseForOrder(address indexed buyer, address indexed seller, uint amount);
    event ReleaseForAuction(address indexed buyer, address indexed seller, address nft, address token, uint amount);

    /**
     * @dev Constructor.
     * @param _feePercentage The fee percentage.
     */
    constructor (uint _feePercentage) {
        owner = msg.sender;
        feePercentage = _feePercentage;
    }

    /**
     * @dev Deposit funds for an order.
     */
    function depositForOrder(address seller, uint amount) external payable {
        require(msg.value == amount, "Escrow: value mismatch");

        orderEscrow[msg.sender][seller] += amount;

        emit DepositForOrder(msg.sender, seller, amount);
    }

    /**
     * @dev Deposit funds and NFT for an auction.
     */
    function depositForAuction(address seller, address nft, address token, uint amount) external payable {
        require(msg.value == amount, "Escrow: value mismatch");

        auctionEscrow[msg.sender][seller] += amount;
        nftEscrow[msg.sender][seller].push(nft);
        amountEscrow[msg.sender][seller].push(amount);
        tokenEscrow[msg.sender][seller].push(token);

        emit DepositForAuction(msg.sender, seller, nft, token, amount);
    }

    /**
     * @dev Release funds for an order.
     */
    function releaseForOrder(address buyer, address seller) external {
        uint amount = orderEscrow[buyer][seller];

        require(amount > 0, "Escrow: no funds to release");

        orderEscrow[buyer][seller] = 0;

        uint fee = (amount * feePercentage) / 100;
        uint amountToRelease = amount - fee;

        (bool success, ) = payable(seller).call{value: amountToRelease}("");
        require(success, "Escrow: failed to release funds");

        (bool success2, ) = payable(owner).call{value: fee}("");
        require(success2, "Escrow: failed to release fee");

        emit ReleaseForOrder(buyer, seller, amount);
    }

    /**
     * @dev Release funds and NFT for an auction.
     */
    function releaseForAuction(address buyer, address seller) external {
        uint amount = auctionEscrow[buyer][seller];

        require(amount > 0, "Escrow: no funds to release");

        auctionEscrow[buyer][seller] = 0;

        uint fee = (amount * feePercentage) / 100;
        uint amountToRelease = amount - fee;

        (bool success, ) = payable(seller).call{value: amountToRelease}("");
        require(success, "Escrow: failed to release funds");

        (bool success2, ) = payable(owner).call{value: fee}("");
        require(success2, "Escrow: failed to release fee");

        address[] memory nfts = nftEscrow[buyer][seller];
        for (uint i = 0; i < nfts.length; i++) {
            // Transfer the NFT to the seller
            // Implement the logic to transfer the NFT
        }

        emit ReleaseForAuction(buyer, seller, nfts[0], tokenEscrow[buyer][seller][0], amount);
    }
}
