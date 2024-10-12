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
contract Escrow is ReentrancyGuard,IERC721Receiver {
    address public owner;
    uint256 public feePercentage;
    address public auctionContract;

    struct FinalizedAuction {
        address payable seller; // can be fabric seller or designer
        address winner;
        uint256 winningbid;
        bool isReceived;
    }

    // Mapping of escrowed funds for orders
    mapping(address => mapping(address => uint256)) public orderEscrow;

    // // Mapping of escrowed funds for auctions
    // mapping (address => mapping (address => uint)) public auctionEscrow;

    // Mapping of escrowed NFTs for auctions
    mapping(address => mapping(address => address[])) public nftEscrow;

    // Mapping of escrowed amounts for auctions
    mapping(address => mapping(uint256 => FinalizedAuction)) public auctionEscrow;

    // Mapping of escrowed token addresses for auctions
    mapping(address => mapping(address => address[])) public tokenEscrow;

    // ===== EVENTS =====
    event DepositForOrder(address indexed buyer, address indexed seller, uint256 amount);
    event DepositForAuction(
        address indexed nftAddress, uint256 indexed tokenId, address seller, address indexed winner, uint256 winningBid
    );
    event ReleaseForOrder(address indexed buyer, address indexed seller, uint256 amount);
    event ReleaseForAuction(address indexed nftAddress, uint256 indexed tokenId, address seller);
    event NFTReceived(address operator, address from, uint256 tokenId, bytes data);


    modifier onlyOwner {
        require(msg.sender == owner, "Escrow: not owner");
        _;
    }

    /**
     * @dev Constructor.
     * @param _feePercentage The fee percentage.
     */
    constructor(uint256 _feePercentage) {
        owner = msg.sender;
        feePercentage = _feePercentage;
    }

    /**
     * @dev Deposit funds for an order.
     */
    function depositForOrder(address seller, uint256 amount) external payable {
        require(msg.value == amount, "Escrow: value mismatch");

        orderEscrow[msg.sender][seller] += amount;

        emit DepositForOrder(msg.sender, seller, amount);
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
    function releaseForOrder(address buyer, address seller) external {
        uint256 amount = orderEscrow[buyer][seller];

        require(amount > 0, "Escrow: no funds to release");

        orderEscrow[buyer][seller] = 0;

        uint256 fee = (amount * feePercentage) / 100;
        uint256 amountToRelease = amount - fee;

        (bool success,) = payable(seller).call{value: amountToRelease}("");
        require(success, "Escrow: failed to release funds");

        (bool success2,) = payable(owner).call{value: fee}("");
        require(success2, "Escrow: failed to release fee");

        emit ReleaseForOrder(buyer, seller, amount);
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

        uint256 fee = (finalizedAuction.winningbid * feePercentage) / 100;
        uint256 amountToRelease = finalizedAuction.winningbid - fee;
        (bool success,) = finalizedAuction.seller.call{value: amountToRelease}("");

        require(success, "Escrow: failed to release fund");

        (bool success2,) = payable(owner).call{value: fee}("");
        require(success2, "Escrow: failed to release fee");

        emit ReleaseForAuction(_nftAddress, _tokenId, finalizedAuction.seller);
    }



    function updateAuctionContract(address _auctionContract) onlyOwner external{
            auctionContract = _auctionContract;
    }

    // Function to handle receiving an ERC-721 token
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        emit NFTReceived(operator, from, tokenId, data);
        return this.onERC721Received.selector;
    }
}
