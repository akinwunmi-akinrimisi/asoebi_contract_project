// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

/**
 * @title OwnerShip
 * @author IAM0TI
 * @dev This contract manages ownership transfer functionality.
 */
contract OwnerShip {
    // ======  ERRORS =====
    error NotOwner(address caller);
    error NotNewOwner(address caller);
    error AddressZero_OwnerShip();

    // ======  Events =====
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProposedNewOwner(address indexed previousOwner, address indexed newOwner);

    address public owner;
    address public newOwner;

    /**
     * @dev Sets the contract deployer as the initial owner.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Modifier to restrict access to only the current owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner(msg.sender));
        _;
    }

    /**
     * @dev Modifier to restrict access to only the new owner.
     */
    modifier onlyNewOwner() {
        require(msg.sender == newOwner, NotNewOwner(msg.sender));
        _;
    }

    /**
     * @dev Allows the current owner to propose a new owner.
     * @param _newOwner The address of the proposed new owner.
     */
    function proposeNewOwner(address _newOwner) internal onlyOwner {
        require(_newOwner != address(0), AddressZero_OwnerShip());
        newOwner = _newOwner;
        emit ProposedNewOwner(msg.sender, _newOwner);
    }

    /**
     * @dev Allows the new owner to claim ownership.
     */
    function claimOwnerShip() internal onlyNewOwner {
        require(newOwner != address(0), AddressZero_OwnerShip());
        address prevOwner_ = owner;
        owner = newOwner;
        newOwner = address(0);
        emit OwnershipTransferred(prevOwner_, owner);
    }
}
