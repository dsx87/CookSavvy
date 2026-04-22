import Foundation
import os

/// Production analytics service that writes events to the unified logging system via `os.Logger`.
///
/// This is a lightweight, no-network implementation: events are recorded locally and can be
/// inspected in Console.app under the "Analytics" category. To adopt a third-party analytics
/// SDK (e.g. Amplitude, Mixpanel), conform an adapter to `AnalyticsServiceProtocol` and
/// register it in `AppContainer` in place of this class.
final class AnalyticsService: AnalyticsServiceProtocol {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "Analytics"
    )

    /// Logs an analytics event together with its key-value properties.
    ///
    /// Properties are serialized as a comma-separated `key=value` string appended to the event
    /// name. When `properties` is empty, only the event name is logged.
    /// - Parameters:
    ///   - event: The event to track.
    ///   - properties: Metadata to include in the log entry.
    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        if properties.isEmpty {
            Self.logger.info("[\(event.rawValue)]")
        } else {
            let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            Self.logger.info("[\(event.rawValue)] \(props)")
        }
    }

    /// Logs an analytics event with no additional properties.
    /// - Parameter event: The event to track.
    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }
}
