// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IEscrow {
    function depositForAuction(
        address _nftAddress,
        uint256 _tokenId,
        address payable _seller,
        address _winner,
        uint256 _winningbid
    ) external payable;
}
/**
 * @title AsoEbiAution
 * @author Iam0TI
 * @dev A contract for creating and managing auctions for NFTs representing fabrics and ready-to-wear items.
 */

contract AsoEbiAution is Ownable(msg.sender), ReentrancyGuard, IERC721Receiver {
    // ===== ERROR ====
    error CreateAuction_InvalidOwner(address sender);
    error CreateAuction_InvalidSellingPrice();
    error CreateAuction_InvalidStartTime(uint256 startTime);
    error CreateAuction_InvalidEndTime(uint256 endTiem);
    error AuctionAlreadyListed();
    error AuctionAlreadyStart();
    error AuctionAlreadyEnded();
    error AuctionIsActive();
    error InvalidStartTime(uint256 startTime);
    error InvalidEndTImeTime(uint256 endTiem);
    error BidRefundFailed(uint256 amount);
    error WithDrawBid_TimeLock();
    error WithDrawBid_InvalidOwner();

    error CancelAuction_InvalidOwner(address sender);
    error CancelAuction_AuctionFinaliZed();
    error CancelAuction_AuctionDoesNotExist();
    error CheckAuction_InvalidOwner(address sender);
    error CheckAuction_AuctionAlreadyFinalized();
    error CheckAuction_AuctionDoesNotExist();
    error PlaceBid_AuctionAlreadyFinalized();
    error PlaceBid_InvaildAuction();
    error PlaceBid_DidNotOutBid();
    error InvalidBid();
    error NoBid();
    error InvalidWinningBid();

    // ======  Events =====

    event AuctionCreated(address indexed nftAddress, uint256 indexed tokenId, AuctionType auctionTye);
    event BidPlaced(address indexed nftAddress, uint256 indexed tokenId, address indexed bidder, uint256 bid);

    event BidWithdrawn(address indexed nftAddress, uint256 indexed tokenId, address indexed bidder, uint256 bid);

    // for when the highest bidder change
    event BidRefunded(address indexed nftAddress, uint256 indexed tokenId, address indexed bidder, uint256 bid);

    event UpdatedAuctionEndTime(address indexed nftAddress, uint256 indexed tokenId, uint256 endTime);

    event UpdatedAuctionStartTime(address indexed nftAddress, uint256 indexed tokenId, uint256 startTime);

    event UpdatedAuctionMinimumSellingPrice(
        address indexed nftAddress, uint256 indexed tokenId, uint256 minimumSellingPrice
    );

    // oldowner designer or fabric seller
    event AuctionFinalized(
        address oldOwner,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(address indexed nftAddress, uint256 indexed tokenId);
    event NFTReceived(address operator, address from, uint256 tokenId, bytes data);

    // ======  USER DEFINED VALUES =====

    enum AuctionType {
        Fabric,
        ReadyToWear
    }

    // info of an auction
    struct Auction {
        address owner;
        uint256 minimumBid;
        // the least selling price of an auction
        uint256 minimumSellingPrice;
        uint256 startTime;
        uint256 endTime;
        AuctionType auctionType;
        bool finalized;
        bool minimumbidIsMinSellingPrice;
    }

    //  Info about the person that placed a bid
    struct HighestBid {
        address payable bidder;
        uint256 bid;
        uint256 lastBidTime;
    }

    // ======  STATE VAriable =====

    // Nft Address -> token ID -> Auction Struct
    mapping(address => mapping(uint256 => Auction)) public auctions;

    // Nft Address -> Token ID -> HighestBId Struct
    mapping(address => mapping(uint256 => HighestBid)) public highestBids;
    address public escrowAddress;

    constructor(address _escrowAddress) {
        escrowAddress = _escrowAddress;
    }
    /**
     * @dev Creates a new auction for an NFT.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     * @param _minimumSellingPrice The minimum selling price for the auction.
     * @param _startTime The start time of the auction.
     * @param _endTime The end time of the auction.
     * @param _auctionType The type of auction (Fabric or ReadyToWear).
     * @param _minimumbidIsMinSellingPrice Flag to set minimum bid equal to minimum selling price.
     */

    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _minimumSellingPrice,
        uint256 _startTime,
        uint256 _endTime,
        AuctionType _auctionType,
        bool _minimumbidIsMinSellingPrice
    ) external payable {
        // check if nft has been listed
        require(auctions[_nftAddress][_tokenId].startTime == 0, AuctionAlreadyListed());

        require(msg.sender == IERC721(_nftAddress).ownerOf(_tokenId), CreateAuction_InvalidOwner(msg.sender));

        require(_minimumSellingPrice > 0, CreateAuction_InvalidSellingPrice());

        require(_startTime >= _getTime(), CreateAuction_InvalidStartTime(_startTime));

        require(_endTime >= _startTime + 10 minutes, CreateAuction_InvalidEndTime(_endTime));

        uint256 minBid = 0;
        if (_minimumbidIsMinSellingPrice) {
            minBid = _minimumSellingPrice;
        }

        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

        auctions[_nftAddress][_tokenId] = Auction({
            owner: msg.sender,
            minimumBid: minBid,
            minimumSellingPrice: _minimumSellingPrice,
            startTime: _startTime,
            endTime: _endTime,
            auctionType: _auctionType,
            finalized: false,
            minimumbidIsMinSellingPrice: _minimumbidIsMinSellingPrice
        });

        emit AuctionCreated(_nftAddress, _tokenId, _auctionType);
    }

    /**
     * @dev Cancels an existing auction.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     */
    function cancelAuction(address _nftAddress, uint256 _tokenId) external nonReentrant {
        Auction memory auction = auctions[_nftAddress][_tokenId];
        address auctionOwner = auction.owner;

        require(auctionOwner == msg.sender, CancelAuction_InvalidOwner(msg.sender));

        require(auction.finalized == false, CancelAuction_AuctionFinaliZed());

        require(auction.startTime > 0, CancelAuction_AuctionDoesNotExist());

        // refund  highest bidder
        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
        uint256 bid = highestBid.bid;
        address payable bidder = highestBid.bidder;

        // check if higest bidder exist
        if (highestBid.bidder != address(0)) {
            delete highestBids[_nftAddress][_tokenId];

            _refundHighestBidder(_nftAddress, _tokenId, bidder, bid);
        }

        delete auctions[_nftAddress][_tokenId];
        IERC721(_nftAddress).safeTransferFrom(address(this), auctionOwner, _tokenId);

        emit AuctionCancelled(_nftAddress, _tokenId);
    }

    /**
     * @dev Finalizes an auction and transfers the NFT to the winning bidder.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     */
    function finalizeAuction(address _nftAddress, uint256 _tokenId) external nonReentrant {
        Auction storage auction = auctions[_nftAddress][_tokenId];
        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];

        uint256 winningBid = highestBid.bid;
        address winner = highestBid.bidder;

        _checkAuction(_nftAddress, _tokenId);

        require(auction.endTime < _getTime(), AuctionIsActive());
        require(winner != address(0), NoBid());

        // if revert occurs here owner can do one of two thing (cancel auction or reduce the minimum selling price)
        require(winningBid >= auction.minimumSellingPrice, InvalidWinningBid());

        auction.finalized = true;

        delete highestBids[_nftAddress][_tokenId];

        // transfer the NFT to the escrow contract
        IERC721(_nftAddress).safeTransferFrom(address(this), escrowAddress, _tokenId);

        // call depositForAuction from the escrow contract, sending the winning bid
        IEscrow escrowContract = IEscrow(escrowAddress);
        escrowContract.depositForAuction{value: winningBid}(
            _nftAddress,
            _tokenId,
            payable(auction.owner), //seller address
            winner, // winner address
            winningBid // Winning bid amount
        );
        emit AuctionFinalized(auction.owner, _nftAddress, _tokenId, winner, winningBid);
    }

    /**
     * @dev Withdraws a bid from an ongoing auction.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     */
    function placeBid(address _nftAddress, uint256 _tokenId) external payable nonReentrant {
        require(msg.value > 0, InvalidBid());
        Auction storage auction = auctions[_nftAddress][_tokenId];
        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
        // check that auction has not been finalized
        require(auction.finalized == false, PlaceBid_AuctionAlreadyFinalized());
        require(_getTime() <= auction.endTime && _getTime() >= auction.startTime, PlaceBid_InvaildAuction());
        // for the first bidder
        if (auction.minimumbidIsMinSellingPrice) {
            require(msg.value >= auction.minimumBid, InvalidBid());
        }

        require(msg.value > highestBid.bid, PlaceBid_DidNotOutBid());
        address payable previousBidder = highestBid.bidder;
        uint256 prevBid = highestBid.bid;
        // set new bidder
        highestBid.bidder = payable(msg.sender);
        highestBid.bid = msg.value;

        if (previousBidder != address(0)) {
            _refundHighestBidder(_nftAddress, _tokenId, previousBidder, prevBid);
        }

        emit BidPlaced(_nftAddress, _tokenId, msg.sender, msg.value);
    }
    /**
     * @dev Withdraws a bid from an ongoing auction.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     */

    function withdrawBid(address _nftAddress, uint256 _tokenId) external nonReentrant {
        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
        address payable highestBidder = highestBid.bidder;
        // check if highest bidder is the msg.sender
        require(highestBidder == msg.sender, WithDrawBid_InvalidOwner());

        uint256 _endTime = auctions[_nftAddress][_tokenId].endTime;

        // can only withdraw bid  6 hours after auction endtime has passed
        require(_getTime() > _endTime + 6 hours, WithDrawBid_TimeLock());

        uint256 bidAmount = highestBid.bid;

        delete highestBids[_nftAddress][_tokenId];

        // Refund the highest bidder
        _refundHighestBidder(_nftAddress, _tokenId, highestBidder, bidAmount);

        emit BidWithdrawn(_nftAddress, _tokenId, highestBidder, bidAmount);
    }

    /**
     * @dev Updates the minimum selling price of an ongoing auction.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     * @param _minimumSellingPrice The new minimum selling price.
     */
    function updateAuctionMinimumSellingPrice(address _nftAddress, uint256 _tokenId, uint256 _minimumSellingPrice)
        external
    {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        // Ensure that the auction has not ended
        require(block.timestamp < auction.endTime, "AuctionAlreadyEnded");

        _checkAuction(_nftAddress, _tokenId);
        auction.minimumSellingPrice = _minimumSellingPrice;
        emit UpdatedAuctionMinimumSellingPrice(_nftAddress, _tokenId, _minimumSellingPrice);
    }
    /**
     * @dev Updates the start time of an ongoing auction.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     * @param _startTime The new start time for the auction.
     */

    function updateAuctionStartTime(address _nftAddress, uint256 _tokenId, uint256 _startTime) external {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        _checkAuction(_nftAddress, _tokenId);

        require(auction.startTime > _getTime(), AuctionAlreadyStart());

        // new auction start time should be a least 10 mintues less than aution endtime
        require(_startTime + 10 minutes < auction.endTime, InvalidStartTime(_startTime));

        auction.startTime = _startTime;
        emit UpdatedAuctionStartTime(_nftAddress, _tokenId, _startTime);
    }

    /**
     * @dev Updates the end time of an ongoing auction.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     * @param _endTimestamp The new end time for the auction.
     */
    function updateAuctionEndTime(address _nftAddress, uint256 _tokenId, uint256 _endTimestamp) external {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        _checkAuction(_nftAddress, _tokenId);

        // xheck if auction has not ended
        // require(_getTime() < auction.endTime, AuctionAlreadyEnded());

        // Ensure that the auction has not ended
        require(block.timestamp < auction.endTime, "AuctionAlreadyEnded");

        require(auction.startTime < _endTimestamp, InvalidEndTImeTime(_endTimestamp));
        require(_endTimestamp > _getTime() + 10 minutes, InvalidEndTImeTime(_endTimestamp));

        auction.endTime = _endTimestamp;
        emit UpdatedAuctionEndTime(_nftAddress, _tokenId, _endTimestamp);
    }

    // ======  Owner's Function =====
    function updateEscrowAddress(address _escrowAddress) external onlyOwner {
        escrowAddress = _escrowAddress;
    }
    // ======  View Function =====
    /**
     * @dev Retrieves the information of an auction.
     * @param _nftAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT token.
     * @return _owner The owner of the auction.
     * @return minBid The minimum bid amount.
     * @return minimumSellingPrice The minimum selling price of the auction.
     * @return _startTime The start time of the auction.
     * @return _endTime The end time of the auction.
     * @return _auctionType The type of auction (Fabric or ReadyToWear).
     * @return _finalized The finalization status of the auction.
     * @return _minimumbidIsMinSellingPrice Flag to set minimum bid equal to minimum selling price.
     */

    function getAuction(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (
            address _owner,
            uint256 minBid,
            uint256 minimumSellingPrice,
            uint256 _startTime,
            uint256 _endTime,
            AuctionType _auctionType,
            bool _finalized,
            bool _minimumbidIsMinSellingPrice
        )
    {
        Auction memory auction = auctions[_nftAddress][_tokenId];
        return (
            auction.owner,
            auction.minimumBid,
            auction.minimumSellingPrice,
            auction.startTime,
            auction.endTime,
            auction.auctionType,
            auction.finalized,
            auction.minimumbidIsMinSellingPrice
        );
    }

    function getHighestBidder(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (address payable _bidder, uint256 _bid, uint256 _lastBidTime)
    {
        HighestBid memory highestBid = highestBids[_nftAddress][_tokenId];
        return (highestBid.bidder, highestBid.bid, highestBid.lastBidTime);
    }

    function _getTime() internal view returns (uint256) {
        return block.timestamp;
    }

    function _refundHighestBidder(
        address _nftAddress,
        uint256 _tokenId,
        address payable _currentHighestBidder,
        uint256 _currentHighestBid
    ) internal {
        (bool success,) = _currentHighestBidder.call{value: _currentHighestBid}("");
        require(success, BidRefundFailed(_currentHighestBid));

        emit BidRefunded(_nftAddress, _tokenId, _currentHighestBidder, _currentHighestBid);
    }

    function _checkAuction(address _nftAddress, uint256 _tokenId) internal view {
        Auction memory auction = auctions[_nftAddress][_tokenId];

        require(msg.sender == auction.owner, CheckAuction_InvalidOwner(msg.sender));

        // check that auction has not been finalized
        require(!auction.finalized, CheckAuction_AuctionAlreadyFinalized());

        require(auction.endTime > 0, CheckAuction_AuctionDoesNotExist());
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
