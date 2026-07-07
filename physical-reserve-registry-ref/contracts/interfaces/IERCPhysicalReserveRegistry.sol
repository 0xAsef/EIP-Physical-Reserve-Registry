// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IERCPhysicalReserveRegistry {
    enum ReserveState {
        NONE,
        PENDING,
        ACTIVE,
        SUSPENDED,
        CONSUMED,
        CANCELLED
    }

    struct Reserve {
        bytes32 reserveId;
        bytes32 assetId;
        uint256 quantity;
        uint256 availableQuantity;
        uint256 consumedQuantity;
        ReserveState state;
    }

    event ReserveRegistered(bytes32 indexed reserveId, bytes32 indexed assetId, uint256 quantity);
    event ReserveStateChanged(bytes32 indexed reserveId, ReserveState previousState, ReserveState newState);
    event ReserveQuantityUpdated(bytes32 indexed reserveId, uint256 previousQuantity, uint256 newQuantity);

    function reserveOf(bytes32 reserveId) external view returns (Reserve memory reserve);
    function stateOf(bytes32 reserveId) external view returns (ReserveState state);
    function assetIdOf(bytes32 reserveId) external view returns (bytes32 assetId);
    function quantityOf(bytes32 reserveId) external view returns (uint256 quantity);
    function availableQuantityOf(bytes32 reserveId) external view returns (uint256 quantity);
    function consumedQuantityOf(bytes32 reserveId) external view returns (uint256 quantity);
    function activeQuantity(bytes32 assetId) external view returns (uint256 quantity);
    function availableQuantity(bytes32 assetId) external view returns (uint256 quantity);
    function consumedQuantity(bytes32 assetId) external view returns (uint256 quantity);
}
