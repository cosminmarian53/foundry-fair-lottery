// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // local -> deploy mocks
        // sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        if (config.subscriptionId == 0) {
            // create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2) =
                createSubscription.createSubscription(config.vrfCoordinatorV2, config.account);
            // fund subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2, config.subscriptionId, config.link, config.account
            );
        }
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.interval,
            config.entranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinatorV2, config.subscriptionId, config.account);

        return (raffle, helperConfig);
    }
}
