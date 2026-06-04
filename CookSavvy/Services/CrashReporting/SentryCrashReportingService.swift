//
//  SentryCrashReportingService.swift
//  CookSavvy
//

import Foundation
import Sentry

/// Production crash reporter backed by the Sentry SDK.
///
/// Crash capture is enabled by `bootstrapIfConfigured()`, which must run as early as possible in
/// the app lifecycle (`CookSavvyApp` calls it before the dependency container is built) so that
/// crashes during startup — including container initialization failures — are captured with full
/// stack traces and device metadata. Once started, the SDK auto-captures crashes; this instance
/// adds manual non-fatal error capture and breadcrumbs for the service layer.
///
/// All entry points are safe to call before `start` runs: the Sentry SDK no-ops manual calls
/// until it is started, and `bootstrapIfConfigured` only starts in RELEASE builds with a DSN.
final class SentryCrashReportingService: CrashReportingServiceProtocol {

    /// Whether the process-global Sentry SDK has already been started. `SentrySDK.start` is
    /// process-wide, and the app instantiates `ThemedAppRoot` once per `WindowGroup` scene (e.g. a
    /// second iPad window), so this guard prevents a restart that would reset the hub/scope and
    /// drop the running scene's breadcrumb/session state. Touched only on the main thread at launch.
    private static var hasBootstrapped = false

    /// Starts the Sentry SDK once per process when a DSN is configured and the build is not DEBUG.
    ///
    /// DEBUG builds intentionally skip startup so local development and CI never report to the
    /// production crash dashboard. When no DSN is present the integration stays inert.
    static func bootstrapIfConfigured(configuration: CrashReportingConfiguration = CrashReportingConfiguration()) {
        #if DEBUG
        return
        #else
        guard !hasBootstrapped, let dsn = configuration.dsn else { return }
        hasBootstrapped = true
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = "production"
        }
        #endif
    }

    func record(_ error: Error) {
        SentrySDK.capture(error: error)
    }

    func addBreadcrumb(_ message: String, level: CrashBreadcrumbLevel) {
        let crumb = Breadcrumb()
        crumb.message = message
        crumb.level = level.sentryLevel
        SentrySDK.addBreadcrumb(crumb)
    }
}

private extension CrashBreadcrumbLevel {
    /// Maps the app's breadcrumb level onto Sentry's `SentryLevel`.
    var sentryLevel: SentryLevel {
        switch self {
        case .warning: return .warning
        case .error: return .error
        }
    }
}
