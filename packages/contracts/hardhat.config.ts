import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.8.17",
            },
            {
                version: "0.4.18",
            },
            {
                version: "0.7.5",
            },
            {
                version: "0.5.0",
            },
        ],
    },
    networks: {
        mumbai: {
            url: "https://rpc.ankr.com/polygon_mumbai",
            accounts: [process.env.PRIVATE_KEY],
        },
    },
};

export default config;
