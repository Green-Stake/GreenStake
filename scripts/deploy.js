const hre = require("hardhat");
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy ProjectListing contract
  const ProjectListing = await ethers.getContractFactory("ProjectListing");
  const subscriptionFee = ethers.parseEther("0.01"); // 0.01 ETH
  const projectListing = await ProjectListing.deploy(subscriptionFee);
  await projectListing.waitForDeployment();
  const projectListingAddress = await projectListing.getAddress();
  console.log("ProjectListing deployed to:", projectListingAddress);

  // Deploy DAO contract
  const DAO = await ethers.getContractFactory("DAO");
  const minStakeAmount = ethers.parseEther("0.01"); // 0.01 ETH
  const dao = await DAO.deploy(projectListingAddress, minStakeAmount);
  await dao.waitForDeployment();
  const daoAddress = await dao.getAddress();
  console.log("DAO deployed to:", daoAddress);

  // Deploy Donate contract
  const Donate = await ethers.getContractFactory("Donate");
  const donate = await Donate.deploy(projectListingAddress, daoAddress);
  await donate.waitForDeployment();
  const donateAddress = await donate.getAddress();
  console.log("Donate deployed to:", donateAddress);

  // Set up contract relationships
  const projectListingContract = await ethers.getContractAt("ProjectListing", projectListingAddress);
  await projectListingContract.setDaoContract(daoAddress);
  await projectListingContract.setDonateContract(donateAddress);
  console.log("Contract relationships set up");

  // Get the contract ABIs
  const projectListingArtifact = await hre.artifacts.readArtifact("ProjectListing");
  const daoArtifact = await hre.artifacts.readArtifact("DAO");
  const donateArtifact = await hre.artifacts.readArtifact("Donate");

  // Create the contract config
  const contractConfig = {
    contracts: {
      ProjectListing: {
        address: projectListingAddress,
        subscriptionFee: "0.01",
        abi: projectListingArtifact.abi
      },
      DAO: {
        address: daoAddress,
        minStakeAmount: "0.01",
        abi: daoArtifact.abi
      },
      Donate: {
        address: donateAddress,
        abi: donateArtifact.abi
      }
    }
  };

  // Save the contract config
  const frontendConfigPath = path.join(__dirname, "../../frontend/app/utils/contractConfig.json");
  fs.writeFileSync(frontendConfigPath, JSON.stringify(contractConfig, null, 2));
  console.log("Contract config saved!");

  // Save the deployment info
  const deploymentInfo = {
    projectListing: projectListingAddress,
    dao: daoAddress,
    donate: donateAddress,
    network: hre.network.name
  };

  fs.writeFileSync(
    path.join(__dirname, "..", "deployment.json"),
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Deployment info saved!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
