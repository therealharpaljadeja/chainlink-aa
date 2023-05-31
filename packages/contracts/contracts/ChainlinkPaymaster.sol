// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@account-abstraction/contracts/core/BasePaymaster.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "hardhat/console.sol";

import "./Uniswap/IV3SwapRouter.sol";

// 0xEa7661aB07158073535443997D1acF9b03c62acF - LINK/MATIC pool
// https://docs.uniswap.org/contracts/v3/reference/deployments

contract LinkPaymaster is Ownable, BasePaymaster {
    /**
     * Network: Mumbai
     * Aggregator: LINK/MATIC
     */
    AggregatorV3Interface constant priceFeed =
        AggregatorV3Interface(0x12162c3E810393dEC01362aBf156D7ecf6159528);
    ERC20 public linkToken = ERC20(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    address internal constant SWAP_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant wMatic =
        0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889;

    // Gas Limit to perform postOp
    uint256 internal constant COST_OF_POST = 15_000;

    constructor(
        IEntryPoint anEntryPoint,
        address owner
    ) BasePaymaster(anEntryPoint) {
        transferOwnership(owner);
    }

    /*
     * Chainlink Data Feeds
     */

    function getLinkRequired(uint256 ethAmount) public view returns (uint256) {
        (, int answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer) / ethAmount;
    }

    /*
     * Account Abstraction Paymaster Implementation
     */

    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 requestId,
        uint256 maxCost
    )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        // this is Account Abstraction wallet address
        address account = userOp.sender;

        // For the purpose of the hackathon I am making the EOA hold LINK tokens, however it can be present in the SCW but that make it complicated because I need to make an approval transaction before performing transactions and that requires ETH
        address signer = Ownable(account).owner();

        // Convert maxCost to amount of Link using Data Feed
        uint256 amountLinkRequired = getLinkRequired(maxCost);

        // Check signer balance is greater than the amount of Link required
        require(
            linkToken.balanceOf(signer) >= amountLinkRequired,
            "Signer doesn't have enough LINK"
        );

        // Check if the user has approved the paymaster to withdraw LINK from his/her account
        require(
            linkToken.allowance(signer, address(this)) >= amountLinkRequired,
            "Required Link amount not approved"
        );

        return (abi.encode(signer), 0);
    }

    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        address account = abi.decode(context, (address));

        address signer = Ownable(account).owner();

        // How many tokens did it cost to do the entire thing?
        uint256 actualTokenCost = getLinkRequired(actualGasCost + COST_OF_POST);

        // Get all that amount from the signer now
        linkToken.transferFrom(signer, address(this), actualTokenCost);
    }

    /*
     * Function that should be called by Keeper so that the link accumulated here is swapped to native currency for sponsoring user transactions and also recharge the keeper
     */
    function swapLinkToETH() external {
        uint256 linkBalance = linkToken.balanceOf(address(this));
        uint256 allowanceToSwapRouter = linkToken.allowance(
            address(this),
            SWAP_ROUTER
        );

        // Check if SwapRouter has allowance
        if (allowanceToSwapRouter < linkBalance) {
            linkToken.approve(SWAP_ROUTER, linkBalance - allowanceToSwapRouter);
        }

        IV3SwapRouter(SWAP_ROUTER).exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams(
                address(linkToken),
                address(wMatic),
                100,
                address(this),
                linkBalance,
                0,
                0
            )
        );

        bytes memory balanceOfSig = abi.encodeWithSignature(
            "balanceOf(address)",
            address(this)
        );
        (, bytes memory balanceData) = wMatic.call(balanceOfSig);
        uint256 wMaticBalance = uint256(bytes32(balanceData));

        bytes memory withdrawSig = abi.encodeWithSignature(
            "withdraw(uint256)",
            wMaticBalance
        );
        (bool success, ) = wMatic.call(withdrawSig);
    }

    receive() external payable {}
}
