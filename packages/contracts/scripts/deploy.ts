import { ethers } from "hardhat";

async function main() {
    const ENTRYPOINT_ADDRESS = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

    const [deployer] = await ethers.getSigners();
    console.log(`Deploying using: ${deployer.address}`);

    const Paymaster = await ethers.getContractFactory("LinkPaymaster");
    const paymaster = await Paymaster.deploy(
        ENTRYPOINT_ADDRESS,
        deployer.address
    );

    await paymaster.deployed();

    console.log(`Paymaster deployed at: ${paymaster.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
