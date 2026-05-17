// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/factories/AMMFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract AMMFactoryTest is Test {
    AMMFactory factory;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;

    function setUp() public {
        factory = new AMMFactory();
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        tokenC = new MockERC20("Token C", "TKC");
    }

    function test_CreatePool() public {
        address pool = factory.createPool(address(tokenA), address(tokenB));
        assertNotEq(pool, address(0));
    }

    function test_CreatePool_Stored() public {
        address pool = factory.createPool(address(tokenA), address(tokenB));
        assertEq(factory.getPool(address(tokenA), address(tokenB)), pool);
        assertEq(factory.getPool(address(tokenB), address(tokenA)), pool);
    }

    function test_CreatePool_IdenticalTokens_Reverts() public {
        vm.expectRevert("Factory: identical tokens");
        factory.createPool(address(tokenA), address(tokenA));
    }

    function test_CreatePool_ZeroAddress_Reverts() public {
        vm.expectRevert("Factory: zero address");
        factory.createPool(address(0), address(tokenB));
    }

    function test_CreatePool_Duplicate_Reverts() public {
        factory.createPool(address(tokenA), address(tokenB));
        vm.expectRevert("Factory: pool exists");
        factory.createPool(address(tokenA), address(tokenB));
    }

    function test_CreatePool2() public {
        bytes32 salt = keccak256("salt1");
        address pool = factory.createPool2(address(tokenA), address(tokenB), salt);
        assertNotEq(pool, address(0));
    }

    function test_PredictAddress() public {
        bytes32 salt = keccak256("salt2");
        address predicted = factory.predictAddress(address(tokenA), address(tokenB), salt);
        address pool = factory.createPool2(address(tokenA), address(tokenB), salt);
        assertEq(predicted, pool);
    }

    function test_AllPoolsLength() public {
        factory.createPool(address(tokenA), address(tokenB));
        factory.createPool(address(tokenA), address(tokenC));
        assertEq(factory.allPoolsLength(), 2);
    }

    function test_AllPools() public {
        address pool1 = factory.createPool(address(tokenA), address(tokenB));
        address pool2 = factory.createPool(address(tokenA), address(tokenC));
        assertEq(factory.allPools(0), pool1);
        assertEq(factory.allPools(1), pool2);
    }
}