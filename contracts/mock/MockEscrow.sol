// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {Escrow} from "../Escrow.sol";

contract MockEscrow is Escrow(2, address(1)) {}
