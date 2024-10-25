// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library SignatureVerifier {
    function verifySignature(address signer, bytes32 hash, bytes memory signature) internal pure returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        return recoverSigner(messageHash, signature) == signer;
    }

    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid signature 'v' value");

        return ecrecover(hash, v, r, s);
    }
}
