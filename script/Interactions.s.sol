// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2;
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }
    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        console2.log("Creating subscription on chain ID: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console2.log("Subscription ID: ", subId);
        console2.log("Please update your subId in your HelperConfig.s.sol");
        return (subId, vrfCoordinator);
    }
    function run() public {
        // Create a subscription
    }
}
contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 1 ether;
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subId, linkToken);
    }
    function fundSubscription(
        address vrfCoordinator,
        uint256 subId,
        address linkToken
    ) public {
        console2.log("Funding subscription:", subId);
        console2.log("Chain ID: ", block.chainid);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }
    function run() public {
        fundSubscriptionUsingConfig();
    }
}
contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId);
    }
    function addConsumer(
        address contractToAddtoVrf,
        address vrfCoordinator,
        uint256 subId
    ) public {
        console2.log("Adding consumer to subscription:", subId);
        console2.log("Chain ID: ", block.chainid);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddtoVrf);
        vm.stopBroadcast();
    }
    function run() external {
       address mostRecentDeployedContract = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
       addConsumerUsingConfig(mostRecentDeployedContract);
    }
}
