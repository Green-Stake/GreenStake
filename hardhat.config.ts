import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const { ALCHEMY_API_KEY, DEPLOYER_PRIVATE_KEY } = process.env;

if (!ALCHEMY_API_KEY || !DEPLOYER_PRIVATE_KEY) {
  throw new Error("Please set ALCHEMY_API_KEY and DEPLOYER_PRIVATE_KEY in your .env file");
}

const config: HardhatUserConfig = {
  solidity: "0.8.25",
  networks: {
    arbitrumSepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
  },
};

export default config;
