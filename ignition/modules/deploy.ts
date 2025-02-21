import { ethers } from "hardhat";

async function main() {
  // Get the contract factories
  const ProjectListing = await ethers.getContractFactory("ProjectListing");
  const DAO = await ethers.getContractFactory("DAO");
  const Donate = await ethers.getContractFactory("Donate");

  // Deploy the contracts
  console.log("Deploying ProjectListing...");
  const projectListing = await ProjectListing.deploy(
    ethers.parseEther("0.001"), // Subscription fee (0.001 ETH)
    ethers.ZeroAddress, // Placeholder for DAO contract address
    ethers.ZeroAddress // Placeholder for Donate contract address
  );
  await projectListing.waitForDeployment();
  console.log("ProjectListing deployed to:", await projectListing.getAddress());

  console.log("Deploying DAO...");
  const dao = await DAO.deploy(
    await projectListing.getAddress(), // ProjectListing contract address
    ethers.parseEther("1") // Minimum stake amount (1 ETH)
  );
  await dao.waitForDeployment();
  console.log("DAO deployed to:", await dao.getAddress());

  console.log("Deploying Donate...");
  const donate = await Donate.deploy(
    await projectListing.getAddress(), // ProjectListing contract address
    await dao.getAddress() // DAO contract address
  );
  await donate.waitForDeployment();
  console.log("Donate deployed to:", await donate.getAddress());

  // Update ProjectListing with DAO and Donate contract addresses
  console.log("Updating ProjectListing with DAO and Donate addresses...");
  await projectListing.updateDAOContract(await dao.getAddress());
  await projectListing.updateDonateContract(await donate.getAddress());
  console.log("ProjectListing updated successfully!");

  console.log("Deployment complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
