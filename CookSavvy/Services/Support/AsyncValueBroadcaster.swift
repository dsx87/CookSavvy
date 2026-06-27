//
//  AsyncValueBroadcaster.swift
//  CookSavvy
//

import Foundation
import os

/// Thread-safe multicast of a current value plus subsequent updates to any number of
/// `AsyncStream` consumers — the app-layer replacement for a Combine `CurrentValueSubject`.
///
/// Mirrors the two behaviours the service event streams relied on:
/// - `value` is readable **synchronously from any isolation** (lock-protected), so callers such as
///   `SupabaseAuthService.authState` keep their "readable from any context without an actor hop"
///   contract.
/// - Each `updates` access returns a **fresh** `AsyncStream` that immediately replays the current
///   value, then yields every subsequent change. A fresh stream per call site is intentional:
///   `AsyncStream` is single-consumer, so multiple observers (e.g. several view models) each get
///   their own stream.
///
/// Continuations are tracked under an `OSAllocatedUnfairLock` and removed on stream termination,
/// so a finished/cancelled consumer does not leak.
nonisolated final class AsyncValueBroadcaster<Value: Sendable>: Sendable {
    /// The lock-protected state: the latest value and the set of live stream continuations.
    private struct State {
        var value: Value
        var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    }

    private let state: OSAllocatedUnfairLock<State>

    /// Creates a broadcaster seeded with `initialValue` (replayed to the first consumer).
    init(_ initialValue: Value) {
        state = OSAllocatedUnfairLock(initialState: State(value: initialValue))
    }

    /// The current value, readable synchronously from any context.
    var value: Value {
        state.withLock { $0.value }
    }

    /// A fresh stream that replays the current value, then yields every subsequent change.
    var updates: AsyncStream<Value> {
        AsyncStream { continuation in
            let id = UUID()
            state.withLock { state in
                continuation.yield(state.value)
                state.continuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { $0.continuations[id] = nil }
            }
        }
    }

    /// Updates the value and broadcasts it to all active streams.
    func send(_ newValue: Value) {
        state.withLock { state in
            state.value = newValue
            for continuation in state.continuations.values {
                continuation.yield(newValue)
            }
        }
    }
}
