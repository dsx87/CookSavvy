import Foundation
import os

/// Typed categories that scope log output within the app's subsystem.
///
/// Each case corresponds to a distinct feature or layer. Using typed categories
/// (rather than raw strings at call sites) prevents typos and makes it straightforward to
/// filter output by category in Console.app or Instruments.
enum LogCategory: String {
    case recipeListViewModel = "RecipeListViewModel"
    case discoverViewModel = "DiscoverViewModel"
    case journeyViewModel = "JourneyViewModel"
    case shoppingListViewModel = "ShoppingListViewModel"
    case cookModeViewModel = "CookModeViewModel"
    case settingsViewModel = "SettingsViewModel"
    case recipeDetailsViewModel = "RecipeDetailsViewModel"
    case recipeService = "RecipeService"
    case dataImportService = "DataImportService"
    case subscriptionService = "SubscriptionService"
    case authService = "AuthService"
    case dietaryPreferences = "DietaryPreferences"
    case asyncImageDisk = "AsyncImageDisk"
}

/// Abstraction over `os.Logger` that maps to the standard severity levels.
///
/// Keeps call sites decoupled from `os.Logger` so tests can inject a no-op or
/// recording logger without importing the `os` framework.
protocol LoggerProtocol {
    /// Logs a debug-level message (verbose; may be stripped by the OS in non-debug builds).
    func debug(_ message: String)
    /// Logs an informational message.
    func info(_ message: String)
    /// Logs a notice-level message (default persistence level in the unified logging system).
    func notice(_ message: String)
    /// Logs a warning indicating a recoverable, unexpected condition.
    func warning(_ message: String)
    /// Logs a non-fatal error.
    func error(_ message: String)
    /// Logs an unrecoverable fault; triggers data collection for diagnostics.
    func fault(_ message: String)
}

/// Factory protocol for creating feature-scoped loggers.
///
/// The factory pattern lets each feature own a dedicated `LoggerProtocol` instance scoped to
/// its category, making log output filterable per feature in Console.app and Instruments
/// without relying on a single global logger.
protocol LoggingServiceProtocol {
    /// Creates a new `LoggerProtocol` scoped to `category` within the app's bundle subsystem.
    func makeLogger(category: LogCategory) -> any LoggerProtocol
}

/// Concrete `LoggingServiceProtocol` implementation backed by Apple's unified logging system (`os.Logger`).
///
/// Loggers are created on demand — one per `LogCategory` — sharing the same `subsystem` so all
/// app logs are grouped under one identifier in Console.app and can be filtered by category.
final class LoggingService: LoggingServiceProtocol {
    /// The reverse-DNS subsystem identifier passed to every `os.Logger` instance (defaults to the bundle ID).
    private let subsystem: String

    /// - Parameter subsystem: Reverse-DNS subsystem string; defaults to the app's bundle identifier.
    init(subsystem: String = Bundle.main.bundleIdentifier ?? "CookSavvy") {
        self.subsystem = subsystem
    }

    /// Creates an `os.Logger`-backed `LoggerProtocol` scoped to `category`.
    func makeLogger(category: LogCategory) -> any LoggerProtocol {
        OSAppLogger(
            logger: Logger(
                subsystem: subsystem,
                category: category.rawValue
            )
        )
    }
}

/// `LoggerProtocol` adapter that forwards calls to an `os.Logger` instance.
///
/// All messages are logged with `.public` privacy so they appear in Console.app without
/// redaction. Adjust the privacy level for any message that may contain PII in the future.
private struct OSAppLogger: LoggerProtocol {
    private let logger: Logger

    /// Wraps an `os.Logger` instance behind the app's `LoggerProtocol`.
    init(logger: Logger) {
        self.logger = logger
    }

    /// Emits a debug-level log entry.
    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    /// Emits an info-level log entry.
    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    /// Emits a notice-level log entry.
    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }

    /// Emits a warning-level log entry.
    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    /// Emits an error-level log entry.
    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    /// Emits a fault-level log entry.
    func fault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
    }
}
