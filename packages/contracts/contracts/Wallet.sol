// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@account-abstraction/contracts/samples/SimpleAccount.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract Wallet is ERC165, IERC1271, SimpleAccount {
    constructor(
        IEntryPoint anEntryPoint,
        address anOwner
    ) SimpleAccount(anEntryPoint) {
        initialize(anOwner);
    }

    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view override returns (bytes4) {
        address recovered = ECDSA.recover(_hash, _signature);
        if (recovered == owner) {
            return type(IERC1271).interfaceId;
        } else {
            return 0xffffffff;
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC165, TokenCallbackHandler)
        returns (bool)
    {
        return
            interfaceId == type(IERC1271).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
