// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@account-abstraction/contracts/core/BasePaymaster.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "hardhat/console.sol";

contract LinkPaymaster is Ownable, BasePaymaster {
    /**
     * Network: Sepolia
     * Aggregator: LINK/ETH
     */
    AggregatorV3Interface constant priceFeed =
        AggregatorV3Interface(0x42585eD362B3f1BCa95c640FdFf35Ef899212734);
    ERC20 public linkToken = ERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789);

    // Gas Limit to perform postOp
    uint256 const internal COST_OF_POST = 15_000;

    constructor(
        IEntryPoint anEntryPoint,
        address owner
    ) BasePaymaster(anEntryPoint) {
        transferOwnership(actualOwner);
    }

    /*
     * Chainlink Data Feeds
     */

    function getLinkRequired(uint256 ethAmount) public view returns (int) {
        (, int answer, , , ) = priceFeed.latestRoundData();
        return answer / ethAmount;
    }

    /*
     * Account Abstraction Paymaster Implementation
     */

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 requestId,
        uint256 maxCost
    ) external view override returns (bytes memory context) {
        // this is Account Abstraction wallet address
        address account = userOp.sender;

        // For the purpose of the hackathon I am making the EOA hold LINK tokens, however it can be present in the SCW but that make it complicated because I need to make an approval transaction before performing transactions and that requires ETH
        address signer = Ownable(account).owner();

        // Convert maxCost to amount of Link using Data Feed
        int linkPriceInETH = getLatestPrice();
        uint256 amountLinkRequired = getLinkRequired(maxCost);

        // Check signer balance is greater than the amount of Link required
        require(
            linkToken.balanceOf(signer) >= amountLinkRequired,
            "Signer doesn't have enough LINK"
        );

        // Check if the user has approved the paymaster to withdraw LINK from his/her account
        require(
            linkToken.allowance(address(this)) >= amountLinkRequired,
            "Required Link amount not approved"
        );

        return abi.encode(signer);
    }

    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        (
            address account,
        ) = abi.decode(context, (address));

        address signer = Ownable(account).owner();

        // How many tokens did it cost to do the entire thing?
        uint256 actualTokenCost = getLinkRequired(actualGasCost + COST_OF_POST);

        // Get all that amount from the signer now
        linkToken.transferFrom(signer, address(this), actualTokenCost);
    }
}
