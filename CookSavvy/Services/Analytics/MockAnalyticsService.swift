import Foundation

/// In-memory analytics service used in DEBUG builds and UI tests.
///
/// Events are appended to `trackedEvents` with no side-effects, allowing test code to
/// assert that the expected analytics calls were made.
final class MockAnalyticsService: AnalyticsServiceProtocol {

    /// All events recorded since the mock was created, in chronological order.
    var trackedEvents: [(AnalyticsEvent, [String: String])] = []

    /// Appends the event and its properties to `trackedEvents`.
    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        trackedEvents.append((event, properties))
    }

    /// Appends the event with an empty properties dictionary to `trackedEvents`.
    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }
}
