import { expect } from "chai";
import { ethers } from "hardhat";
import { DAO } from "../typechain-types";
import { parseEther } from "ethers"; // ✅ Import `parseEther` directly

describe("DAO Contract", function () {
    let dao: DAO;
    let owner: any;
    let user1: any;
    let user2: any;
    let projectListing: any;
    let minStake: any;

    beforeEach(async function () {
        [owner, user1, user2, projectListing] = await ethers.getSigners();

        minStake = parseEther("1"); // ✅ Use `parseEther` directly

        const DAO = await ethers.getContractFactory("DAO");
        dao = await DAO.deploy(projectListing.address, minStake);
        await dao.waitForDeployment(); // ✅ Replaces `.deployed()`
    });

    it("Should allow a user to join the DAO by staking", async function () {
        await dao.connect(user1).joinDAO({ value: minStake });

        const member = await dao.members(user1.address);
        expect(member.isMember).to.be.true;
        expect(member.stakedAmount).to.equal(minStake);
    });

    it("Should not allow a user to join DAO with insufficient stake", async function () {
        await expect(
            dao.connect(user1).joinDAO({ value: parseEther("0.5") }) // ✅ Use `parseEther` directly
        ).to.be.revertedWith("Insufficient stake amount");
    });

    it("Should receive a project request from ProjectListing", async function () {
        const projectId = 1;
        const projectOwner = user1.address;
        const projectName = "Solar Power Plant";
        const projectDesc = "A renewable energy project";

        await dao.connect(projectListing).receiveProjectRequest(projectId, projectOwner, projectName, projectDesc);

        const project = await dao.projectRequests(projectId);
        expect(project.projectOwner).to.equal(projectOwner);
        expect(project.name).to.equal(projectName);
        expect(project.description).to.equal(projectDesc);
    });

    it("Should allow DAO members to vote on projects", async function () {
        await dao.connect(user1).joinDAO({ value: minStake });
        await dao.connect(user2).joinDAO({ value: minStake });

        const projectId = 1;
        await dao.connect(projectListing).receiveProjectRequest(projectId, user1.address, "Wind Farm", "Green Energy");

        await dao.connect(user1).voteOnProject(projectId, true);
        await dao.connect(user2).voteOnProject(projectId, false);

        const project = await dao.projectRequests(projectId);
        expect(project.yesVotes).to.equal(1);
        expect(project.noVotes).to.equal(1);
    });

    it("Should process a project request and approve/reject based on votes", async function () {
        await dao.connect(user1).joinDAO({ value: minStake });
        await dao.connect(user2).joinDAO({ value: minStake });

        const projectId = 1;
        await dao.connect(projectListing).receiveProjectRequest(projectId, user1.address, "Wind Farm", "Green Energy");

        await dao.connect(user1).voteOnProject(projectId, true); // 1 Yes Vote
        await dao.connect(user2).voteOnProject(projectId, true); // 2 Yes Votes

        await dao.connect(owner).projectRequests(projectId);

        const project = await dao.projectRequests(projectId);
        expect(project.isApproved).to.be.true;
    });
});
