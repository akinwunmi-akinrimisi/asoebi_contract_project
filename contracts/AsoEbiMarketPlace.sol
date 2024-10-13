// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AsoEbiMarketPlace is ERC721("AsoEbiMarketPlace", "AEMP"), Ownable(msg.sender), ReentrancyGuard {
    // ===== ERROR ====
    error  NotANewUser(address );
    error  NotVaildLister();
    error  NotListed(  );
    error OrderDoesNotExist();
    error OrderDoesExist();
    error  Alreadylisted( );
    error NotItemOwner();

    event ItemListed(
        address indexed seller,
        uint256 tokenId,
        uint256 quantity,
         ListingType listingType,
          uint256 pricePerItem
    
    );

    event ItemUpdated(address indexed  seller, uint256 tokenId, uint256 price,uint256 quantity);
    event ItemCanceled(address indexed seller, uint256 tokenId);
    event OrderCreated(
        address indexed buyer,
        uint256 tokenId,
        uint256 quantity,
        OrderType orderType

    );
    event OrderAccepted(
          address indexed buyer,
        uint256 tokenId,
        uint256 quantity,
        OrderType orderType
    );
    event OrderCanceled(address indexed buyer, uint256 tokenId);

    enum RoleType {
        NotRegitered,
        FabricSeller,
        Designer,
        Buyer
    }

    enum OrderType {
        NotType,
        Fabric,
        ReadyToWear
    } enum ListingType {
          NotType,
        Fabric,
        ReadyToWear
    }
    enum OrderStatus {
        NotOrdered,
        Pending,
        Accepted
    }

    struct User {
        string displayName;
        RoleType roleType;
        bool isRegistered;
    }

    struct Listing {
        uint256 quantity; // the amount of readytowears or farbic yards  avaliable for sale
        uint256 pricePerItem; // price per yard of fabric or price per ready to wear
        uint256 listingTime; 
        bool isListed;
        ListingType listingType;
        uint256 quantityLeft; // to know when item is soldout
    }

    struct Order {
        uint256 quantity;
        string shippingInfo; // weird should get a better way
        uint256 timeofOrder;
        OrderStatus orderStatus;
        OrderType orderType;
    }

IERC721 public nftAddress = IERC721(address(this));
    mapping(address => User) public users;
    // tokenid -> seller/designer -> Listing
    mapping(uint256 => mapping(address => Listing)) public listings;
    // tokenid -> buyer -> Order
    mapping(uint256 => mapping(address => Order)) public orders;

    modifier validLister {
        require(users[msg.sender].roleType == RoleType.FabricSeller || users[msg.sender].roleType == RoleType.Buyer , NotVaildLister()  );
        
        _;
    }



    modifier isListed( uint256 _tokenId, address _owner) {
        Listing memory listing = listings[_tokenId][_owner];
        require(listing.listingTime > 0, NotListed());
        _;
    }

    modifier notListed( uint256 _tokenId, address _owner) {     
        Listing memory listing = listings[_tokenId][_owner];
        require(listing.isListed == false, Alreadylisted());
        _;
    }                           

    modifier validListing( uint256 _tokenId, address _owner) {
      Listing memory listing = listings[_tokenId][_owner];
        require(listing.isListed == false, Alreadylisted());
        _isOwner( _tokenId, _owner);

      
        _;
    }

    modifier orderExist( uint256 _tokenId, address _buyer) {
        Order memory order 
        = orders[_tokenId][_buyer];
        require(order.quantity > 0 && order.orderStatus == OrderStatus.Pending, OrderDoesNotExist());
        _;
    }

    modifier orderNotExists( uint256 _tokenId, address _buyer) {
        Order memory order = orders[_tokenId][_buyer];
        require(order.quantity == 0 || order.timeofOrder == 0,OrderDoesExist());
        _;
    }

    function registerUser(string memory _displayName,RoleType _roleType) external {
        require(users[msg.sender].isRegistered == false, NotANewUser(msg.sender));
        users[msg.sender] = User({
           displayName : _displayName,
            roleType : _roleType,
            isRegistered : true
        });
    }
    function listItem(uint256 _tokenId, uint256 _quantity, uint256 _pricePerItem) external validLister validListing(_tokenId, msg.sender) {
        nftAddress.safeTransferFrom(msg.sender, address(this), _tokenId);
        ListingType listingType ;
        if (users[msg.sender].roleType == RoleType.FabricSeller ) {
            listingType = ListingType.Fabric;
            listings[_tokenId][msg.sender] = Listing(_quantity, _pricePerItem, _getTime(), true, listingType, _quantity);
        } else {
            listingType = ListingType.ReadyToWear;
                 listings[_tokenId][msg.sender] = Listing(_quantity, _pricePerItem, _getTime(), true, listingType, _quantity);
        }
        
        emit ItemListed(msg.sender, _tokenId, _quantity, listingType, _pricePerItem);
    }
    function updateListing() external {}
    function CancelListing() external {}
    function makeOrder() external {}
    
    function acceptOrder(uint256 _tokenId, address _buyer) external isListed(_tokenId, msg.sender) orderExist(_tokenId, _buyer) {
        Order storage order = orders[_tokenId][_buyer];
        order.orderStatus = OrderStatus.Accepted;
        Listing storage listing = listings[_tokenId][msg.sender];
        listing.quantityLeft -= order.quantity;
        // call escrow 
        emit OrderAccepted(_buyer, _tokenId, order.quantity, order.orderType);
    }

    function cancelOrder(uint256 _tokenId) external orderExist(_tokenId, msg.sender) {
       // return money 
       // add logic to if to return money
        delete orders[_tokenId][msg.sender];
        emit OrderCanceled(msg.sender, _tokenId);
    }
    function mint() external {}


    function _isOwner (uint _tokenId,address _owner) internal view {
        require(IERC721(address(this)).ownerOf(_tokenId) == _owner, NotItemOwner());
    }

     function _getTime() internal view  returns (uint256) {
        return block.timestamp;
    }
}
