// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ShrinkBugTimestamp.sol";

/// @title Forge replay of Echidna's shrunk reproducer for timestamp-dependent assertion
///
/// Same bug as ReplayShrunkReproducer.t.sol but for block.timestamp.
/// `put vmBeforeTx` rolls back BOTH block.number and block.timestamp for
/// reverting calls. NoCall preserves both advances.
///
/// Echidna's shrunk reproducer:
///   fuzz_deposit(71554...)       Time delay: 437838s Block delay: 20243
///   fuzz_withdraw()              Time delay: 33271s  Block delay: 2512
///   *wait*                       Time delay: 31594s  Block delay: 15367
///   fuzz_deposit(11579...9893)   Time delay: 67960s  Block delay: 5016
///   *wait*                       Time delay: 653745s Block delay: 26490
///   fuzz_withdraw()              Time delay: 206186s Block delay: 13
///   *wait*                       Time delay: 463588s Block delay: 34720
///   fuzz_deposit(11579...8940)   Time delay: 322373s Block delay: 3300
///   fuzz_withdraw()              Time delay: 254414s Block delay: 255
contract ReplayShrunkTimestamp is ShrinkBugTimestamp, Test {

    function setUp() public {
        vm.warp(1524785992); // Echidna initialTimestamp
        vm.roll(4370000);    // Echidna initialBlockNumber
    }

    /// @dev Replays WITH *wait* vm.warp/vm.roll applied.
    /// Expected: PASSES -- timestamp is inflated by 1148927 seconds,
    /// changing keccak mode from 42 (triggers assert) to 121 (safe).
    function test_replay_with_waits() public {
        // fuzz_deposit(71554...) Time delay: 437838s Block delay: 20243
        vm.warp(block.timestamp + 437838);
        vm.roll(block.number + 20243);
        try this.fuzz_deposit(71554115414099333135277059724416422375914631453585440178605096504509454195703) {} catch {}

        // fuzz_withdraw() Time delay: 33271s Block delay: 2512
        vm.warp(block.timestamp + 33271);
        vm.roll(block.number + 2512);
        try this.fuzz_withdraw() {} catch {}

        // *wait* Time delay: 31594s Block delay: 15367
        vm.warp(block.timestamp + 31594);
        vm.roll(block.number + 15367);

        // fuzz_deposit(11579...9893) Time delay: 67960s Block delay: 5016
        vm.warp(block.timestamp + 67960);
        vm.roll(block.number + 5016);
        try this.fuzz_deposit(115792089237316195423570985008687907853269984665640564039457584007913129639893) {} catch {}

        // *wait* Time delay: 653745s Block delay: 26490
        vm.warp(block.timestamp + 653745);
        vm.roll(block.number + 26490);

        // fuzz_withdraw() Time delay: 206186s Block delay: 13
        vm.warp(block.timestamp + 206186);
        vm.roll(block.number + 13);
        try this.fuzz_withdraw() {} catch {}

        // *wait* Time delay: 463588s Block delay: 34720
        vm.warp(block.timestamp + 463588);
        vm.roll(block.number + 34720);

        // fuzz_deposit(11579...8940) Time delay: 322373s Block delay: 3300
        vm.warp(block.timestamp + 322373);
        vm.roll(block.number + 3300);
        try this.fuzz_deposit(115792089237316195423570985008687907853269984665640564039457584007913129638940) {} catch {}

        // fuzz_withdraw() Time delay: 254414s Block delay: 255
        // timestamp = 1527256961, mode = 121. Assertion does NOT fire.
        vm.warp(block.timestamp + 254414);
        vm.roll(block.number + 255);

        console2.log("block.timestamp at final fuzz_withdraw:", block.timestamp);
        console2.log("keccak mode:", uint256(keccak256(abi.encode(block.timestamp))) % 997);

        this.fuzz_withdraw();
    }

    /// @dev Replays WITHOUT *wait* vm.warp/vm.roll.
    /// Expected: FAILS -- timestamp is correct (1526108034),
    /// giving keccak mode=42 which triggers the assert.
    function test_replay_without_waits() public {
        // fuzz_deposit(71554...) Time delay: 437838s Block delay: 20243
        vm.warp(block.timestamp + 437838);
        vm.roll(block.number + 20243);
        try this.fuzz_deposit(71554115414099333135277059724416422375914631453585440178605096504509454195703) {} catch {}

        // fuzz_withdraw() Time delay: 33271s Block delay: 2512
        vm.warp(block.timestamp + 33271);
        vm.roll(block.number + 2512);
        try this.fuzz_withdraw() {} catch {}

        // *wait* -- SKIPPED

        // fuzz_deposit(11579...9893) Time delay: 67960s Block delay: 5016
        vm.warp(block.timestamp + 67960);
        vm.roll(block.number + 5016);
        try this.fuzz_deposit(115792089237316195423570985008687907853269984665640564039457584007913129639893) {} catch {}

        // *wait* -- SKIPPED

        // fuzz_withdraw() Time delay: 206186s Block delay: 13
        vm.warp(block.timestamp + 206186);
        vm.roll(block.number + 13);
        try this.fuzz_withdraw() {} catch {}

        // *wait* -- SKIPPED

        // fuzz_deposit(11579...8940) Time delay: 322373s Block delay: 3300
        vm.warp(block.timestamp + 322373);
        vm.roll(block.number + 3300);
        try this.fuzz_deposit(115792089237316195423570985008687907853269984665640564039457584007913129638940) {} catch {}

        // fuzz_withdraw() Time delay: 254414s Block delay: 255
        // timestamp = 1526108034, mode = 42. Assertion fires!
        vm.warp(block.timestamp + 254414);
        vm.roll(block.number + 255);

        console2.log("block.timestamp at final fuzz_withdraw:", block.timestamp);
        console2.log("keccak mode:", uint256(keccak256(abi.encode(block.timestamp))) % 997);

        this.fuzz_withdraw();
    }
}
