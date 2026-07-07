// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IERCPhysicalReserveAllocator {
    event ReserveAllocated(bytes32 indexed reserveId, address indexed instrument, uint256 quantity);
    event ReserveReleased(bytes32 indexed reserveId, address indexed instrument, uint256 quantity);
    event ReserveConsumed(bytes32 indexed reserveId, address indexed instrument, uint256 quantity);

    function allocatedQuantityOf(bytes32 reserveId, address instrument) external view returns (uint256 quantity);
    function allocatedQuantity(bytes32 assetId, address instrument) external view returns (uint256 quantity);
    function totalAllocatedQuantityOf(bytes32 reserveId) external view returns (uint256 quantity);
    function totalAllocatedQuantity(bytes32 assetId) external view returns (uint256 quantity);

    function allocateReserve(bytes32 reserveId, address instrument, uint256 quantity, bytes calldata data) external;
    function releaseReserve(bytes32 reserveId, address instrument, uint256 quantity, bytes calldata data) external;
    function consumeReserve(bytes32 reserveId, address instrument, uint256 quantity, bytes calldata data) external;
}
