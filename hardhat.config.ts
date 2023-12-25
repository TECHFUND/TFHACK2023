import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const accounts = process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [];

task(
  "accounts",
  "Prints the list of accounts with balances",
  async (_, hre) => {
    const accounts = await hre.ethers.getSigners();
    const provider = hre.ethers.provider;

    for (const account of accounts) {
      const balance = await provider.getBalance(account.address);
      console.log(
        `${account.address} - ${hre.ethers.formatEther(balance)} ETH`
      );
    }
  }
);

task("deploy", "Deploys Contract", async (_, hre) => {
  const tfInstance = await hre.ethers.deployContract("MusicRemixer");
  await tfInstance.waitForDeployment();
  console.log("contract deployed at:", tfInstance.target);
});

const config: HardhatUserConfig = {
  defaultNetwork: "localhost",
  networks: {
    hardhat: {
      chainId: 1337
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  gasReporter: {
    enabled: true,
    currency: "USD"
  },
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  }
};

export default config;
