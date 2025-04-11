// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Donate is ReentrancyGuard, Ownable {
    // Struct to store donation details
    struct Donation {
        address donor;
        uint256 amount;
        uint256 projectId;
        uint256 timestamp;
    }

    // Mapping to store donations by project ID
    mapping(uint256 => Donation[]) public projectDonations;

    // Mapping to store total donations per project
    mapping(uint256 => uint256) public totalDonationsPerProject;

    // Mapping to store donations by donor address
    mapping(address => Donation[]) public donorDonations;

    // Address of the ProjectListing contract
    address public projectListingContract;

    // Address of the DAO contract
    address public daoContract;

    // Events
    event DonationReceived(uint256 indexed projectId, address indexed donor, uint256 amount);
    event FundsDistributed(uint256 indexed projectId, uint256 ownerShare, uint256 daoShare, uint256 platformFee);

    // Constructor to set the ProjectListing and DAO contract addresses
    constructor(address _projectListingContract, address _daoContract) Ownable(msg.sender) {
        require(_projectListingContract != address(0), "Invalid ProjectListing address");
        require(_daoContract != address(0), "Invalid DAO address");
        projectListingContract = _projectListingContract;
        daoContract = _daoContract;
    }

    // Function to set the ProjectListing contract address
    function setProjectListingContract(address _projectListingContract) external onlyOwner {
        require(_projectListingContract != address(0), "Invalid ProjectListing contract address");
        projectListingContract = _projectListingContract;
    }

    // Function to set the DAO contract address
    function setDaoContract(address _daoContract) external onlyOwner {
        require(_daoContract != address(0), "Invalid DAO contract address");
        daoContract = _daoContract;
    }

    // Function to donate to a project
    function donateToProject(uint256 projectId) external payable nonReentrant {
        require(msg.value > 0, "Donation amount must be greater than 0");

        // Get project details from ProjectListing
        (bool success, bytes memory data) = projectListingContract.call(
            abi.encodeWithSignature("getProject(uint256)", projectId)
        );
        require(success && data.length > 0, "Failed to get project details");

        // Decode project details
        (
            string memory name,
            string memory description,
            address owner,
            bool isListed,
            bool isApproved,
            uint256 totalDonations,
            uint256 subscriptionEndTime
        ) = abi.decode(data, (string, string, address, bool, bool, uint256, uint256));

        require(isListed, "Project is not listed");
        require(isApproved, "Project is not approved");
        require(block.timestamp <= subscriptionEndTime, "Project subscription has expired");

        // Record the donation
        Donation memory newDonation = Donation({
            donor: msg.sender,
            amount: msg.value,
            projectId: projectId,
            timestamp: block.timestamp
        });

        // Update project donations
        projectDonations[projectId].push(newDonation);
        totalDonationsPerProject[projectId] += msg.value;

        // Update donor donations
        donorDonations[msg.sender].push(newDonation);

        // Record donation in ProjectListing contract
        (success, ) = projectListingContract.call(
            abi.encodeWithSignature("recordDonation(uint256,uint256)", projectId, msg.value)
        );
        require(success, "Failed to record donation in ProjectListing");

        // Calculate shares
        uint256 ownerShare = (msg.value * 80) / 100; // 80% to project owner
        uint256 daoShare = (msg.value * 15) / 100;   // 15% to DAO members
        uint256 platformFee = (msg.value * 5) / 100;  // 5% to platform

        // Send owner share to project owner
        (success, ) = payable(owner).call{value: ownerShare}("");
        require(success, "Failed to send owner share");
        
        // Get DAO members
        (success, data) = daoContract.call(
            abi.encodeWithSignature("getDAOMembers()")
        );
        require(success && data.length > 0, "Failed to get DAO members");
        address[] memory daoMembers = abi.decode(data, (address[]));

        if (daoMembers.length > 0) {
            // Distribute DAO share among members
            uint256 sharePerMember = daoShare / daoMembers.length;
            for (uint256 i = 0; i < daoMembers.length; i++) {
                (success, ) = daoMembers[i].call{value: sharePerMember}("");
                require(success, "Failed to send DAO member share");
            }
        } else {
            // If no DAO members, send DAO share to platform
            platformFee += daoShare;
        }

        // Send platform fee to contract owner
        (success, ) = super.owner().call{value: platformFee}("");
        require(success, "Failed to send platform fee");

        emit DonationReceived(projectId, msg.sender, msg.value);
        emit FundsDistributed(projectId, ownerShare, daoShare, platformFee);
    }

    // Function to get donations for a project
    function getProjectDonations(uint256 projectId) external view returns (Donation[] memory) {
        return projectDonations[projectId];
    }

    // Function to get total donations by a donor
    function getTotalDonationsByDonor(address donor) external view returns (uint256) {
        uint256 total = 0;
        Donation[] memory donations = donorDonations[donor];
        for(uint i = 0; i < donations.length; i++) {
            total += donations[i].amount;
        }
        return total;
    }

    // Function to get all donations by a donor
    function getDonorDonations(address donor) external view returns (Donation[] memory) {
        return donorDonations[donor];
    }

    // Function to get donations by a donor
    function getDonorDonations(address donor) external view returns (Donation[] memory) {
        return donorDonations[donor];
    }

    // Function to get total donations for a project
    function getProjectTotalDonations(uint256 projectId) external view returns (uint256) {
        return totalDonationsPerProject[projectId];
    }
}
