# Research Grant System (Upgradeable Smart Contract)

A decentralized and upgradeable smart contract system designed to streamline academic research funding. This system enables researchers to submit proposals, reviewers to score them, and funds to be allocated transparently based on verified scoring and DAO governance.

---

##  Overview

This project provides:

- ✅ **UUPS upgradeable** grant management contract  
- ✅ **IPFS-powered proposal & review storage**  
- ✅ **DAO-based reviewer reputation system**  
- ✅ **Secure ETH pool & grant disbursement**  
- ✅ **Transparent proposal scoring and funding criteria**  

Researchers upload proposals via IPFS, reviewers submit evaluations, and high-scoring proposals receive funding from a pooled treasury.

---

##  Features

| Category | Description |
|---------|-------------|
Proposal Submission | Researchers submit proposals stored via IPFS  
Peer Review | Registered reviewers submit scores (0–100) + review hash  
Reputation System | DAO members score reviewer credibility  
Upgradeable Architecture | UUPS pattern powered by OpenZeppelin  
Secure Fund Handling | Reentrancy-safe ETH transfers to researchers  
Governance | DAO controls reviewer credibility & system upgrades  

---

##  Contract Workflow

1. DAO initializes contract and registers reviewers  
2. Researchers submit proposals with metadata on IPFS  
3. Reviewers score proposals & upload review hash  
4. DAO members rate reviewer credibility  
5. Proposals crossing score threshold get funded  
6. Contract sends ETH securely to researcher 
