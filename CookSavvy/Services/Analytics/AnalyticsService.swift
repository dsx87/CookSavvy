import Foundation
import os

final class AnalyticsService: AnalyticsServiceProtocol {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "Analytics"
    )

    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        if properties.isEmpty {
            Self.logger.info("[\(event.rawValue)]")
        } else {
            let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            Self.logger.info("[\(event.rawValue)] \(props)")
        }
    }

    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }
}
