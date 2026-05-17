// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/AMM.sol";

/// @title AMMFactory — deploys AMM pools via CREATE and CREATE2
contract AMMFactory {
    address[] public allPools;
    mapping(address => mapping(address => address)) public getPool;

    event PoolCreated(address indexed tokenA, address indexed tokenB, address pool);

    /// @notice Deploy pool with CREATE
    function createPool(address tokenA, address tokenB)
        external returns (address pool)
    {
        require(tokenA != tokenB, "Factory: identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Factory: zero address");
        require(getPool[tokenA][tokenB] == address(0), "Factory: pool exists");

        // CREATE
        pool = address(new AMM(tokenA, tokenB));

        getPool[tokenA][tokenB] = pool;
        getPool[tokenB][tokenA] = pool;
        allPools.push(pool);

        emit PoolCreated(tokenA, tokenB, pool);
    }

    /// @notice Deploy pool with CREATE2 (deterministic address)
    function createPool2(address tokenA, address tokenB, bytes32 salt)
        external returns (address pool)
    {
        require(tokenA != tokenB, "Factory: identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Factory: zero address");
        require(getPool[tokenA][tokenB] == address(0), "Factory: pool exists");

        // CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(AMM).creationCode,
            abi.encode(tokenA, tokenB)
        );
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(pool != address(0), "Factory: deployment failed");

        getPool[tokenA][tokenB] = pool;
        getPool[tokenB][tokenA] = pool;
        allPools.push(pool);

        emit PoolCreated(tokenA, tokenB, pool);
    }

    /// @notice Predict CREATE2 address before deployment
    function predictAddress(address tokenA, address tokenB, bytes32 salt)
        external view returns (address)
    {
        bytes memory bytecode = abi.encodePacked(
            type(AMM).creationCode,
            abi.encode(tokenA, tokenB)
        );
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }

    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }
}