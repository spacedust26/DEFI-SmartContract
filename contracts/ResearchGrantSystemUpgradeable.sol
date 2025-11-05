// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

/*
 * Upgradeable Research Grant System
 * ---------------------------------
 * This contract manages a decentralized research grant process using
 * DAO members and registered reviewers. Researchers submit proposals,
 * reviewers submit reviews and scores, and funds are released based on ratings.
 *
 * Features:
 * - UUPS upgradeable contract pattern (OpenZeppelin)
 * - Decentralized voting + scoring on proposals
 * - DAO governance for reviewer reputation scoring
 * - Secure ETH funding and payout to winning researchers
 */

import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v5.0/contracts/proxy/utils/UUPSUpgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v5.0/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract ResearchGrantSystemUpgradeable is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    /* ------------------------------------------------------------------------
       DATA STRUCTURES
    ------------------------------------------------------------------------ */

    /// @notice Represents a research proposal stored by IPFS hash
    struct Proposal {
        string title;
        string ipfsHash;
        string principalInvestigator;
        string orcid;
        string institution;
        uint256 budget;
        address payable researcher;
        uint256 totalScore;     // Sum of all review scores
        uint256 reviewCount;    // Number of reviews received
        bool funded;            // Funding status flag
    }

    /// @notice Represents a review submitted by a reviewer
    struct Review {
        string proposalIpfsHash; // Linked proposal (IPFS)
        string reviewIpfsHash;   // IPFS location of review report
        uint256 score;           // Numeric rating (0–100)
        address reviewer;
    }

    /// @notice Represents a reviewer profile and reputation score
    struct Reviewer {
        uint256 creditScore; // Honesty / performance score
        bool registered;
    }

    /* ------------------------------------------------------------------------
       STATE VARIABLES
    ------------------------------------------------------------------------ */

    address public deployer; // Original deployer of the contract
    uint256 public totalFunds; // Grants liquidity pool

    // Proposal storage keyed by proposal IPFS hash
    mapping(string => Proposal) public proposals;

    // Reviewer registry and reputation tracking
    mapping(address => Reviewer) public reviewers;

    // Track reviews per reviewer
    mapping(address => Review[]) public reviewerReviews;

    // DAO member mapping for governance
    mapping(address => bool) public daoMembers;

    // List of proposal hashes for indexing
    string[] public proposalList;

    /* ------------------------------------------------------------------------
       EVENTS
    ------------------------------------------------------------------------ */

    event FundsDeposited(address indexed contributor, uint256 amount);
    event ProposalSubmitted(address indexed researcher, string ipfsHash);
    event ProposalVoted(address indexed reviewer, string ipfsHash, uint256 score);
    event ReviewerVoted(address indexed daoMember, address reviewer, uint256 vote);
    event FundsAllocated(address indexed researcher, uint256 amount);

    /* ------------------------------------------------------------------------
       MODIFIERS
    ------------------------------------------------------------------------ */

    /// @dev Restricts access to DAO members only
    modifier onlyDAO() {
        require(daoMembers[msg.sender], "Not a DAO member");
        _;
    }

    /* ------------------------------------------------------------------------
       UUPS UPGRADE HOOK
    ------------------------------------------------------------------------ */

    /**
     * @dev UUPS upgrade authorization. Only owner can upgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /* ------------------------------------------------------------------------
       INITIALIZATION (instead of constructor for upgradeable contracts)
    ------------------------------------------------------------------------ */

    /**
     * @notice Initializes contract after deployment (UUPS pattern)
     * @param _daoMembers Initial DAO member wallet addresses
     */
    function initialize(address[] memory _daoMembers) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        deployer = msg.sender;

        // Grant DAO permissions
        for (uint256 i = 0; i < _daoMembers.length; i++) {
            daoMembers[_daoMembers[i]] = true;
        }
    }

    /* ------------------------------------------------------------------------
       FUNDING MECHANISM
    ------------------------------------------------------------------------ */

    /**
     * @notice Deposits ETH into grant pool
     */
    function depositFunds() external payable {
        require(msg.value > 0, "Zero deposit not allowed");
        totalFunds += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    /* ------------------------------------------------------------------------
       PROPOSAL MANAGEMENT
    ------------------------------------------------------------------------ */

    /**
     * @notice Submit a proposal for funding
     */
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

    /**
     * @notice View a proposal by its IPFS hash
     */
    function retrieveProposal(string memory _ipfsHash)
        external
        view
        returns (Proposal memory)
    {
        return proposals[_ipfsHash];
    }

    /* ------------------------------------------------------------------------
       REVIEWING & VOTING
    ------------------------------------------------------------------------ */

    /**
     * @notice Review and score a proposal
     * @param _proposalIpfs Proposal identifier (IPFS hash)
     * @param _reviewIpfs Review file IPFS hash
     * @param _score Score (0-100)
     */
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

    /// @notice Retrieve all reviews by a reviewer
    function retrieveReviews(address reviewer)
        external
        view
        returns (Review[] memory)
    {
        return reviewerReviews[reviewer];
    }

    /**
     * @notice DAO members vote on reviewer credibility
     * @dev Simple average update `(old + new) / 2`
     */
    function voteReviewer(address reviewer, uint256 vote) external onlyDAO {
        require(vote <= 100, "Invalid vote");
        reviewers[reviewer].creditScore =
            (reviewers[reviewer].creditScore + vote) / 2;
        emit ReviewerVoted(msg.sender, reviewer, vote);
    }

    /* ------------------------------------------------------------------------
       FUND ALLOCATION
    ------------------------------------------------------------------------ */

    /**
     * @notice Allocate funds to a winning proposal if criteria met
     * @dev Score threshold: >= 75 average rating
     */
    function allocateFunds(string memory _ipfsHash) external nonReentrant onlyOwner {
        Proposal storage p = proposals[_ipfsHash];

        require(p.researcher != address(0), "Zero address");
        require(!p.funded, "Already funded");
        require(p.reviewCount > 0, "No reviews");

        // Calculate average safely (scaled to avoid precision loss)
        require((p.totalScore * 1e18 / p.reviewCount) >= 75e18, "Low score");
        require(totalFunds >= p.budget, "Insufficient funds");

        totalFunds -= p.budget;
        p.funded = true;

        (bool sent, ) = p.researcher.call{value: p.budget}("");
        require(sent, "Transfer failed");

        emit FundsAllocated(p.researcher, p.budget);
    }

    /* ------------------------------------------------------------------------
       REVIEWER REGISTRATION
    ------------------------------------------------------------------------ */

    /**
     * @notice Register a new reviewer (only owner)
     */
    function registerReviewer(address reviewer) external onlyOwner {
        reviewers[reviewer] = Reviewer({creditScore: 50, registered: true});
    }
}

