// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAO is ReentrancyGuard, Ownable {
    // Struct to store project request details
    struct ProjectRequest {
        uint256 projectId;
        address projectOwner;
        string name;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool isApproved;
        bool isProcessed;
    }

    // Struct to store DAO member details
    struct Member {
        uint256 stakedAmount;
        bool isMember;
    }

    // Mapping to store project requests by project ID
    mapping(uint256 => ProjectRequest) public projectRequests;

    // Mapping to store DAO members by address
    mapping(address => Member) public members;

    // Mapping to track if a member has voted on a project request
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // List of DAO member addresses
    address[] public memberAddresses;

    // Address of the ProjectListing contract
    address public projectListingContract;

    // Minimum stake required to become a DAO member (in wei)
    uint256 public minStakeAmount;

    // Events
    event ProjectRequestReceived(uint256 indexed projectId, address indexed projectOwner, string name, string description);
    event Voted(uint256 indexed projectId, address indexed voter, bool vote);
    event ProjectApproved(uint256 indexed projectId);
    event ProjectRejected(uint256 indexed projectId);
    event NewMember(address indexed member, uint256 stakedAmount);

    // Modifiers
    modifier onlyMember() {
        require(members[msg.sender].isMember, "Not a DAO member");
        _;
    }

    // Constructor to set the ProjectListing contract address and minimum stake amount
    constructor(address _projectListingContract, uint256 _minStakeAmount) Ownable(msg.sender) {
        require(_projectListingContract != address(0), "Invalid ProjectListing address");
        projectListingContract = _projectListingContract;
        minStakeAmount = _minStakeAmount;
    }

    // Function to set the ProjectListing contract address
    function setProjectListingContract(address _projectListingContract) external onlyOwner {
        require(_projectListingContract != address(0), "Invalid ProjectListing contract address");
        projectListingContract = _projectListingContract;
    }

    // Function to join the DAO by staking tokens
    function joinDAO() external payable nonReentrant {
        require(msg.value >= minStakeAmount, "Insufficient stake amount");
        require(!members[msg.sender].isMember, "Already a DAO member");

        members[msg.sender] = Member({
            stakedAmount: msg.value,
            isMember: true
        });
        memberAddresses.push(msg.sender);

        emit NewMember(msg.sender, msg.value);
    }

    // Function to receive project requests from ProjectListing.sol
    function receiveProjectRequest(uint256 projectId, address projectOwner, string memory name, string memory description) external {
        require(msg.sender == projectListingContract, "Caller is not the ProjectListing contract");
        require(projectRequests[projectId].projectId == 0, "Project request already exists");

        projectRequests[projectId] = ProjectRequest({
            projectId: projectId,
            projectOwner: projectOwner,
            name: name,
            description: description,
            yesVotes: 0,
            noVotes: 0,
            isApproved: false,
            isProcessed: false
        });

        emit ProjectRequestReceived(projectId, projectOwner, name, description);
    }

    // Function to vote on a project request
    function voteOnProject(uint256 projectId, bool voteInFavor) external onlyMember {
        require(!hasVoted[projectId][msg.sender], "Already voted on this project");
        require(!projectRequests[projectId].isProcessed, "Project request already processed");

        ProjectRequest storage request = projectRequests[projectId];
        hasVoted[projectId][msg.sender] = true;

        if (voteInFavor) {
            request.yesVotes++;
        } else {
            request.noVotes++;
        }

        emit Voted(projectId, msg.sender, voteInFavor);

        // Check if we have enough votes to process the request
        uint256 totalVotes = request.yesVotes + request.noVotes;
        if (totalVotes >= memberAddresses.length / 2) {
            _processProjectRequest(projectId);
        }
    }

    // Internal function to process a project request after voting
    function _processProjectRequest(uint256 projectId) internal {
        ProjectRequest storage request = projectRequests[projectId];
        require(!request.isProcessed, "Project request already processed");

        // Check if the project has a majority of yes votes
        if (request.yesVotes > request.noVotes) {
            request.isApproved = true;
            // Call approveProject on ProjectListing contract
            (bool success, ) = projectListingContract.call(
                abi.encodeWithSignature("approveProject(uint256)", projectId)
            );
            require(success, "Failed to approve project in ProjectListing");
            emit ProjectApproved(projectId);
        } else {
            request.isApproved = false;
            emit ProjectRejected(projectId);
        }

        request.isProcessed = true;
    }

    // Function to get member count
    function getMemberCount() external view returns (uint256) {
        return memberAddresses.length;
    }

    // Function to check if an address is a member
    function isMember(address account) external view returns (bool) {
        return members[account].isMember;
    }

    // Function to get member stake amount
    function getMemberStake(address account) external view returns (uint256) {
        return members[account].stakedAmount;
    }

    // Function to get all DAO members
    function getDAOMembers() external view returns (address[] memory) {
        return memberAddresses;
    }
}
