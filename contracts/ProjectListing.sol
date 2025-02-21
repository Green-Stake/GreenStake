// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectListing is ReentrancyGuard, Ownable {
    // Struct to store project details
    struct Project {
        uint256 id;
        string name;
        string description;
        address owner;
        uint256 subscriptionEndTime;
        bool isListed;
        uint256 totalDonations;
    }

    // Mapping to store projects by their ID
    mapping(uint256 => Project) public projects;

    // Mapping to store project IDs by owner address
    mapping(address => uint256[]) public ownerProjects;

    // Counter for project IDs
    uint256 public projectCounter;

    // Subscription fee amount (in wei)
    uint256 public subscriptionFee;

    // Address of the DAO contract
    address public daoContract;

    // Address of the Donate contract
    address public donateContract;

    // Events
    event ProjectListed(uint256 indexed projectId, address indexed owner, string name, uint256 subscriptionEndTime);
    event SubscriptionRenewed(uint256 indexed projectId, uint256 newSubscriptionEndTime);
    event ProjectDelisted(uint256 indexed projectId);
    event FundsDistributed(uint256 indexed projectId, uint256 platformShare, uint256 donorsShare);

    // Constructor to set the subscription fee, DAO contract address, and Donate contract address
    constructor(uint256 _subscriptionFee, address _daoContract, address _donateContract) Ownable(msg.sender){
        subscriptionFee = _subscriptionFee;
        daoContract = _daoContract;
        donateContract = _donateContract;
    }

    // Function to list a new project
    function listProject(string memory name, string memory description) external payable nonReentrant {
        require(msg.value == subscriptionFee, "Incorrect subscription fee");

        // Generate a new project ID
        projectCounter++;
        uint256 projectId = projectCounter;

        // Set subscription end time (1 month from now)
        uint256 subscriptionEndTime = block.timestamp + 30 days;

        // Create and store the project
        projects[projectId] = Project({
            id: projectId,
            name: name,
            description: description,
            owner: msg.sender,
            subscriptionEndTime: subscriptionEndTime,
            isListed: true,
            totalDonations: 0
        });

        // Map the project ID to the owner's address
        ownerProjects[msg.sender].push(projectId);

        // Send the subscription fee to the platform (contract owner)
        payable(owner()).transfer(msg.value);

        // Emit event
        emit ProjectListed(projectId, msg.sender, name, subscriptionEndTime);

        // Send the project request to the DAO contract
        (bool success, ) = daoContract.call(
            abi.encodeWithSignature("receiveProjectRequest(uint256,address,string,string)", projectId, msg.sender, name, description)
        );
        require(success, "DAO contract call failed");
    }

    // Function to get project owner address
    function getProjectOwner(uint256 projectId) external view returns (address) {
        return projects[projectId].owner;
    }

    // Function to update the DAO contract address (only callable by the owner)
    function updateDAOContract(address newDAOContract) external onlyOwner {
        daoContract = newDAOContract;
    }

    // Function to update the Donate contract address (only callable by the owner)
    function updateDonateContract(address newDonateContract) external onlyOwner {
        donateContract = newDonateContract;
    }
}
