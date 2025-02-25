import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";
import { ProjectListing__factory, DAO__factory, Donate__factory } from "../typechain-types";

async function main() {
    try {
        const [deployer] = await ethers.getSigners();
        console.log("Deploying contracts with the account:", deployer.address);

        // Set subscription fee to 0.01 ETH
        const subscriptionFee = ethers.parseEther("0.01");
        console.log("Setting subscription fee to: 0.01 ETH");

        // Deploy ProjectListing contract first
        console.log("Deploying ProjectListing...");
        const ProjectListing = await ethers.getContractFactory("ProjectListing");
        const projectListing = await ProjectListing.deploy(subscriptionFee);
        await projectListing.waitForDeployment();
        const projectListingAddress = await projectListing.getAddress();
        console.log("ProjectListing deployed to:", projectListingAddress);

        // Set minimum stake amount to 0.01 ETH
        const minStakeAmount = ethers.parseEther("0.01");
        console.log("Setting minimum stake amount to: 0.01 ETH");

        // Deploy DAO contract with ProjectListing address
        console.log("Deploying DAO...");
        const DAO = await ethers.getContractFactory("DAO");
        const dao = await DAO.deploy(projectListingAddress, minStakeAmount);
        await dao.waitForDeployment();
        const daoAddress = await dao.getAddress();
        console.log("DAO deployed to:", daoAddress);

        // Deploy Donate contract with ProjectListing and DAO addresses
        console.log("Deploying Donate...");
        const Donate = await ethers.getContractFactory("Donate");
        const donate = await Donate.deploy(projectListingAddress, daoAddress);
        await donate.waitForDeployment();
        const donateAddress = await donate.getAddress();
        console.log("Donate deployed to:", donateAddress);

        // Update contract addresses
        console.log("Updating contract addresses...");

        try {
            // Set DAO contract address in ProjectListing
            const setDaoTx = await projectListing.setDaoContract(daoAddress);
            await setDaoTx.wait();
            console.log("Updated DAO address in ProjectListing");

            // Set Donate contract address in ProjectListing
            const setDonateTx = await projectListing.setDonateContract(donateAddress);
            await setDonateTx.wait();
            console.log("Updated Donate address in ProjectListing");

            // Verify contract addresses are set correctly
            const daoContractAddress = await projectListing.daoContract();
            const donateContractAddress = await projectListing.donateContract();

            if (daoContractAddress.toLowerCase() !== daoAddress.toLowerCase()) {
                throw new Error("DAO contract address not set correctly in ProjectListing");
            }
            if (donateContractAddress.toLowerCase() !== donateAddress.toLowerCase()) {
                throw new Error("Donate contract address not set correctly in ProjectListing");
            }

            console.log("Contract addresses verified successfully");
        } catch (error) {
            console.error("Error updating or verifying contract addresses:", error);
            throw error;
        }

        // Save deployment info
        const deploymentInfo = {
            projectListing: projectListingAddress,
            dao: daoAddress,
            donate: donateAddress,
            network: "arbitrumSepolia",
            subscriptionFee: "0.01",
            minStakeAmount: "0.01"
        };

        const deploymentPath = path.join(__dirname, "..", "deployment.json");
        fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
        console.log("Deployment info saved to:", deploymentPath);

        // Get contract ABIs
        const projectListingAbi = ProjectListing__factory.abi;
        const daoAbi = DAO__factory.abi;
        const donateAbi = Donate__factory.abi;

        // Save contract config for frontend
        const contractConfig = {
            contracts: {
                ProjectListing: {
                    address: projectListingAddress,
                    subscriptionFee: "0.01",
                    abi: projectListingAbi
                },
                DAO: {
                    address: daoAddress,
                    minStakeAmount: "0.01",
                    abi: daoAbi
                },
                Donate: {
                    address: donateAddress,
                    abi: donateAbi
                }
            }
        };

        const frontendConfigPath = path.join(__dirname, "../../frontend/app/utils/contractConfig.json");
        fs.writeFileSync(frontendConfigPath, JSON.stringify(contractConfig, null, 2));
        console.log("Contract config saved to frontend at:", frontendConfigPath);

        console.log("\nDeployment completed successfully!");
    } catch (error) {
        console.error("Error during deployment:", error);
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
