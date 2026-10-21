// Copyright (Ice) © 2023–2025 Jordan Baird
// Copyright (Thaw) © 2026 Toni Förster
// Adapted for OverflowBar; GPL-3.0. See THIRD_PARTY_NOTICES.md.
import Foundation
struct EngineDeadlineExceeded: Error {}
struct EngineMoveBudget {
        typealias Elapsed = @Sendable () -> Duration
        typealias Sleeper = @Sendable (Duration) async throws -> Void

        let limit: Duration
        private let elapsedProvider: Elapsed
        private let sleeper: Sleeper

        init(limit: Duration) {
            let startedAt = ContinuousClock.now
            self.init(
                limit: limit,
                elapsed: { startedAt.duration(to: .now) },
                sleeper: { try await Task.sleep(for: $0) }
            )
        }

        init(
            limit: Duration,
            elapsed: @escaping Elapsed,
            sleeper: @escaping Sleeper = { try await Task.sleep(for: $0) }
        ) {
            self.limit = limit
            elapsedProvider = elapsed
            self.sleeper = sleeper
        }

        var elapsed: Duration {
            elapsedProvider()
        }

        func remaining() throws -> Duration {
            let value = limit - elapsed
            guard value > .zero else {
                throw EngineDeadlineExceeded()
            }
            return value
        }

        func timeout(for requested: Duration, repeating count: Int = 1) throws -> Duration {
            let repetitions = max(1, count)
            let value = try min(requested, remaining() / repetitions)
            guard value > .zero else {
                throw EngineDeadlineExceeded()
            }
            return value
        }

        func run<Value>(
            maximum: Duration,
            repeating count: Int = 1,
            operation: (Duration) async throws -> Value
        ) async throws -> Value {
            let allowance = try timeout(for: maximum, repeating: count)
            do {
                let value = try await operation(allowance)
                _ = try remaining()
                return value
            } catch {
                if elapsed >= limit {
                    throw EngineDeadlineExceeded()
                }
                throw error
            }
        }

        func sleep(for duration: Duration) async throws {
            let available = try remaining()
            guard available >= duration else {
                try await sleeper(available)
                throw EngineDeadlineExceeded()
            }
            try await sleeper(duration)
            _ = try remaining()
        }
    }

