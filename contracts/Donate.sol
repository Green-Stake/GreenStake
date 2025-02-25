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

    // Function to donate to a project
    function donateToProject(uint256 projectId) external payable nonReentrant {
        require(msg.value > 0, "Donation amount must be greater than 0");

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
        (bool success, ) = projectListingContract.call(
            abi.encodeWithSignature("recordDonation(uint256,uint256)", projectId, msg.value)
        );
        require(success, "Failed to record donation in ProjectListing");

        // Distribute funds
        _distributeFunds(projectId, msg.value);

        // Emit event
        emit DonationReceived(projectId, msg.sender, msg.value);
    }

    // Internal function to distribute funds
    function _distributeFunds(uint256 projectId, uint256 amount) internal {
        // Calculate shares
        uint256 ownerShare = (amount * 80) / 100; // 80% to project owner
        uint256 daoShare = (amount * 15) / 100;   // 15% to DAO members
        uint256 platformFee = (amount * 5) / 100;  // 5% to platform

        // Get project details from ProjectListing
        (bool success, bytes memory data) = projectListingContract.call(
            abi.encodeWithSignature("getProject(uint256)", projectId)
        );
        require(success, "Failed to get project details");

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

        require(isListed && isApproved, "Project is not listed or not approved");
        require(block.timestamp <= subscriptionEndTime, "Project subscription has expired");

        // Send shares to respective parties
        payable(owner).transfer(ownerShare);

        // Get DAO members
        (bool daoSuccess, bytes memory daoData) = daoContract.call(
            abi.encodeWithSignature("getDAOMembers()")
        );
        require(daoSuccess, "Failed to get DAO members");
        address[] memory daoMembers = abi.decode(daoData, (address[]));

        if (daoMembers.length > 0) {
            // Distribute DAO share among members
            uint256 sharePerMember = daoShare / daoMembers.length;
            for (uint256 i = 0; i < daoMembers.length; i++) {
                payable(daoMembers[i]).transfer(sharePerMember);
            }
        } else {
            // If no DAO members, send DAO share to platform
            platformFee += daoShare;
        }

        // Send platform fee to contract owner
        payable(super.owner()).transfer(platformFee);

        emit FundsDistributed(projectId, ownerShare, daoShare, platformFee);
    }

    // Function to get donations for a project
    function getProjectDonations(uint256 projectId) external view returns (Donation[] memory) {
        return projectDonations[projectId];
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
