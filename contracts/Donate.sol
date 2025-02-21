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
    constructor(address _projectListingContract, address _daoContract) Ownable(msg.sender){
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

        // Distribute funds
        _distributeFunds(projectId, msg.value);

        // Emit event
        emit DonationReceived(projectId, msg.sender, msg.value);
    }
// Internal function to distribute funds
function _distributeFunds(uint256 projectId, uint256 amount) internal {
    // Calculate shares
    uint256 ownerShare = (amount * 80) / 100; // 80% to project owner
    uint256 daoShare = (amount * 15) / 100;  // 15% to DAO members
    uint256 platformFee = (amount * 5) / 100; // 5% to platform

    // Retrieve project owner address from ProjectListing.sol
    (bool successProjectOwner, bytes memory projectOwnerData) = projectListingContract.call(
        abi.encodeWithSignature("getProjectOwner(uint256)", projectId)
    );
    require(successProjectOwner, "Failed to retrieve project owner");
    address projectOwner = abi.decode(projectOwnerData, (address));

    // Send 80% to the project owner
    payable(projectOwner).transfer(ownerShare);

    // Retrieve DAO member addresses from DAO.sol
    (bool successDAOMembers, bytes memory daoMembersData) = daoContract.call(
        abi.encodeWithSignature("getDAOMembers()")
    );
    require(successDAOMembers, "Failed to retrieve DAO members");
    address[] memory daoMembers = abi.decode(daoMembersData, (address[]));

    // Distribute 15% among DAO members
    if (daoMembers.length > 0) {
        uint256 sharePerMember = daoShare / daoMembers.length;
        for (uint256 i = 0; i < daoMembers.length; i++) {
            payable(daoMembers[i]).transfer(sharePerMember);
        }
    } else {
        // If no DAO members, send the DAO share to the platform
        platformFee += daoShare;
    }

    // Retrieve platform wallet address (contract owner) from ProjectListing.sol
    (bool successPlatformWallet, bytes memory platformWalletData) = projectListingContract.call(
        abi.encodeWithSignature("owner()")
    );
    require(successPlatformWallet, "Failed to retrieve platform wallet");

    // Decode the platform wallet address
    address platformWallet = abi.decode(platformWalletData, (address));

    // Send 5% to the platform
    payable(platformWallet).transfer(platformFee);

    // Emit event
    emit FundsDistributed(projectId, ownerShare, daoShare, platformFee);
}
}
