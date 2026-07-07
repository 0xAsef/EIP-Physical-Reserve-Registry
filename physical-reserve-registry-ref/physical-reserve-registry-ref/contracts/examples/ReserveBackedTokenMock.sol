// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IReserveAllocatorView {
    function allocatedQuantity(bytes32 assetId, address instrument) external view returns (uint256 quantity);
}

/// @notice Minimal ERC-20-like example showing how a later reserve-backed token could read allocation.
/// @dev This is NOT part of the ERC-A standard. It is only a usage example.
contract ReserveBackedTokenMock {
    string public name = "Example Reserve Backed Token";
    string public symbol = "ERBT";
    uint8 public decimals = 0;

    address public owner;
    IReserveAllocatorView public reserveRegistry;
    bytes32 public assetId;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address registry_, bytes32 assetId_) {
        owner = msg.sender;
        reserveRegistry = IReserveAllocatorView(registry_);
        assetId = assetId_;
    }

    function allocatedReserve() public view returns (uint256) {
        return reserveRegistry.allocatedQuantity(assetId, address(this));
    }

    function availableToMint() public view returns (uint256) {
        uint256 allocated = allocatedReserve();
        return allocated > totalSupply ? allocated - totalSupply : 0;
    }

    function mintBacked(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero to");
        require(totalSupply + amount <= allocatedReserve(), "exceeds allocated reserve");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "zero to");
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(to != address(0), "zero to");
        require(balanceOf[from] >= amount, "insufficient balance");
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
