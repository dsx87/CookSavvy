//
//  TelemetryDeckAnalyticsService.swift
//  CookSavvy
//

import Foundation
import TelemetryDeck

/// Remote analytics adapter that forwards `AnalyticsEvent`s to TelemetryDeck.
///
/// This is the production transport for analytics when a TelemetryDeck app ID is configured;
/// otherwise `AppContainer` falls back to the local `os.Logger` `AnalyticsService`. The adapter
/// owns the TelemetryDeck SDK lifecycle (it initializes the SDK in `init`) so `AppContainer`
/// remains the single wiring point and no SDK setup leaks into the app entry point.
///
/// Event names are emitted verbatim from `AnalyticsEvent.rawValue` and properties are passed
/// through unchanged, preserving the trial-funnel event names and the `product_id` property that
/// the subscription layer depends on (see the T-002 notes in `SubscriptionServiceProtocol`).
final class TelemetryDeckAnalyticsService: AnalyticsServiceProtocol {

    /// Whether the process-global TelemetryDeck SDK has already been initialized. The app builds an
    /// `AppContainer` (and thus this service) once per `WindowGroup` scene, so this guard prevents a
    /// re-`initialize` that would reset TelemetryDeck's global manager/session and break queued
    /// signals. Touched only on the main thread (containers are built on the main actor).
    private static var isInitialized = false

    /// Initializes the TelemetryDeck SDK once per process with the given application identifier.
    /// - Parameter appID: The TelemetryDeck application identifier from `APIKeys.plist`.
    init(appID: String) {
        guard !Self.isInitialized else { return }
        Self.isInitialized = true
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
    }

    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        TelemetryDeck.signal(event.rawValue, parameters: properties)
    }

    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }
}
