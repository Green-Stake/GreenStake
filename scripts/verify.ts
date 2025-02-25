import { run } from "hardhat";
import { ethers } from "hardhat";
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  // Read deployment info
  const deploymentPath = path.join(__dirname, '../deployment.json');
  if (!fs.existsSync(deploymentPath)) {
    throw new Error('Deployment info not found. Please run deploy.ts first.');
  }

  const deploymentInfo = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
  const { contracts } = deploymentInfo;

  console.log("Starting contract verification...");

  try {
    // Values used in deployment
    const subscriptionFee = ethers.parseEther("0.1"); // 0.1 ETH
    const minStakeAmount = ethers.parseEther("1"); // 1 ETH

    // Verify ProjectListing
    console.log("Verifying ProjectListing contract...");
    await run("verify:verify", {
      address: contracts.ProjectListing.address,
      constructorArguments: [
        subscriptionFee,
        contracts.DAO.address,
        contracts.Donate.address
      ]
    });

    // Verify DAO
    console.log("Verifying DAO contract...");
    await run("verify:verify", {
      address: contracts.DAO.address,
      constructorArguments: [
        contracts.ProjectListing.address,
        minStakeAmount
      ]
    });

    // Verify Donate
    console.log("Verifying Donate contract...");
    await run("verify:verify", {
      address: contracts.Donate.address,
      constructorArguments: [
        contracts.ProjectListing.address,
        contracts.DAO.address
      ]
    });

    console.log("All contracts verified successfully!");
  } catch (error) {
    console.error("Error during verification:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
