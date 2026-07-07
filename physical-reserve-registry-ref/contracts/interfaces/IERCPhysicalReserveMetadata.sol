// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IERCPhysicalReserveMetadata {
    event ReserveMetadataURIUpdated(bytes32 indexed reserveId, string metadataURI);
    event ReserveDocumentUpdated(bytes32 indexed reserveId, bytes32 indexed documentType, bytes32 documentHash, string documentURI);

    function reserveMetadataURI(bytes32 reserveId) external view returns (string memory uri);
    function reserveDocument(bytes32 reserveId, bytes32 documentType) external view returns (bytes32 documentHash, string memory documentURI);
}
