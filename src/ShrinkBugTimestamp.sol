// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Minimal reproducer: Echidna removeReverts block.timestamp bug
///
/// Same root cause as ShrinkBug.sol but for block.timestamp instead of
/// block.number. `put vmBeforeTx` rolls back BOTH block.number and
/// block.timestamp for reverting calls. NoCall preserves both advances.
///
/// See ShrinkBug.sol for full explanation of the root cause.
contract ShrinkBugTimestamp {
    uint256 public balance;

    /// @dev Reverts for amounts < 10. When this reverts, the original Echidna
    /// execution rolls back both block.number AND block.timestamp advances.
    /// After removeReverts converts to NoCall, both advances stick.
    function fuzz_deposit(uint256 amount) external {
        require(amount >= 10, "too small");
        balance += amount;
    }

    /// @dev Uses block.timestamp-dependent RNG. The exact timestamp determines
    /// the hash. After removeReverts inflates block.timestamp, the hash changes
    /// and the assertion no longer fires.
    function fuzz_withdraw() external {
        require(balance > 0, "nothing to withdraw");
        uint256 mode = uint256(keccak256(abi.encode(block.timestamp))) % 997;
        balance = 0;
        assert(mode != 42);
    }
}
