import Foundation

/// Private wire model for a bundled substitution catalog entry.
struct SubstitutionCatalogEntry: Codable, Equatable, Sendable {
    /// Canonical ingredient name this entry covers.
    let ingredient: String
    /// Alternate names that should resolve to the same canonical ingredient.
    let aliases: [String]
    /// Curated substitute options for the canonical ingredient.
    let substitutes: [SubstitutionCatalogOption]
}

/// Private wire model for a single bundled substitute option.
struct SubstitutionCatalogOption: Codable, Equatable, Sendable {
    /// Canonical substitute ingredient name.
    let ingredient: String
    /// Alternate names that should count as the same substitute when checking the user's inventory.
    let aliases: [String]
    /// Human-readable ratio guidance such as `"1:1"` or `"3/4 amount"`.
    let ratio: String?
    /// Short caveat describing when the substitute is appropriate.
    let note: String?
}

/// Abstraction over loading substitution catalog entries from a local source.
protocol SubstitutionCatalogLoading {
    /// Loads and decodes the full curated substitution catalog.
    func loadCatalog() throws -> [SubstitutionCatalogEntry]
}

/// Reads the curated substitution catalog from either the app bundle or an explicit file URL.
final class LocalSubstitutionCatalogLoader: SubstitutionCatalogLoading {
    private enum Constants {
        static let defaultFileName = "Substitutions"
        static let defaultFileExtension = "json"
    }

    /// Source resolution is isolated here so production can use the app bundle while tests can
    /// point the loader at a temporary JSON file without depending on resource-copying behavior.
    private enum Source {
        case bundle(Bundle, fileName: String, fileExtension: String)
        case fileURL(URL)
    }

    private let source: Source
    private let decoder: JSONDecoder
    private let logger: any LoggerProtocol

    init(
        bundle: Bundle = .main,
        fileName: String = Constants.defaultFileName,
        fileExtension: String = Constants.defaultFileExtension,
        decoder: JSONDecoder = JSONDecoder(),
        logger: any LoggerProtocol
    ) {
        self.source = .bundle(bundle, fileName: fileName, fileExtension: fileExtension)
        self.decoder = decoder
        self.logger = logger
    }

    init(
        fileURL: URL,
        decoder: JSONDecoder = JSONDecoder(),
        logger: any LoggerProtocol
    ) {
        self.source = .fileURL(fileURL)
        self.decoder = decoder
        self.logger = logger
    }

    func loadCatalog() throws -> [SubstitutionCatalogEntry] {
        let fileURL = try resolveFileURL()

        do {
            let data = try Data(contentsOf: fileURL)
            let catalog = try decoder.decode([SubstitutionCatalogEntry].self, from: data)
            guard !catalog.isEmpty else {
                throw SubstitutionCatalogLoaderError.emptyCatalog
            }
            return catalog
        } catch let error as SubstitutionCatalogLoaderError {
            throw error
        } catch {
            logger.error("Failed to decode substitution catalog: \(error.localizedDescription)")
            throw SubstitutionCatalogLoaderError.decodingFailed(error)
        }
    }

    private func resolveFileURL() throws -> URL {
        switch source {
        case .bundle(let bundle, let fileName, let fileExtension):
            guard let fileURL = bundle.url(forResource: fileName, withExtension: fileExtension) else {
                logger.error("Substitution catalog file \(fileName).\(fileExtension) was not found in bundle")
                throw SubstitutionCatalogLoaderError.fileNotFound("\(fileName).\(fileExtension)")
            }
            return fileURL
        case .fileURL(let fileURL):
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                logger.error("Substitution catalog file does not exist at \(fileURL.path)")
                throw SubstitutionCatalogLoaderError.fileNotFound(fileURL.lastPathComponent)
            }
            return fileURL
        }
    }
}

/// Errors thrown while loading or decoding the curated substitution catalog.
enum SubstitutionCatalogLoaderError: Error, LocalizedError {
    /// The expected catalog file could not be found.
    case fileNotFound(String)
    /// The file exists but contains no substitution entries.
    case emptyCatalog
    /// The file exists but could not be decoded into the expected schema.
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Substitution catalog file '\(fileName)' not found"
        case .emptyCatalog:
            return "Substitution catalog is empty"
        case .decodingFailed(let error):
            return "Failed to decode substitution catalog: \(error.localizedDescription)"
        }
    }
}
