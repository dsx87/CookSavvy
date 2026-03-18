import Foundation

final class MockAnalyticsService: AnalyticsServiceProtocol {

    var trackedEvents: [(AnalyticsEvent, [String: String])] = []

    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        trackedEvents.append((event, properties))
    }

    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }
}
