// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract ResearchGrantSystemUpgradeable is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    struct Proposal {
        string title;
        string ipfsHash;
        string principalInvestigator;
        string orcid;
        string institution;
        uint256 budget;
        address payable researcher;
        uint256 totalScore;
        uint256 reviewCount;
        bool funded;
    }

    struct Review {
        string proposalIpfsHash;
        string reviewIpfsHash;
        uint256 score;
        address reviewer;
    }

    struct Reviewer {
        uint256 creditScore;
        bool registered;
    }

    address public deployer;
    uint256 public totalFunds;

    mapping(string => Proposal) public proposals;
    mapping(address => Reviewer) public reviewers;
    mapping(address => Review[]) public reviewerReviews;
    mapping(address => bool) public daoMembers;

    string[] public proposalList;

    event FundsDeposited(address indexed contributor, uint256 amount);
    event ProposalSubmitted(address indexed researcher, string ipfsHash);
    event ProposalVoted(address indexed reviewer, string ipfsHash, uint256 score);
    event ReviewerVoted(address indexed daoMember, address reviewer, uint256 vote);
    event FundsAllocated(address indexed researcher, uint256 amount);

    modifier onlyDAO() {
        require(daoMembers[msg.sender], "Not a DAO member");
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address[] memory _daoMembers) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        deployer = msg.sender;
        for (uint256 i = 0; i < _daoMembers.length; i++) {
            daoMembers[_daoMembers[i]] = true;
        }
    }

    function depositFunds() external payable {
        require(msg.value > 0, "Zero deposit not allowed");
        totalFunds += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function submitProposal(
        string memory _ipfsHash,
        string memory _title,
        string memory _pi,
        string memory _orcid,
        string memory _institution,
        uint256 _budget
    ) external {
        require(proposals[_ipfsHash].researcher == address(0), "Proposal already exists");

        proposals[_ipfsHash] = Proposal({
            title: _title,
            ipfsHash: _ipfsHash,
            principalInvestigator: _pi,
            orcid: _orcid,
            institution: _institution,
            budget: _budget,
            researcher: payable(msg.sender),
            totalScore: 0,
            reviewCount: 0,
            funded: false
        });
        proposalList.push(_ipfsHash);
        emit ProposalSubmitted(msg.sender, _ipfsHash);
    }

    function retrieveProposal(string memory _ipfsHash)
        external
        view
        returns (Proposal memory)
    {
        return proposals[_ipfsHash];
    }

    function voteProposal(
        string memory _proposalIpfs,
        string memory _reviewIpfs,
        uint256 _score
    ) external {
        require(reviewers[msg.sender].registered, "Not a registered reviewer");
        require(_score <= 100, "Invalid score");

        Proposal storage p = proposals[_proposalIpfs];
        require(p.researcher != address(0), "Proposal not found");

        reviewerReviews[msg.sender].push(
            Review(_proposalIpfs, _reviewIpfs, _score, msg.sender)
        );

        p.totalScore += _score;
        p.reviewCount += 1;
        emit ProposalVoted(msg.sender, _proposalIpfs, _score);
    }

    function retrieveReviews(address reviewer)
        external
        view
        returns (Review[] memory)
    {
        return reviewerReviews[reviewer];
    }

    function voteReviewer(address reviewer, uint256 vote) external onlyDAO {
        require(vote <= 100, "Invalid vote");
        reviewers[reviewer].creditScore =
            (reviewers[reviewer].creditScore + vote) /
            2;
        emit ReviewerVoted(msg.sender, reviewer, vote);
    }

    function allocateFunds(string memory _ipfsHash) external nonReentrant onlyOwner {
        Proposal storage p = proposals[_ipfsHash];
        require(p.researcher != address(0), "Zero address");
        require(!p.funded, "Already funded");
        require(p.reviewCount > 0, "No reviews");
        // Scaled arithmetic to avoid truncation
        require((p.totalScore * 1e18 / p.reviewCount) >= 75e18, "Low score");
        require(totalFunds >= p.budget, "Insufficient funds");

        totalFunds -= p.budget;
        p.funded = true;
        (bool sent, ) = p.researcher.call{value: p.budget}("");
        require(sent, "Transfer failed");
        emit FundsAllocated(p.researcher, p.budget);
    }

    function registerReviewer(address reviewer) external onlyOwner {
        reviewers[reviewer] = Reviewer({creditScore: 50, registered: true});
    }
}
