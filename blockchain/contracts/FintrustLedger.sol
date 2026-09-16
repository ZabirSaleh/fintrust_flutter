// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract FintrustLedger {
    address public owner;

    struct Proof {
        string transactionId;
        bytes32 transactionHash;
        bytes32 previousHash;
        uint256 blockIndex;
        uint256 timestamp;
    }

    mapping(string => Proof) public proofs;
    string[] public transactionIds;

    event ProofAnchored(
        string transactionId,
        bytes32 transactionHash,
        bytes32 previousHash,
        uint256 blockIndex,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function anchorProof(
        string calldata transactionId,
        bytes32 transactionHash,
        bytes32 previousHash,
        uint256 blockIndex
    ) external onlyOwner {
        require(proofs[transactionId].timestamp == 0, "Already anchored");

        proofs[transactionId] = Proof(
            transactionId,
            transactionHash,
            previousHash,
            blockIndex,
            block.timestamp
        );

        transactionIds.push(transactionId);

        emit ProofAnchored(
            transactionId,
            transactionHash,
            previousHash,
            blockIndex,
            block.timestamp
        );
    }

    function getProofCount() external view returns (uint256) {
        return transactionIds.length;
    }
}
