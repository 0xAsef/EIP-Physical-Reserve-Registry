// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IERCPhysicalReserveReceipt721 {
    event ReserveReceiptLinked(bytes32 indexed reserveId, address indexed receiptContract, uint256 indexed tokenId);
    event ReserveReceiptUnlinked(bytes32 indexed reserveId, address indexed receiptContract, uint256 indexed tokenId);

    function receiptOf(bytes32 reserveId) external view returns (address receiptContract, uint256 tokenId);
    function reserveIdOf(address receiptContract, uint256 tokenId) external view returns (bytes32 reserveId);
}
