// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane; // keyHash
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10000 ether;

    // Events
    event RaffleEntered(address indexed player);
    event RaffleWinner(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2 = config.vrfCoordinatorV2;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // Ensure PLAYER has enough balance
    }
    // Tests
    // Test that the raffle reverts when the player doesn't pay enough

    function testRaffleRevertsWHenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        raffle.enterRaffle();
    }
    // Test that the raffle reverts when the player doesn't pay enough

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }
    // Test that the raffle emits an event when a player enters

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // Ensure PLAYER has enough balance

        // Act
        vm.expectEmit(true, true, true, true, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
    // Test that the players wont be able to enter the raffle when the raffle is calculating

    function testDontAllowPlayersToEnterWhenRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act

        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfItHasNoBallance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool result,) = raffle.checkUpkeep("");
        // Assert
        assert(!result);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act
        (bool result,) = raffle.checkUpkeep("");
        // Assert
        assert(!result);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testPerfomUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerfomUpKeepRevertsIfCheckUpKeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }
    // ---------------Modifiers-------------------

    modifier raffleEntered() {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testPerfomUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Assert
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }
    // ---------------Fulfill Random Words-------------------

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleEntered skipFork {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fulfillRandomWords(0, address(raffle));

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fulfillRandomWords(1, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // Ensure PLAYER has enough balance
        raffle.enterRaffle{value: entranceFee}();

        // Simulate multiple players entering the raffle
        address[] memory players = new address[](3);
        players[0] = address(1);
        players[1] = address(2);
        players[2] = address(3);

        for (uint256 i = 0; i < players.length; i++) {
            vm.deal(players[i], 1 ether);
            vm.prank(players[i]);
            raffle.enterRaffle{value: entranceFee}();
        }

        // Move forward in time and block number to simulate the passage of time
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Ensure the upkeep conditions are met
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        require(upkeepNeeded, "Upkeep not needed");

        // Perform the upkeep
        raffle.performUpkeep("");

        // Simulate the VRF callback
        uint256 requestId = 1; // Assuming requestId is 1 for simplicity
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))); // Generate a pseudo-random number

        // Act
        vm.prank(address(vrfCoordinatorV2));
        raffle.rawFulfillRandomWords(requestId, randomWords);

        // Assert
        address recentWinner = raffle.getRecentWinner();
        assert(recentWinner != address(0));
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getLastTimeStamp() > 0);
        assert(address(raffle).balance == 0);
    }
}
