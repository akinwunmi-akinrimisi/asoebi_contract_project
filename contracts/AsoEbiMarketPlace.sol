// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IEscrow {
    function depositForOrder(address seller, uint256 amount, address buyer, uint256 newOrderId) external payable;
}

/**
 * @title AsoEbiMarketPlace
 * @author Iam0TI
 * @dev A marketplace for listing and ordering NFTs representing fabrics and ready-to-wear items.
 */
contract AsoEbiMarketPlace is
    ERC721("AsoEbiMarketPlace", "AEMP"),
    Ownable(msg.sender),
    ReentrancyGuard,
    ERC721URIStorage
{
    uint256 public nextTokenId; // Counter to track tokenIds

    // ===== ERROR ====
    error NotANewUser(address);
    error NotVaildLister();
    error NotListed();
    error OrderDoesNotExist();
    error OrderDoesExist();
    error Alreadylisted();
    error NotItemOwner();
    error InvalidValue();
    error InvalidQuantity();
    error InvalidPrice();
    error InsufficientFunds();
    error NotListingOwner();
    error NotVaildBuyer();
    error WithdrawFailed();

    event ItemListed(
        address indexed seller, uint256 tokenId, uint256 quantity, ListingType listingType, uint256 pricePerItem
    );

    event ItemUpdated(address indexed seller, uint256 tokenId, uint256 price, uint256 quantity);
    event ItemCanceled(address indexed seller, uint256 tokenId);
    event OrderCreated(address indexed buyer, uint256 tokenId, uint256 quantity, OrderType orderType);
    event OrderAccepted(address indexed buyer, uint256 tokenId, uint256 quantity, OrderType orderType);
    event OrderCanceled(address indexed buyer, uint256 tokenId);
    event UserRegister(address indexed user, string  displayName,RoleType roleType);

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
    }
    enum ListingType {
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
        // uint256 quantity; // the amount of readytowears or farbic yards  avaliable for sale
        address owner; // seller/designer
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
        uint256 totalPrice;
    }

    IERC721 public nftAddress = IERC721(address(this));
    address public escrowAddress;
    uint256 public acceptedOrderCount;
    mapping(address => User) public users;
    // tokenid  -> Listing
    mapping(uint256 => Listing) public listings;
    // tokenid -> buyer -> Order
    mapping(uint256 => mapping(address => Order)) public orders;

    modifier validLister() {
        require(
            users[msg.sender].roleType == RoleType.FabricSeller || users[msg.sender].roleType == RoleType.Designer,
            NotVaildLister()
        );

        _;
    }

    modifier validBuyer() {
        require(users[msg.sender].roleType == RoleType.Buyer, NotVaildBuyer());

        _;
    }

    modifier isListed(uint256 _tokenId, address _owner) {
        Listing memory listing = listings[_tokenId];
        require(listing.listingTime > 0, NotListed());
        require(listing.owner == _owner, NotListingOwner());
        _;
    }

    modifier validListing(uint256 _tokenId, address _owner) {
        Listing memory listing = listings[_tokenId];
        require(listing.isListed == false, Alreadylisted());
        _isOwner(_tokenId, _owner);

        _;
    }

    modifier orderExist(uint256 _tokenId, address _buyer) {
        Order memory order = orders[_tokenId][_buyer];
        require(order.quantity > 0 && order.orderStatus == OrderStatus.Pending, OrderDoesNotExist());
        _;
    }

    modifier orderNotExists(uint256 _tokenId, address _buyer) {
        Order memory order = orders[_tokenId][_buyer];
        require(order.quantity == 0 || order.timeofOrder == 0, OrderDoesExist());
        _;
    }

    constructor(address _escrowAddress) {
        escrowAddress = _escrowAddress;
    }

    /**
     * @notice Registers a new user with a display name and role type.
     * @param _displayName The display name of the user.
     * @param _roleType The role type of the user (FabricSeller, Designer, Buyer).
     * @dev Emits an error if the user is already registered.
     */
    function registerUser(string memory _displayName, RoleType _roleType) external {
        require(users[msg.sender].isRegistered == false, NotANewUser(msg.sender));
        users[msg.sender] = User({displayName: _displayName, roleType: _roleType, isRegistered: true});
    }
    /**
     * @notice Lists an item for sale on the marketplace.
     * @param _tokenId The ID of the token to be listed.
     * @param _quantity The quantity of the item to be listed.
     * @param _pricePerItem The price per item.
     * @dev The caller must be a valid lister and the item must not already be listed.
     * Emits an {ItemListed} event.
     */

    function listItem(uint256 _tokenId, uint256 _quantity, uint256 _pricePerItem)
        external
        validLister
        validListing(_tokenId, msg.sender)
    {
        require(_pricePerItem > 0, InvalidPrice());
        require(_quantity > 0, InvalidQuantity());

        nftAddress.safeTransferFrom(msg.sender, address(this), _tokenId);
        ListingType listingType;
        if (users[msg.sender].roleType == RoleType.FabricSeller) {
            listingType = ListingType.Fabric;
            listings[_tokenId] = Listing(msg.sender, _pricePerItem, _getTime(), true, listingType, _quantity);
        } else {
            listingType = ListingType.ReadyToWear;
            listings[_tokenId] = Listing(msg.sender, _pricePerItem, _getTime(), true, listingType, _quantity);
        }

        emit ItemListed(msg.sender, _tokenId, _quantity, listingType, _pricePerItem);
    }
    /**
     * @notice Updates the listing of an item.
     * @param _tokenId The ID of the token to be updated.
     * @param _pricePerItem The new price per item.
     * @param _quantity The additional quantity to be added to the listing.
     * @dev The caller must be a valid lister and the item must be listed.
     * Emits an {ItemUpdated} event.
     */

    function updateListing(uint256 _tokenId, uint256 _pricePerItem, uint256 _quantity)
        external
        validLister
        isListed(_tokenId, msg.sender)
    {
        require(_quantity > 0 || _pricePerItem > 0, InvalidValue());

        Listing storage listing = listings[_tokenId];
        listing.pricePerItem = _pricePerItem;
        listing.quantityLeft += _quantity;
        emit ItemUpdated(msg.sender, _tokenId, _pricePerItem, _quantity);
    }

    /**
     * @notice Cancels a listed item and returns it to the owner.
     * @param _tokenId The ID of the token to be canceled.
     * @dev The caller must be a valid lister and the item must be listed.
     * Emits an {ItemCanceled} event.
     */
    function cancelListing(uint256 _tokenId) external validLister isListed(_tokenId, msg.sender) {
        delete ( listings[_tokenId]);
        nftAddress.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit ItemCanceled(msg.sender, _tokenId);
    }

    /**
     * @notice Places an order for a listed item.
     * @param _tokenId The ID of the token to order.
     * @param _quantity The quantity of the item to order.
     * @param _shippingInfo The shipping information for the order.
     * @dev The caller must be a valid buyer and the order must not already exist.
     * Emits an {OrderCreated} event.
     */
    function makeOrder(uint256 _tokenId, uint256 _quantity, string memory _shippingInfo)
        external
        payable
        validBuyer
        orderNotExists(_tokenId, msg.sender)
    {
        require(_quantity > 0, InvalidQuantity());

        _checkListing(_tokenId, _quantity);

        Listing storage listing = listings[_tokenId];

        require(listing.quantityLeft >= _quantity, InvalidQuantity());

        uint256 totalPrice = listing.pricePerItem * _quantity;

        require(msg.value >= totalPrice, InsufficientFunds());

        listing.quantityLeft -= _quantity;

        OrderType orderType;
        if (listing.listingType == ListingType.Fabric) {
            orderType = OrderType.Fabric;
        } else {
            orderType = OrderType.ReadyToWear;
        }

        orders[_tokenId][msg.sender] = Order({
            quantity: _quantity,
            shippingInfo: _shippingInfo,
            timeofOrder: block.timestamp,
            orderStatus: OrderStatus.Pending,
            orderType: orderType,
            totalPrice: msg.value
        });

        emit OrderCreated(msg.sender, _tokenId, _quantity, OrderType.Fabric);
    }
    /**
     * @notice Accepts an order for a listed item.
     * @param _tokenId The ID of the token for which the order is accepted.
     * @param _buyer The address of the buyer who placed the order.
     * @dev The caller must be the owner of the listed item and the order must exist.
     * Emits an {OrderAccepted} event.
     */

    function acceptOrder(uint256 _tokenId, address _buyer)
        external
        nonReentrant
        isListed(_tokenId, msg.sender)
        orderExist(_tokenId, _buyer)
    {
        Order storage order = orders[_tokenId][_buyer];
        order.orderStatus = OrderStatus.Accepted;
        Listing storage listing = listings[_tokenId];
        listing.quantityLeft -= order.quantity;
        // call escrow
        acceptedOrderCount = acceptedOrderCount + 1;
        IEscrow escrowContract = IEscrow(escrowAddress);

        escrowContract.depositForOrder{value: order.totalPrice}(
            msg.sender, order.totalPrice, _buyer, acceptedOrderCount
        );

        emit OrderAccepted(_buyer, _tokenId, order.quantity, order.orderType);
    }
    /**
     * @notice Cancels an order and refunds the buyer.
     * @param _tokenId The ID of the token for which the order is canceled.
     * @dev The caller must be the buyer who placed the order and the order must exist.
     * Emits an {OrderCanceled} event.
     */

    function cancelOrder(uint256 _tokenId) external nonReentrant orderExist(_tokenId, msg.sender) {
        Order memory order = orders[_tokenId][msg.sender];
        uint256 amount = order.totalPrice;
        delete orders[_tokenId][msg.sender];
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, WithdrawFailed());

        emit OrderCanceled(msg.sender, _tokenId);
    }

    function mint(string memory uri) external validLister {
        nextTokenId++;
        _safeMint(msg.sender, nextTokenId);
        _setTokenURI(nextTokenId, uri);
    }

    // ======  Owner's Function =====
    /**
     * @notice Updates the escrow address.
     * @param _escrowAddress The new escrow address.
     * @dev Only the contract owner can call this function.
     */
    function updateEscrowAddress(address _escrowAddress) external onlyOwner {
        escrowAddress = _escrowAddress;
    }

    function _isOwner(uint256 _tokenId, address _owner) internal view {
        require(IERC721(address(this)).ownerOf(_tokenId) == _owner, NotItemOwner());
    }

    function _getTime() internal view returns (uint256) {
        return block.timestamp;
    }

    function _checkListing(uint256 _tokenId, uint256 _quantity) internal view {
        Listing memory listing = listings[_tokenId];
        require(listing.listingTime > 0, NotListed());
        require(listing.owner != address(0), NotListed());
        require(listing.quantityLeft >= _quantity, InvalidQuantity());
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
        