# Physical Reserve Registry Reference Implementation

This folder contains a minimal illustrative Solidity implementation for the proposed **Physical Reserve Registry ERC**.

The purpose of this implementation is to help reviewers understand the proposed reserve accounting model. It is not intended to be a production-ready contract.

## What This Implementation Demonstrates

The example shows how a physical reserve registry may support:

* reserve registration;
* reserve state changes;
* reserve quantity accounting;
* allocation of reserve quantity to an instrument;
* release of previously allocated reserve quantity;
* consumption of allocated reserve quantity;
* basic metadata/document references;
* basic endorsement records;
* optional ERC-721 reserve receipt mapping.

## Important Warning

This implementation is **illustrative only**.

It is not audited, not optimized, and not intended for production deployment. A production implementation would need stronger access control, governance, testing, upgrade policy, emergency handling, legal integration, and operational controls.

The ERC specification is authoritative. This implementation is only an example.

## Basic Flow

### 1. Register a reserve

```solidity
registerReserve(reserveId, assetId, quantity);
```

This creates a reserve in the `PENDING` state.

At this stage, the reserve exists in the registry but cannot yet be allocated as backing.

### 2. Optionally attach metadata or documents

```solidity
setReserveMetadataURI(reserveId, uri);
```

or:

```solidity
setReserveDocument(reserveId, documentType, documentHash, documentURI);
```

These functions can be used to reference off-chain documents such as custody records, vault records, audit reports, insurance documents, or legal terms.

### 3. Optionally record endorsements

An authorized endorser may call:

```solidity
endorseReserve(reserveId, endorsementType, endorsementHash, data);
```

Examples of endorsement types may include:

```solidity
keccak256("CUSTODY_CONFIRMATION");
keccak256("AUDIT_REPORT");
keccak256("INSURANCE_CONFIRMATION");
keccak256("REGULATORY_APPROVAL");
```

In this simple implementation, endorsements are recorded for transparency. They do not automatically activate the reserve unless the implementation adds that policy.

### 4. Activate the reserve

```solidity
setReserveState(reserveId, ReserveState.ACTIVE);
```

Once active, the reserve quantity becomes available for allocation.

### 5. Allocate reserve quantity to an instrument

```solidity
allocateReserve(reserveId, instrument, quantity, data);
```

The `instrument` may be a token contract, vault, issuer module, redemption module, or another address that uses reserve backing.

The `data` parameter is implementation-specific and may be empty. For a simple call, use:

```solidity
0x
```

After allocation:

```text
available quantity decreases
allocated quantity for the instrument increases
```

Allocation does not mean that tokens have been minted. Token issuance is handled by the instrument using the allocated reserve.

### 6. Release allocated quantity

```solidity
releaseReserve(reserveId, instrument, quantity, data);
```

Use this when allocated quantity should return to availability and the physical reserve remains eligible for future backing.

For example, if a reserve-backed token burns supply but the physical reserve remains in custody, the implementation may release some allocated quantity.

### 7. Consume allocated quantity

```solidity
consumeReserve(reserveId, instrument, quantity, data);
```

Use this when reserve quantity is permanently removed from future backing.

Examples include:

* physical redemption completed;
* physical delivery completed;
* reserve withdrawn from custody;
* reserve replaced or removed from backing;
* another final settlement event.

Consumption decreases allocated quantity and increases consumed quantity.

If the full reserve quantity is consumed, the reserve may become `CONSUMED`.

## Minimal Example Sequence

```solidity
registerReserve(reserveId, assetId, 1000);

setReserveState(reserveId, ReserveState.ACTIVE);

allocateReserve(reserveId, instrument, 400, "0x");

releaseReserve(reserveId, instrument, 100, "0x");

consumeReserve(reserveId, instrument, 200, "0x");
```

After this sequence:

```text
total reserve quantity = 1000
allocated to instrument = 100
released back to availability = 100
consumed = 200
remaining available quantity depends on the previous allocation/release state
```

## Reserve States

The example uses the following state model:

```solidity
enum ReserveState {
    NONE,
    PENDING,
    ACTIVE,
    SUSPENDED,
    CONSUMED,
    CANCELLED
}
```

Meaning:

* `NONE`: reserve does not exist or is unknown;
* `PENDING`: reserve exists but is not eligible for allocation;
* `ACTIVE`: reserve is eligible for allocation;
* `SUSPENDED`: reserve is temporarily ineligible for new allocation or reserve use;
* `CONSUMED`: reserve has been fully consumed and cannot be used for future backing;
* `CANCELLED`: reserve registration was cancelled, rejected, invalidated, or otherwise made permanently ineligible.

## Relationship to Reserve-Backed Tokens

A reserve-backed token may use this registry to check how much reserve quantity has been allocated to it.

For example, a later ERC-20 token extension may enforce:

```solidity
totalSupply() <= allocatedQuantity(assetId, address(this));
```

This reference implementation does not define a full token standard. It only demonstrates the reserve registry side.

## License

This reference implementation is provided under CC0-1.0 unless otherwise stated.
