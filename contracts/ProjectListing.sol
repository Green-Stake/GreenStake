// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectListing is ReentrancyGuard, Ownable {
    // Struct to store project details
    struct Project {
        string name;
        string description;
        address owner;
        bool isListed;
        bool isApproved;
        uint256 totalDonations;
        uint256 subscriptionEndTime;
    }

    // Mapping to store projects by ID
    mapping(uint256 => Project) public projects;
    
    // Array to store all project IDs
    uint256[] public projectIds;
    
    // Array to store approved project IDs
    uint256[] public approvedProjectIds;

    // Counter for project IDs
    uint256 private nextProjectId = 1;

    // Subscription fee in wei
    uint256 public subscriptionFee;

    // Subscription duration in seconds (30 days)
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;

    // Address of the DAO contract
    address public daoContract;

    // Address of the Donate contract
    address public donateContract;

    // Events
    event ProjectListed(uint256 indexed projectId, address indexed owner, string name);
    event ProjectApproved(uint256 indexed projectId);
    event DonationRecorded(uint256 indexed projectId, uint256 amount);

    // Constructor to set the subscription fee
    constructor(uint256 _subscriptionFee) Ownable(msg.sender) {
        subscriptionFee = _subscriptionFee;
    }

    // Modifier to check if project exists and is listed
    modifier projectExists(uint256 projectId) {
        require(projectId > 0 && projectId < nextProjectId, "Project does not exist");
        require(projects[projectId].isListed, "Project is not listed");
        _;
    }

    // Function to set the DAO contract address
    function setDAOContract(address _daoContract) external onlyOwner {
        require(_daoContract != address(0), "Invalid DAO contract address");
        daoContract = _daoContract;
    }

    // Function to set the Donate contract address
    function setDonateContract(address _donateContract) external onlyOwner {
        require(_donateContract != address(0), "Invalid Donate contract address");
        donateContract = _donateContract;
    }

    // Function to list a new project
    function listProject(string memory name, string memory description) external payable nonReentrant {
        require(msg.value == subscriptionFee, "Incorrect subscription fee");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 projectId = nextProjectId++;
        
        projects[projectId] = Project({
            name: name,
            description: description,
            owner: msg.sender,
            isListed: true,
            isApproved: false,
            totalDonations: 0,
            subscriptionEndTime: block.timestamp + SUBSCRIPTION_DURATION
        });

        projectIds.push(projectId);

        // Forward the request to the DAO contract
        (bool success, ) = daoContract.call(
            abi.encodeWithSignature(
                "receiveProjectRequest(uint256,address,string,string)",
                projectId,
                msg.sender,
                name,
                description
            )
        );
        require(success, "Failed to forward request to DAO");

        emit ProjectListed(projectId, msg.sender, name);
    }

    // Function to approve a project (can only be called by the DAO contract)
    function approveProject(uint256 projectId) external projectExists(projectId) {
        require(msg.sender == daoContract, "Only DAO can approve projects");
        require(!projects[projectId].isApproved, "Project already approved");

        projects[projectId].isApproved = true;
        approvedProjectIds.push(projectId);

        emit ProjectApproved(projectId);
    }

    // Function to record a donation (can only be called by the Donate contract)
    function recordDonation(uint256 projectId, uint256 amount) external projectExists(projectId) {
        require(msg.sender == donateContract, "Only Donate contract can record donations");
        require(projects[projectId].isApproved, "Project is not approved");
        require(block.timestamp <= projects[projectId].subscriptionEndTime, "Project subscription has expired");

        projects[projectId].totalDonations += amount;

        emit DonationRecorded(projectId, amount);
    }

    // Function to get all project IDs
    function getAllProjectIds() external view returns (uint256[] memory) {
        return projectIds;
    }

    // Function to get approved project IDs
    function getApprovedProjects() external view returns (uint256[] memory) {
        return approvedProjectIds;
    }

    // Function to get project details
    function getProject(uint256 projectId) external view returns (
        string memory name,
        string memory description,
        address owner,
        bool isListed,
        bool isApproved,
        uint256 totalDonations,
        uint256 subscriptionEndTime
    ) {
        Project storage project = projects[projectId];
        return (
            project.name,
            project.description,
            project.owner,
            project.isListed,
            project.isApproved,
            project.totalDonations,
            project.subscriptionEndTime
        );
    }

    // Function to get the number of projects
    function getProjectCount() external view returns (uint256) {
        return projectIds.length;
    }

    // Function to get the number of approved projects
    function getApprovedProjectCount() external view returns (uint256) {
        return approvedProjectIds.length;
    }
}
