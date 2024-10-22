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
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 *@title Raffle
 *@author cosminmarian53
 *@notice This contract is used to create a raffle
 *@dev Implements Chainlink VRF
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*
        Errors
    */
    error Raffle__NotEnoughEthToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );
    /*
        Type declarations
    */
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    /*
        State variables
    */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    // Chainlink VRF related variables
    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    /* 
        Events
    */
    event RaffleEntered(address indexed player);
    event RaffleWinner(address indexed winner);
    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        // uint256 balance = address(this).balance;
        // if (balance > 0) {
        //     payable(msg.sender).transfer(balance);
        // }
    }
    function enterRaffle() public payable {
        // require(msg.value>=i_entranceFee, "Not enough ETH to enter the raffle");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink nodes will call to see if the
     * lottery is ready to have a winner picked
     *The following should be true in order for upKeepNeeded to return true:
     *1. The time interval between the raffles has passed
     *2. The raffle is in the OPEN state
     *3. The contract has ETH
     *4. Implicitly, your subscription is funded with LINK
     * @param -  ignored
     * @return upKeepNeeded - true if the raffle is ready to have a winner picked
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upKeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) < i_interval);
        bool raffleIsOpen = s_raffleState == RaffleState.OPEN;
        bool contractHasEth = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = timeHasPassed && raffleIsOpen && contractHasEth;
        return (upKeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit RaffleWinner(recentWinner);
    }
    /**
     *Getters
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
