// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title DeFiTimelock — 2-day delay timelock for DAO
contract DeFiTimelock is TimelockController {
    constructor(
        address[] memory proposers,
        address[] memory executors,
        address admin
    )
        TimelockController(
            2 days,      // minDelay
            proposers,
            executors,
            admin
        )
    {}
}