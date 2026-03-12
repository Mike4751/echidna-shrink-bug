// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ShrinkBug.sol";

/// @title Forge replay of Echidna's shrunk reproducer for fuzz_withdraw() assertion
///
/// Demonstrates that Echidna's shrunk "reproducer" does NOT actually reproduce
/// the bug due to block.number inflation from removeReverts converting reverting
/// calls to NoCall.
///
/// Echidna's shrunk reproducer output:
///   *wait* Time delay: 529715 seconds Block delay: 189689
///   ShrinkBug.fuzz_deposit(127)     Time delay: 439556s Block delay: 45852
///   ShrinkBug.fuzz_withdraw()       Time delay: 490446s Block delay: 6721
///   ShrinkBug.fuzz_deposit(44)      Time delay: 321375s Block delay: 53349
///   ShrinkBug.fuzz_deposit(29328..) Time delay: 195123s Block delay: 9920
///   *wait* Time delay: 55 seconds Block delay: 61336
///   ShrinkBug.fuzz_deposit(36484..) Time delay: 322336s Block delay: 7
///   ShrinkBug.fuzz_withdraw()       Time delay: 82670s  Block delay: 59983
///   ShrinkBug.fuzz_deposit(11579..) Time delay: 376096s Block delay: 5021
///   *wait* Time delay: 649826 seconds Block delay: 5020
///   ShrinkBug.fuzz_withdraw()       Time delay: 50417s  Block delay: 15368
contract ReplayShrunkReproducer is ShrinkBug, Test {

    function setUp() public {
        vm.warp(1524785992); // Echidna initialTimestamp
        vm.roll(4370000);    // Echidna initialBlockNumber
    }

    /// @dev Replays the shrunk reproducer WITH *wait* vm.warp/vm.roll applied.
    /// This is what a naive Forge replay would do: translate every line of the
    /// shrunk output (including *wait* entries) into vm.warp + vm.roll.
    ///
    /// Expected: PASSES -- the assertion does NOT fire because block.number is
    /// inflated by 256045 blocks (the sum of 3 *wait* block delays), changing
    /// the keccak hash from mode=42 (triggers assert) to mode=751 (safe).
    function test_replay_with_waits() public {
        // *wait* Time delay: 529715 seconds Block delay: 189689
        vm.warp(block.timestamp + 529715);
        vm.roll(block.number + 189689);

        // ShrinkBug.fuzz_deposit(127) Time delay: 439556s Block delay: 45852
        vm.warp(block.timestamp + 439556);
        vm.roll(block.number + 45852);
        try this.fuzz_deposit(127) {} catch {}

        // ShrinkBug.fuzz_withdraw() Time delay: 490446s Block delay: 6721
        vm.warp(block.timestamp + 490446);
        vm.roll(block.number + 6721);
        try this.fuzz_withdraw() {} catch {}

        // ShrinkBug.fuzz_deposit(44) Time delay: 321375s Block delay: 53349
        vm.warp(block.timestamp + 321375);
        vm.roll(block.number + 53349);
        try this.fuzz_deposit(44) {} catch {}

        // ShrinkBug.fuzz_deposit(2932840...) Time delay: 195123s Block delay: 9920
        vm.warp(block.timestamp + 195123);
        vm.roll(block.number + 9920);
        try this.fuzz_deposit(2932840344248105651236158692751300961877350388516644163444628504254465775109) {} catch {}

        // *wait* Time delay: 55 seconds Block delay: 61336
        vm.warp(block.timestamp + 55);
        vm.roll(block.number + 61336);

        // ShrinkBug.fuzz_deposit(36484...) Time delay: 322336s Block delay: 7
        vm.warp(block.timestamp + 322336);
        vm.roll(block.number + 7);
        try this.fuzz_deposit(36484534905583458108145381534243984527706468852830035410856965324184590164199) {} catch {}

        // ShrinkBug.fuzz_withdraw() Time delay: 82670s Block delay: 59983
        vm.warp(block.timestamp + 82670);
        vm.roll(block.number + 59983);
        try this.fuzz_withdraw() {} catch {}

        // ShrinkBug.fuzz_deposit(11579...) Time delay: 376096s Block delay: 5021
        vm.warp(block.timestamp + 376096);
        vm.roll(block.number + 5021);
        try this.fuzz_deposit(115792089237316195423570985008687907853269984665640564039457584007913129639926) {} catch {}

        // *wait* Time delay: 649826 seconds Block delay: 5020
        vm.warp(block.timestamp + 649826);
        vm.roll(block.number + 5020);

        // ShrinkBug.fuzz_withdraw() Time delay: 50417s Block delay: 15368
        // This is the triggering call. block.number = 4822266, mode = 751.
        // The assertion does NOT fire -- the shrunk reproducer is broken.
        vm.warp(block.timestamp + 50417);
        vm.roll(block.number + 15368);

        console2.log("block.number at final fuzz_withdraw:", block.number);
        console2.log("keccak mode:", uint256(keccak256(abi.encode(block.number))) % 997);

        // This should succeed (no assertion failure) -- bug NOT reproduced
        this.fuzz_withdraw();
    }

    /// @dev Replays the same sequence WITHOUT *wait* vm.warp/vm.roll.
    /// This matches what Echidna's ORIGINAL execution actually saw: reverting
    /// calls had their block advances rolled back, so *wait* entries should
    /// not advance block.number.
    ///
    /// Expected: FAILS -- the assertion fires because block.number is correct
    /// (4566221), giving keccak mode=42 which triggers the assert.
    function test_replay_without_waits() public {
        // *wait* -- SKIPPED (original reverting call's block advance was rolled back)

        // ShrinkBug.fuzz_deposit(127) Time delay: 439556s Block delay: 45852
        vm.warp(block.timestamp + 439556);
        vm.roll(block.number + 45852);
        try this.fuzz_deposit(127) {} catch {}

        // ShrinkBug.fuzz_withdraw() Time delay: 490446s Block delay: 6721
        vm.warp(block.timestamp + 490446);
        vm.roll(block.number + 6721);
        try this.fuzz_withdraw() {} catch {}

        // ShrinkBug.fuzz_deposit(44) Time delay: 321375s Block delay: 53349
        vm.warp(block.timestamp + 321375);
        vm.roll(block.number + 53349);
        try this.fuzz_deposit(44) {} catch {}

        // ShrinkBug.fuzz_deposit(2932840...) Time delay: 195123s Block delay: 9920
        vm.warp(block.timestamp + 195123);
        vm.roll(block.number + 9920);
        try this.fuzz_deposit(2932840344248105651236158692751300961877350388516644163444628504254465775109) {} catch {}

        // *wait* -- SKIPPED

        // ShrinkBug.fuzz_deposit(36484...) Time delay: 322336s Block delay: 7
        vm.warp(block.timestamp + 322336);
        vm.roll(block.number + 7);
        try this.fuzz_deposit(36484534905583458108145381534243984527706468852830035410856965324184590164199) {} catch {}

        // ShrinkBug.fuzz_withdraw() Time delay: 82670s Block delay: 59983
        vm.warp(block.timestamp + 82670);
        vm.roll(block.number + 59983);
        try this.fuzz_withdraw() {} catch {}

        // ShrinkBug.fuzz_deposit(11579...) Time delay: 376096s Block delay: 5021
        vm.warp(block.timestamp + 376096);
        vm.roll(block.number + 5021);
        try this.fuzz_deposit(115792089237316195423570985008687907853269984665640564039457584007913129639926) {} catch {}

        // *wait* -- SKIPPED

        // ShrinkBug.fuzz_withdraw() Time delay: 50417s Block delay: 15368
        // block.number = 4566221, mode = 42. Assertion fires!
        vm.warp(block.timestamp + 50417);
        vm.roll(block.number + 15368);

        console2.log("block.number at final fuzz_withdraw:", block.number);
        console2.log("keccak mode:", uint256(keccak256(abi.encode(block.number))) % 997);

        // This should revert with Panic(0x01) -- bug IS reproduced
        this.fuzz_withdraw();
    }
}
