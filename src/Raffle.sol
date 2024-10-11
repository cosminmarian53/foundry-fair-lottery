// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
/**
 *@title Raffle
 *@author cosminmarian53
 *@notice This contract is used to create a raffle
 *@dev Implements Chainlink VRF
 */
contract Raffle {
    /*
        Errors
    */
    error Raffle__NotEnoughEthToEnterRaffle();
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    /* 
        Events
    */
    event RaffleEntered(address indexed player);
    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        // require(msg.value>=i_entranceFee, "Not enough ETH to enter the raffle");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }
    function pickWinner() public {}
    /**
     *Getters
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
