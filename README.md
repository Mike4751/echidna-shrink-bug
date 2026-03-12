# Echidna Shrink Bug: `removeReverts` Breaks `block.number` and `block.timestamp` in Shrunk Reproducers

## Summary

When Echidna shrinks a failing call sequence, `removeReverts` replaces reverting transactions with `NoCall` entries. However, in the **original execution**, reverting calls had their `block.number` and `block.timestamp` advances **rolled back** by the EVM state restoration in `handleErrorsAndConstruction`. The `NoCall` replacements return `VMSuccess` and never trigger this rollback, so block advances **stick** -- giving the shrunk reproducer **higher `block.number` and `block.timestamp`** than the original run.

Any invariant or assertion that depends on exact `block.number` or `block.timestamp` (e.g., RNG based on `keccak256(abi.encode(block.number))`) will fail to reproduce from the shrunk call sequence.

## Root Cause

In `lib/Echidna/Exec.hs`, `execTxWith`:

```haskell
vmBeforeTx <- get          -- snapshot BEFORE setupTx (before advanceBlock)
setupTx tx                 -- advances block.number and timestamp
case tx.call of
  NoCall -> pure VMSuccess -- advance preserved, no rollback
  _      -> do
    vmResult <- runFully
    handleErrorsAndConstruction vmResult vmBeforeTx
      -- on Reversion: `put vmBeforeTx` restores pre-advance state
```

- `setupTx` calls `advanceBlock`, which increments both `block.number` and `block.timestamp`
- For real calls that revert, `handleErrorsAndConstruction` does `put vmBeforeTx`, restoring the state from **before** `setupTx` -- rolling back the block advance
- For `NoCall` (inserted by `removeReverts`), execution returns `VMSuccess` immediately -- `handleErrorsAndConstruction` is never called, so the block advance is preserved
- The hevm EVM itself does **not** roll back `block.number`/`block.timestamp` on revert (only contract storage and substate), so `put vmBeforeTx` is the only mechanism that does this

## Impact

- **Shrunk reproducers have incorrect `block.number` and `block.timestamp`**: inflated by the sum of all block/time delays from formerly-reverting calls
- **Shrinking always fails**: `removeReverts` runs first, producing a non-reproducing base sequence. All subsequent `shrinkSeq` attempts are variations of this broken sequence, so all 500 (default `shrinkLimit`) attempts fail
- **Silent failure**: Echidna reports a "reproducer" that does not actually reproduce the finding. The displayed call sequence and the traces come from different executions
- **Affects `block.timestamp` too**: same `put vmBeforeTx` mechanism rolls back timestamp, so time delays from `*wait*` entries are also technically incorrect

## Reproducing

### Prerequisites

- [Echidna](https://github.com/crytic/echidna) (any version with `removeReverts` in `Shrink.hs`)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Step 1: Run Echidna

```bash
echidna src/ShrinkBug.sol --config echidna.yaml
```

Echidna will find an assertion violation in `fuzz_withdraw()` and attempt to shrink it. The shrunk reproducer will contain `*wait*` entries (NoCalls from `removeReverts`).

### Step 2: Observe shrinking failure

If using a diagnostic Echidna build with `[SHRINK-DIAG]` logging in `Shrink.hs`:

```
[SHRINK-DIAG] removeReverts produced 11 txs (3 NoCalls)
[SHRINK-DIAG] replay of removeReverts sequence: value=True    <-- doesn't reproduce!
[SHRINK-DIAG] original test value=
[SHRINK-DIAG] attempt 0/500 failed for 11 txs
[SHRINK-DIAG] attempt 100/500 failed for 11 txs
[SHRINK-DIAG] attempt 200/500 failed for 11 txs
[SHRINK-DIAG] attempt 300/500 failed for 11 txs
[SHRINK-DIAG] attempt 400/500 failed for 11 txs
```

All 500 shrink attempts fail because the base sequence (post-`removeReverts`) doesn't reproduce the bug.

### Step 3: Verify with Forge

```bash
forge test -vv
```

#### block.number variant (`ShrinkBug.sol`)

- **`test_replay_with_waits` PASSES** -- replays the shrunk reproducer exactly as Echidna outputs it, including `vm.roll` for `*wait*` entries. `block.number` is inflated, `keccak256` hash changes, assertion does not fire. **The shrunk reproducer does not reproduce the bug.**

- **`test_replay_without_waits` FAILS** -- same sequence but skipping `vm.roll` for `*wait*` entries (matching the original execution where reverting calls' block advances were rolled back). `block.number` is correct, assertion fires. **The bug is real.**

```
[PASS] test_replay_with_waits()
  block.number at final fuzz_withdraw: 4822266
  keccak mode: 751

[FAIL: panic: assertion failed (0x01)] test_replay_without_waits()
  block.number at final fuzz_withdraw: 4566221
  keccak mode: 42
```

The difference: 4822266 - 4566221 = **256045 blocks** -- exactly the sum of the three `*wait*` block delays (189689 + 61336 + 5020).

#### block.timestamp variant (`ShrinkBugTimestamp.sol`)

Same pattern but for `block.timestamp`:

```
[PASS] test_replay_with_waits()
  block.timestamp at final fuzz_withdraw: 1527256961
  keccak mode: 121

[FAIL: panic: assertion failed (0x01)] test_replay_without_waits()
  block.timestamp at final fuzz_withdraw: 1526108034
  keccak mode: 42
```

The difference: 1527256961 - 1526108034 = **1148927 seconds** -- exactly the sum of the three `*wait*` time delays (31594 + 653745 + 463588).

## The Contracts

Both contracts follow the same pattern:

- `fuzz_deposit(amount)` -- reverts for `amount < 10` (~50% of fuzzer inputs), succeeds otherwise
- `fuzz_withdraw()` -- uses `keccak256(abi.encode(block.number))` or `keccak256(abi.encode(block.timestamp))` as RNG with `% 997`; asserts `mode != 42`

When `fuzz_deposit` calls revert during fuzzing, Echidna's original execution rolls back their block/time advances. After `removeReverts` converts them to `NoCall`, the advances stick, inflating the values by the sum of their delays.

## Files

- `src/ShrinkBug.sol` -- minimal contract demonstrating the block.number bug
- `src/ShrinkBugTimestamp.sol` -- minimal contract demonstrating the block.timestamp bug
- `test/ReplayShrunkReproducer.t.sol` -- Forge test for block.number variant
- `test/ReplayShrunkTimestamp.t.sol` -- Forge test for block.timestamp variant
- `echidna.yaml` -- Echidna configuration (block.number variant)
- `echidna-timestamp.yaml` -- Echidna configuration (block.timestamp variant)
