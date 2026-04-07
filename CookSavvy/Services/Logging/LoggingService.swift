import Foundation
import os

enum LogCategory: String {
    case recipeListViewModel = "RecipeListViewModel"
    case discoverViewModel = "DiscoverViewModel"
    case journeyViewModel = "JourneyViewModel"
    case shoppingListViewModel = "ShoppingListViewModel"
    case cookModeViewModel = "CookModeViewModel"
    case settingsViewModel = "SettingsViewModel"
    case recipeDetailsViewModel = "RecipeDetailsViewModel"
}

protocol LoggerProtocol {
    func debug(_ message: String)
    func info(_ message: String)
    func notice(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func fault(_ message: String)
}

protocol LoggingServiceProtocol {
    func makeLogger(category: LogCategory) -> any LoggerProtocol
}

final class LoggingService: LoggingServiceProtocol {
    private let subsystem: String

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "CookSavvy") {
        self.subsystem = subsystem
    }

    func makeLogger(category: LogCategory) -> any LoggerProtocol {
        OSAppLogger(
            logger: Logger(
                subsystem: subsystem,
                category: category.rawValue
            )
        )
    }
}

private struct OSAppLogger: LoggerProtocol {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    func fault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
    }
}
