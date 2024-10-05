// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library SignatureVerifier {
    // Function to verify signatures
    function verifySignature(
        address signer,
        bytes memory data,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 hash = keccak256(data);
        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        address recoveredSigner = ECDSA.recover(messageHash, signature);
        return recoveredSigner == signer;
    }
}
