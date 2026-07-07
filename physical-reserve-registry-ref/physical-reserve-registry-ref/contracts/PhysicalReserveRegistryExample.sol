// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {IERC165} from "./interfaces/IERC165.sol";
import {IERCPhysicalReserveRegistry} from "./interfaces/IERCPhysicalReserveRegistry.sol";
import {IERCPhysicalReserveAllocator} from "./interfaces/IERCPhysicalReserveAllocator.sol";
import {IERCPhysicalReserveEndorsement} from "./interfaces/IERCPhysicalReserveEndorsement.sol";
import {IERCPhysicalReserveMetadata} from "./interfaces/IERCPhysicalReserveMetadata.sol";
import {IERCPhysicalReserveReceipt721} from "./interfaces/IERCPhysicalReserveReceipt721.sol";

/// @notice Small example implementation for the Physical Reserve Registry ERC draft.
/// @dev This is an educational reference implementation, not production code.
contract PhysicalReserveRegistryExample is
    IERC165,
    IERCPhysicalReserveRegistry,
    IERCPhysicalReserveAllocator,
    IERCPhysicalReserveEndorsement,
    IERCPhysicalReserveMetadata,
    IERCPhysicalReserveReceipt721
{
    address public owner;
    mapping(address => bool) public operators;

    mapping(bytes32 => Reserve) private _reserves;
    mapping(bytes32 => uint256) private _activeByAsset;
    mapping(bytes32 => uint256) private _availableByAsset;
    mapping(bytes32 => uint256) private _consumedByAsset;

    mapping(bytes32 => mapping(address => uint256)) private _allocatedByReserveToInstrument;
    mapping(bytes32 => uint256) private _totalAllocatedByReserve;
    mapping(bytes32 => mapping(address => uint256)) private _allocatedByAssetToInstrument;
    mapping(bytes32 => uint256) private _totalAllocatedByAsset;

    mapping(bytes32 => string) private _metadataURI;
    mapping(bytes32 => mapping(bytes32 => bytes32)) private _documentHash;
    mapping(bytes32 => mapping(bytes32 => string)) private _documentURI;

    mapping(bytes32 => mapping(bytes32 => mapping(address => bool))) private _endorsed;
    mapping(bytes32 => mapping(bytes32 => mapping(address => bytes32))) private _latestEndorsementHash;
    mapping(bytes32 => mapping(bytes32 => uint256)) private _endorsementCount;
    mapping(bytes32 => mapping(bytes32 => uint256)) private _endorsementThreshold;
    mapping(bytes32 => string) private _endorsementPolicyURI;
    mapping(bytes32 => mapping(address => bool)) private _authorizedEndorserByType;

    struct ReceiptLink {
        address receiptContract;
        uint256 tokenId;
    }

    mapping(bytes32 => ReceiptLink) private _receiptOf;
    mapping(address => mapping(uint256 => bytes32)) private _reserveIdOf;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == owner || operators[msg.sender], "not operator");
        _;
    }

    modifier existingReserve(bytes32 reserveId) {
        require(_reserves[reserveId].state != ReserveState.NONE, "reserve not found");
        _;
    }

    constructor() {
        owner = msg.sender;
        operators[msg.sender] = true;
    }

    function setOperator(address account, bool allowed) external onlyOwner {
        operators[account] = allowed;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        owner = newOwner;
        operators[newOwner] = true;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERCPhysicalReserveRegistry).interfaceId ||
            interfaceId == type(IERCPhysicalReserveAllocator).interfaceId ||
            interfaceId == type(IERCPhysicalReserveEndorsement).interfaceId ||
            interfaceId == type(IERCPhysicalReserveMetadata).interfaceId ||
            interfaceId == type(IERCPhysicalReserveReceipt721).interfaceId;
    }

    function registerReserve(bytes32 reserveId, bytes32 assetId, uint256 quantity) external onlyOperator {
        require(_reserves[reserveId].state == ReserveState.NONE, "reserve exists");
        require(assetId != bytes32(0), "zero asset");
        require(quantity > 0, "zero quantity");

        _reserves[reserveId] = Reserve({
            reserveId: reserveId,
            assetId: assetId,
            quantity: quantity,
            availableQuantity: 0,
            consumedQuantity: 0,
            state: ReserveState.PENDING
        });

        emit ReserveRegistered(reserveId, assetId, quantity);
        emit ReserveStateChanged(reserveId, ReserveState.NONE, ReserveState.PENDING);
    }

    function setReserveState(bytes32 reserveId, ReserveState newState) external onlyOperator existingReserve(reserveId) {
        Reserve storage reserve = _reserves[reserveId];
        ReserveState previousState = reserve.state;
        require(previousState != newState, "same state");
        require(newState != ReserveState.NONE, "invalid state");

        if (previousState == ReserveState.ACTIVE) {
            uint256 previousActive = reserve.quantity - reserve.consumedQuantity;
            _activeByAsset[reserve.assetId] -= previousActive;
            _availableByAsset[reserve.assetId] -= reserve.availableQuantity;
            reserve.availableQuantity = 0;
        }

        reserve.state = newState;

        if (newState == ReserveState.ACTIVE) {
            uint256 remaining = reserve.quantity - reserve.consumedQuantity;
            uint256 allocated = _totalAllocatedByReserve[reserveId];
            require(remaining >= allocated, "allocated exceeds remaining");
            reserve.availableQuantity = remaining - allocated;
            _activeByAsset[reserve.assetId] += remaining;
            _availableByAsset[reserve.assetId] += reserve.availableQuantity;
        }

        if (newState == ReserveState.CONSUMED || newState == ReserveState.CANCELLED) {
            require(_totalAllocatedByReserve[reserveId] == 0, "allocated remains");
            reserve.availableQuantity = 0;
        }

        emit ReserveStateChanged(reserveId, previousState, newState);
    }

    function updateReserveQuantity(bytes32 reserveId, uint256 newQuantity) external onlyOperator existingReserve(reserveId) {
        Reserve storage reserve = _reserves[reserveId];
        require(reserve.state != ReserveState.ACTIVE, "deactivate first");
        require(newQuantity >= reserve.consumedQuantity + _totalAllocatedByReserve[reserveId], "too small");
        uint256 oldQuantity = reserve.quantity;
        reserve.quantity = newQuantity;
        emit ReserveQuantityUpdated(reserveId, oldQuantity, newQuantity);
    }

    function allocateReserve(bytes32 reserveId, address instrument, uint256 quantity, bytes calldata) external override onlyOperator existingReserve(reserveId) {
        Reserve storage reserve = _reserves[reserveId];
        require(reserve.state == ReserveState.ACTIVE, "not active");
        require(instrument != address(0), "zero instrument");
        require(quantity > 0, "zero quantity");
        require(reserve.availableQuantity >= quantity, "insufficient available");

        reserve.availableQuantity -= quantity;
        _availableByAsset[reserve.assetId] -= quantity;
        _allocatedByReserveToInstrument[reserveId][instrument] += quantity;
        _allocatedByAssetToInstrument[reserve.assetId][instrument] += quantity;
        _totalAllocatedByReserve[reserveId] += quantity;
        _totalAllocatedByAsset[reserve.assetId] += quantity;

        emit ReserveAllocated(reserveId, instrument, quantity);
    }

    function releaseReserve(bytes32 reserveId, address instrument, uint256 quantity, bytes calldata) external override onlyOperator existingReserve(reserveId) {
        Reserve storage reserve = _reserves[reserveId];
        require(quantity > 0, "zero quantity");
        require(_allocatedByReserveToInstrument[reserveId][instrument] >= quantity, "insufficient allocated");

        _allocatedByReserveToInstrument[reserveId][instrument] -= quantity;
        _allocatedByAssetToInstrument[reserve.assetId][instrument] -= quantity;
        _totalAllocatedByReserve[reserveId] -= quantity;
        _totalAllocatedByAsset[reserve.assetId] -= quantity;

        if (reserve.state == ReserveState.ACTIVE) {
            reserve.availableQuantity += quantity;
            _availableByAsset[reserve.assetId] += quantity;
        }

        emit ReserveReleased(reserveId, instrument, quantity);
    }

    function consumeReserve(bytes32 reserveId, address instrument, uint256 quantity, bytes calldata) external override onlyOperator existingReserve(reserveId) {
        Reserve storage reserve = _reserves[reserveId];
        require(quantity > 0, "zero quantity");
        require(_allocatedByReserveToInstrument[reserveId][instrument] >= quantity, "insufficient allocated");

        _allocatedByReserveToInstrument[reserveId][instrument] -= quantity;
        _allocatedByAssetToInstrument[reserve.assetId][instrument] -= quantity;
        _totalAllocatedByReserve[reserveId] -= quantity;
        _totalAllocatedByAsset[reserve.assetId] -= quantity;
        reserve.consumedQuantity += quantity;
        _consumedByAsset[reserve.assetId] += quantity;

        if (reserve.state == ReserveState.ACTIVE) {
            _activeByAsset[reserve.assetId] -= quantity;
        }

        if (reserve.consumedQuantity == reserve.quantity) {
            ReserveState oldState = reserve.state;
            reserve.state = ReserveState.CONSUMED;
            reserve.availableQuantity = 0;
            emit ReserveStateChanged(reserveId, oldState, ReserveState.CONSUMED);
        }

        emit ReserveConsumed(reserveId, instrument, quantity);
    }

    function setAuthorizedEndorser(bytes32 endorsementType, address endorser, bool allowed) external onlyOwner {
        _authorizedEndorserByType[endorsementType][endorser] = allowed;
    }

    function setEndorsementThreshold(bytes32 reserveId, bytes32 endorsementType, uint256 threshold) external onlyOperator existingReserve(reserveId) {
        _endorsementThreshold[reserveId][endorsementType] = threshold;
    }

    function setEndorsementPolicyURI(bytes32 reserveId, string calldata uri) external onlyOperator existingReserve(reserveId) {
        _endorsementPolicyURI[reserveId] = uri;
    }

    function endorseReserve(bytes32 reserveId, bytes32 endorsementType, bytes32 endorsementHash, bytes calldata) external override existingReserve(reserveId) {
        require(canEndorse(reserveId, msg.sender, endorsementType), "not authorized");
        require(!_endorsed[reserveId][endorsementType][msg.sender], "already endorsed");
        _endorsed[reserveId][endorsementType][msg.sender] = true;
        _latestEndorsementHash[reserveId][endorsementType][msg.sender] = endorsementHash;
        _endorsementCount[reserveId][endorsementType] += 1;
        emit ReserveEndorsed(reserveId, msg.sender, endorsementType, endorsementHash);
    }

    function revokeEndorsement(bytes32 reserveId, bytes32 endorsementType, bytes calldata) external override existingReserve(reserveId) {
        require(_endorsed[reserveId][endorsementType][msg.sender], "not endorsed");
        _endorsed[reserveId][endorsementType][msg.sender] = false;
        _latestEndorsementHash[reserveId][endorsementType][msg.sender] = bytes32(0);
        _endorsementCount[reserveId][endorsementType] -= 1;
        emit ReserveEndorsementRevoked(reserveId, msg.sender, endorsementType);
    }

    function setReserveMetadataURI(bytes32 reserveId, string calldata uri) external onlyOperator existingReserve(reserveId) {
        _metadataURI[reserveId] = uri;
        emit ReserveMetadataURIUpdated(reserveId, uri);
    }

    function setReserveDocument(bytes32 reserveId, bytes32 documentType, bytes32 hash, string calldata uri) external onlyOperator existingReserve(reserveId) {
        _documentHash[reserveId][documentType] = hash;
        _documentURI[reserveId][documentType] = uri;
        emit ReserveDocumentUpdated(reserveId, documentType, hash, uri);
    }

    function linkReceipt(bytes32 reserveId, address receiptContract, uint256 tokenId) external onlyOperator existingReserve(reserveId) {
        require(receiptContract != address(0), "zero receipt");
        _receiptOf[reserveId] = ReceiptLink(receiptContract, tokenId);
        _reserveIdOf[receiptContract][tokenId] = reserveId;
        emit ReserveReceiptLinked(reserveId, receiptContract, tokenId);
    }

    function unlinkReceipt(bytes32 reserveId) external onlyOperator existingReserve(reserveId) {
        ReceiptLink memory link = _receiptOf[reserveId];
        require(link.receiptContract != address(0), "no receipt");
        delete _receiptOf[reserveId];
        delete _reserveIdOf[link.receiptContract][link.tokenId];
        emit ReserveReceiptUnlinked(reserveId, link.receiptContract, link.tokenId);
    }

    function reserveOf(bytes32 reserveId) external view override returns (Reserve memory) { return _reserves[reserveId]; }
    function stateOf(bytes32 reserveId) external view override returns (ReserveState) { return _reserves[reserveId].state; }
    function assetIdOf(bytes32 reserveId) external view override returns (bytes32) { return _reserves[reserveId].assetId; }
    function quantityOf(bytes32 reserveId) external view override returns (uint256) { return _reserves[reserveId].quantity; }
    function availableQuantityOf(bytes32 reserveId) external view override returns (uint256) { return _reserves[reserveId].availableQuantity; }
    function consumedQuantityOf(bytes32 reserveId) external view override returns (uint256) { return _reserves[reserveId].consumedQuantity; }
    function activeQuantity(bytes32 assetId) external view override returns (uint256) { return _activeByAsset[assetId]; }
    function availableQuantity(bytes32 assetId) external view override returns (uint256) { return _availableByAsset[assetId]; }
    function consumedQuantity(bytes32 assetId) external view override returns (uint256) { return _consumedByAsset[assetId]; }
    function allocatedQuantityOf(bytes32 reserveId, address instrument) external view override returns (uint256) { return _allocatedByReserveToInstrument[reserveId][instrument]; }
    function allocatedQuantity(bytes32 assetId, address instrument) external view override returns (uint256) { return _allocatedByAssetToInstrument[assetId][instrument]; }
    function totalAllocatedQuantityOf(bytes32 reserveId) external view override returns (uint256) { return _totalAllocatedByReserve[reserveId]; }
    function totalAllocatedQuantity(bytes32 assetId) external view override returns (uint256) { return _totalAllocatedByAsset[assetId]; }
    function endorsementCount(bytes32 reserveId, bytes32 endorsementType) external view override returns (uint256) { return _endorsementCount[reserveId][endorsementType]; }
    function isEndorsedBy(bytes32 reserveId, address endorser, bytes32 endorsementType) external view override returns (bool) { return _endorsed[reserveId][endorsementType][endorser]; }
    function latestEndorsementHash(bytes32 reserveId, address endorser, bytes32 endorsementType) external view override returns (bytes32) { return _latestEndorsementHash[reserveId][endorsementType][endorser]; }
    function canEndorse(bytes32, address endorser, bytes32 endorsementType) public view override returns (bool) { return _authorizedEndorserByType[endorsementType][endorser]; }
    function endorsementThreshold(bytes32 reserveId, bytes32 endorsementType) external view override returns (uint256) { return _endorsementThreshold[reserveId][endorsementType]; }
    function endorsementPolicyURI(bytes32 reserveId) external view override returns (string memory) { return _endorsementPolicyURI[reserveId]; }
    function reserveMetadataURI(bytes32 reserveId) external view override returns (string memory) { return _metadataURI[reserveId]; }
    function reserveDocument(bytes32 reserveId, bytes32 documentType) external view override returns (bytes32, string memory) { return (_documentHash[reserveId][documentType], _documentURI[reserveId][documentType]); }
    function receiptOf(bytes32 reserveId) external view override returns (address, uint256) { ReceiptLink memory link = _receiptOf[reserveId]; return (link.receiptContract, link.tokenId); }
    function reserveIdOf(address receiptContract, uint256 tokenId) external view override returns (bytes32) { return _reserveIdOf[receiptContract][tokenId]; }
}
