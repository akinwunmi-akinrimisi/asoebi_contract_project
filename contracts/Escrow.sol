// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.27;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Escrow
 * @author Damboy0
 * @dev Handles escrow for orders and auctions.
 */
contract Escrow is ReentrancyGuard, IERC721Receiver, Ownable(msg.sender) {
    address public feeRecipient; //change ownwers to feeRecipient
    uint256 public feePercentage;
    address public auctionContract;
    address public marketPlaceContract;

    struct FinalizedAuction {
        address payable seller; // can be fabric seller or designer
        address winner;
        uint256 winningbid;
        bool isReceived;
    }

    struct FinalizedOrder {
        address payable seller;
        address buyer;
        uint256 amount;
        bool isReceived;
    }

    // Mapping of escrowed funds for orders
    mapping(address => mapping(address => mapping(uint256 => FinalizedOrder))) public orderEscrow;

    // Mapping of escrowed amounts for auctions
    mapping(address => mapping(uint256 => FinalizedAuction)) public auctionEscrow;

    // ===== EVENTS =====
    event DepositForOrder(address indexed buyer, address indexed seller, uint256 amount);
    event DepositForAuction(
        address indexed nftAddress, uint256 indexed tokenId, address seller, address indexed winner, uint256 winningBid
    );
    event ReleaseForOrder(address indexed buyer, address indexed seller, uint256 amount);
    event ReleaseForAuction(address indexed nftAddress, uint256 indexed tokenId, address seller);
    event NFTReceived(address operator, address from, uint256 tokenId, bytes data);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event FeePercentageUpdated(uint256 newFeePercentage);

    // ===== CONSTRUCTOR =====
    /**
     * @dev Constructor.
     * @param _feePercentage The fee percentage.
     */
    constructor(uint256 _feePercentage, address _feeRecipient) {
        feeRecipient = _feeRecipient;
        // owner = msg.sender;
        feePercentage = _feePercentage;
    }

    /**
     * @dev Deposit funds for an order.
     */
    function depositForOrder(address seller, uint256 amount, address buyer, uint256 orderId) external payable {
        require(msg.value == amount, "Escrow: value mismatch");
        require( msg.sender == marketPlaceContract, "Escrow: invalid caller");

        orderEscrow[buyer][seller][orderId] = FinalizedOrder({
            seller: payable(seller),
            buyer: buyer,
            amount: amount,
            isReceived: false
        });


        emit DepositForOrder(buyer, seller, amount);
    }

    /**
     * @dev Deposit funds and NFT for an auction.
     */
    function depositForAuction(
        address _nftAddress,
        uint256 _tokenId,
        address payable _seller,
        address _winner,
        uint256 _winningbid
    ) external payable {
        require(IERC721(_nftAddress).ownerOf(_tokenId) == address(this), "Escrow: did not send nft");
        require(msg.value == _winningbid, "Escrow: value mismatch");
        require(msg.sender == auctionContract, "Escrow: did not use auction contract");

        auctionEscrow[_nftAddress][_tokenId] =
            FinalizedAuction({seller: _seller, winner: _winner, winningbid: _winningbid, isReceived: false});

        emit DepositForAuction(_nftAddress, _tokenId, _seller, _winner, _winningbid);
    }

    /**
     * @dev Release funds for an order.
     */
    function releaseForOrder(address buyer, address seller, uint256 orderId) external {
        FinalizedOrder storage order = orderEscrow[buyer][seller][orderId];
        require(msg.sender == order.buyer, "Escrow: not buyer");
        require(order.amount > 0, "Escrow: no funds to release");
        require(order.isReceived == false, "Escrow: order already released");

        order.isReceived = true;

        uint256 fee = (order.amount * feePercentage) / 1000;
        uint256 amountToRelease = order.amount - fee;

        (bool success,) = order.seller.call{value: amountToRelease}("");
        require(success, "Escrow: failed to release funds");

        (bool success2,) = payable(feeRecipient).call{value: fee}("");
        require(success2, "Escrow: failed to release fee");

        emit ReleaseForOrder(buyer, seller, order.amount);
    }

    /**
     * @dev Release funds and NFT for an auction.
     */
    function releaseForAuction(address _nftAddress, uint256 _tokenId) external nonReentrant {
        FinalizedAuction storage finalizedAuction = auctionEscrow[_nftAddress][_tokenId];

        require(msg.sender == finalizedAuction.winner, "Escrow: not winner");

        require(finalizedAuction.isReceived == false, "Escrow: auction Received");

        finalizedAuction.isReceived = true;

        IERC721(_nftAddress).safeTransferFrom(address(this), finalizedAuction.winner, _tokenId);

        uint256 fee = (finalizedAuction.winningbid * feePercentage) / 1000;
        uint256 amountToRelease = finalizedAuction.winningbid - fee;
        (bool success,) = finalizedAuction.seller.call{value: amountToRelease}("");

        require(success, "Escrow: failed to release fund");

        (bool success2,) = payable(feeRecipient).call{value: fee}("");
        require(success2, "Escrow: failed to release fee");

        emit ReleaseForAuction(_nftAddress, _tokenId, finalizedAuction.seller);
    }

    /**
     * @dev Owner can update the fee recipient.
     * @param _newFeeRecipient The new fee recipient address.
     */
    function updateFeeRecipient(address _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0), "Escrow: invalid address");
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientUpdated(_newFeeRecipient);
    }

    /**
     * @dev Owner can update the fee percentage.
     * @param _newFeePercentage The new fee percentage.
     */
    function updateFeePercentage(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 100, "Escrow: invalid fee percentage");
        feePercentage = _newFeePercentage;
        emit FeePercentageUpdated(_newFeePercentage);
    }

    function updateAuctionContract(address _auctionContract) external onlyOwner {
        auctionContract = _auctionContract;
    }

    function updateMarketPlaceContract(address _marketPlaceContract) external onlyOwner {
        marketPlaceContract = _marketPlaceContract;
    }

    // Function to handle receiving an ERC-721 token
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        emit NFTReceived(operator, from, tokenId, data);
        return this.onERC721Received.selector;
    }
}
