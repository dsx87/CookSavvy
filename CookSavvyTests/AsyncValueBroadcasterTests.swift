//
//  AsyncValueBroadcasterTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

/// Characterises `AsyncValueBroadcaster` — the `CurrentValueSubject` replacement underpinning the
/// Combine→AsyncStream migration (auth, subscription, and sign-in event streams). These behaviours
/// (synchronous replay, per-consumer fan-out, ordering across the replay→update boundary) are exactly
/// what the compiler cannot verify, so they are pinned here.
final class AsyncValueBroadcasterTests: XCTestCase {

    // MARK: - Synchronous value

    @MainActor
    func testValueReflectsLatestSend() async {
        let broadcaster = AsyncValueBroadcaster<Int>(1)
        XCTAssertEqual(broadcaster.value, 1)

        broadcaster.send(2)
        XCTAssertEqual(broadcaster.value, 2)

        broadcaster.send(3)
        XCTAssertEqual(broadcaster.value, 3)
    }

    // MARK: - Replay

    @MainActor
    func testUpdatesReplaysCurrentValueToNewConsumer() async {
        let broadcaster = AsyncValueBroadcaster<Int>(42)
        let values = await collectValues(1, from: broadcaster.updates)
        XCTAssertEqual(values, [42])
    }

    @MainActor
    func testLateSubscriberReplaysLatestValueNotInitial() async {
        let broadcaster = AsyncValueBroadcaster<Int>(1)
        broadcaster.send(2)
        broadcaster.send(3)

        // A consumer subscribing after several sends must replay the latest value (3), not the seed.
        let values = await collectValues(1, from: broadcaster.updates)
        XCTAssertEqual(values, [3])
    }

    // MARK: - Replay → update boundary

    @MainActor
    func testUpdatesReplaysCurrentThenYieldsSubsequentChangeWithoutDuplication() async {
        let broadcaster = AsyncValueBroadcaster<Int>(1)
        let stream = broadcaster.updates  // registers + replays 1 synchronously
        broadcaster.send(2)

        let values = await collectValues(2, from: stream)
        // Exactly [1, 2]: the replayed current value, then the single subsequent change — no missed
        // update and no duplicated replay at the boundary.
        XCTAssertEqual(values, [1, 2])
    }

    @MainActor
    func testBroadcasterDoesNotDeduplicateConsecutiveEqualValues() async {
        // De-duplication is each service's responsibility (its publish path), not the broadcaster's:
        // every send is delivered, including repeats.
        let broadcaster = AsyncValueBroadcaster<Int>(0)
        let stream = broadcaster.updates
        broadcaster.send(5)
        broadcaster.send(5)

        let values = await collectValues(3, from: stream)
        XCTAssertEqual(values, [0, 5, 5])
    }

    // MARK: - Fan-out

    @MainActor
    func testSendFansOutIndependentlyToEveryLiveConsumer() async {
        let broadcaster = AsyncValueBroadcaster<Int>(0)
        let streamA = broadcaster.updates  // each replays 0 synchronously on access
        let streamB = broadcaster.updates

        async let collectedA = collectValues(2, from: streamA)
        async let collectedB = collectValues(2, from: streamB)

        broadcaster.send(99)

        let (a, b) = await (collectedA, collectedB)
        XCTAssertEqual(a, [0, 99])
        XCTAssertEqual(b, [0, 99])
    }

    // MARK: - Termination cleanup

    @MainActor
    func testTerminatedConsumerDoesNotBreakOtherConsumers() async {
        let broadcaster = AsyncValueBroadcaster<Int>(0)

        // A first consumer subscribes then goes out of scope, terminating its stream so its
        // continuation is removed from the broadcaster.
        do {
            let ephemeral = broadcaster.updates
            var iterator = ephemeral.makeAsyncIterator()
            _ = await iterator.next()  // drain the replayed 0
        }

        // A surviving consumer still receives sends after the other consumer is gone.
        let survivor = broadcaster.updates
        broadcaster.send(1)
        let values = await collectValues(2, from: survivor)
        XCTAssertEqual(values, [0, 1])
    }

    // MARK: - Send vs. cancellation races

    @MainActor
    func testConcurrentSendsAndConsumerTerminationsStayConsistent() async {
        let broadcaster = AsyncValueBroadcaster<Int>(0)

        // Flood sends while many consumers subscribe and immediately terminate, so each consumer's
        // `onTermination` (which takes the lock to deregister) races the writer's lock-held `yield`s.
        // `yield` never re-enters our code, so this contends but cannot deadlock; reaching the
        // assertions proves it, and that the broadcaster stays consistent after the churn.
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for value in 1...500 {
                    broadcaster.send(value)
                }
            }
            for _ in 0..<50 {
                group.addTask {
                    for await _ in broadcaster.updates {
                        break  // take the replayed value, then terminate
                    }
                }
            }
            await group.waitForAll()
        }

        broadcaster.send(123)
        XCTAssertEqual(broadcaster.value, 123)
        let values = await collectValues(1, from: broadcaster.updates)
        XCTAssertEqual(values, [123])
    }
}

/// Collects up to `count` values from `stream`, bounded by a `timeout` so a missing value fails the
/// test quickly instead of hanging the suite. (The broadcaster buffers replayed/sent values, so
/// values produced before collection starts are not lost.) A free function rather than a method to
/// avoid capturing the non-`Sendable` `XCTestCase` across the task group.
private func collectValues(
    _ count: Int,
    from stream: AsyncStream<Int>,
    timeout: Duration = .seconds(2)
) async -> [Int] {
    await withTaskGroup(of: [Int]?.self) { group in
        group.addTask {
            var values: [Int] = []
            for await value in stream {
                values.append(value)
                if values.count >= count { break }
            }
            return values
        }
        group.addTask {
            try? await Task.sleep(for: timeout)
            return nil  // timeout sentinel
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result ?? []
    }
}
