// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Minimal reproducer: Echidna removeReverts block.number bug
///
/// BUG: When Echidna shrinks a failing sequence, `removeReverts` (Shrink.hs)
/// replaces reverting calls with NoCall entries that keep the original block
/// delay. But in the original execution, reverting calls had their block.number
/// advance ROLLED BACK by `put vmBeforeTx` (Exec.hs:256). NoCall returns
/// VMSuccess — no rollback — so block advances stick. The shrunk reproducer
/// has a higher block.number than the original, breaking reproduction of any
/// block.number-dependent bug.
///
/// Root cause in lib/Echidna/Exec.hs:
///
///   vmBeforeTx <- get          -- snapshot BEFORE setupTx (before advanceBlock)
///   setupTx tx                 -- advances block.number and timestamp
///   case tx.call of
///     NoCall -> pure VMSuccess -- advance preserved, no rollback
///     _      -> do
///       vmResult <- runFully
///       handleErrorsAndConstruction vmResult vmBeforeTx
///         -- on Reversion: `put vmBeforeTx` restores pre-advance state
///
/// To reproduce:
///   echidna ShrinkBug.sol --config echidna.yaml
///
///   Expected: Echidna finds the assertion violation. Shrinking fails to
///   reduce the sequence because removeReverts produces a non-reproducing
///   sequence. All shrink attempts fail.
contract ShrinkBug {
    uint256 public balance;

    /// @dev Simulates a deposit. Reverts for amounts < 10, succeeds otherwise.
    /// ~50% of fuzzer inputs will revert. Each reverted tx's block advance gets
    /// rolled back in the original run, but NOT after removeReverts converts it
    /// to NoCall.
    function fuzz_deposit(uint256 amount) external {
        require(amount >= 10, "too small");
        balance += amount;
    }

    /// @dev Uses block.number-dependent RNG (same pattern as real protocol
    /// callback mode selection). The exact block.number determines the hash.
    /// After removeReverts inflates block.number, the hash changes and the
    /// assertion no longer fires.
    function fuzz_withdraw() external {
        require(balance > 0, "nothing to withdraw");
        uint256 mode = uint256(keccak256(abi.encode(block.number))) % 997;
        balance = 0;
        assert(mode != 42);
    }
}
