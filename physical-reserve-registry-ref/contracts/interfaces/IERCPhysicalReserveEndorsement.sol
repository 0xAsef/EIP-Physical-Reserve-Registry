// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IERCPhysicalReserveEndorsement {
    event ReserveEndorsed(bytes32 indexed reserveId, address indexed endorser, bytes32 indexed endorsementType, bytes32 endorsementHash);
    event ReserveEndorsementRevoked(bytes32 indexed reserveId, address indexed endorser, bytes32 indexed endorsementType);

    function endorsementCount(bytes32 reserveId, bytes32 endorsementType) external view returns (uint256 count);
    function isEndorsedBy(bytes32 reserveId, address endorser, bytes32 endorsementType) external view returns (bool);
    function latestEndorsementHash(bytes32 reserveId, address endorser, bytes32 endorsementType) external view returns (bytes32 endorsementHash);
    function canEndorse(bytes32 reserveId, address endorser, bytes32 endorsementType) external view returns (bool);
    function endorsementThreshold(bytes32 reserveId, bytes32 endorsementType) external view returns (uint256 threshold);
    function endorsementPolicyURI(bytes32 reserveId) external view returns (string memory uri);

    function endorseReserve(bytes32 reserveId, bytes32 endorsementType, bytes32 endorsementHash, bytes calldata data) external;
    function revokeEndorsement(bytes32 reserveId, bytes32 endorsementType, bytes calldata data) external;
}
