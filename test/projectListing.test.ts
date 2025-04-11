import { expect } from "chai";
import { ethers } from "hardhat";
import { ProjectListing } from "../typechain-types/contracts/ProjectListing";
import { Signer } from "ethers";

describe("ProjectListing Contract", function () {
  let projectListing: ProjectListing;
  let owner: Signer;
  let user1: Signer;
  let user2: Signer;
  let daoSigner: Signer;    // Simulated DAO contract
  let donateSigner: Signer; // Simulated Donate contract

  beforeEach(async function () {
    // Get signers.
    [owner, user1, user2, daoSigner, donateSigner] = await ethers.getSigners();

    const ProjectListingFactory = await ethers.getContractFactory("ProjectListing");

    // Deploy the contract with three constructor parameters:
    // _subscriptionFee, _daoContract, _donateContract
    projectListing = (await ProjectListingFactory.deploy(
      ethers.parseEther("1")               // Subscription fee
    )) as ProjectListing;

    await projectListing.waitForDeployment();
  });

  it("Should allow a user to list a project", async function () {
    // Get the subscription fee from the contract.
    const listingFee = await projectListing.subscriptionFee();

    // Call listProject from user1 with the required fee.
    const tx = await projectListing.connect(user1).listProject(
      "Solar Plant",
      "Renewable energy project",
      { value: listingFee }
    );
    const receipt = await tx.wait();

    // Optionally, log receipt events for debugging:
    // console.log("Receipt events:", receipt.events);

    // Check that the ProjectListed event is emitted.
    const event = (receipt as any).events?.find((e: any) => e.event === "ProjectListed");
    expect(event, "ProjectListed event not emitted").to.exist;
    if (event && event.args) {
      expect(event.args.projectId).to.equal(1);
      expect(event.args.owner).to.equal(await user1.getAddress());
      expect(event.args.name).to.equal("Solar Plant");
    }

    // Retrieve the project from the public mapping.
    const project = await projectListing.projects(1);
    // Destructure the returned tuple.
    // Expected structure: [id, name, description, owner, subscriptionEndTime, isListed, totalDonations]
    const projectId = project[0];
    const projectName = project[1];
    const projectDescription = project[2];
    const projectOwner = project[3];
    const subscriptionEndTime = project[4];
    const isListed = project[5];
    const totalDonations = project[6];

    expect(projectId).to.equal(1);
    expect(projectOwner).to.equal(await user1.getAddress());
    expect(projectName).to.equal("Solar Plant");
    expect(projectDescription).to.equal("Renewable energy project");
    expect(isListed).to.be.true;
  });
});
