//
//  AsyncImageDisk.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 27/06/2025.
//

import SwiftUI
import UIKit

/// A simple placeholder view displaying a progress spinner, used while an image is loading from disk.
struct DefaultPlaceholder: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UI.Common.placeholderCornerRadius)
                .foregroundStyle(theme.backgroundPrimary)
            ProgressView()
            
        }
    }
}

#Preview {
    DefaultPlaceholder()
}


/// A SwiftUI view that asynchronously loads and displays an image from the app's on-disk image cache
/// via `ImageService`. Accepts a custom placeholder shown while the image is loading.
///
/// The full filename is assembled using a configurable `imageNameBuilder` closure, allowing
/// callers to inject directory prefixes and file extensions. The convenience initialiser treats
/// `imageName` as the exact cache/ZIP path, matching JSON dataset values such as `images/foo.jpg`.
/// It falls back to the `DefaultPlaceholder` when no custom placeholder is provided.
///
/// Services are resolved through the SwiftUI environment (`imageService`, `loggingService`).
struct AsyncImageDisk<Placeholder: View>: View {
    
    let imageName: String
    let contentMode: ContentMode
    private var imageNamePrefix: String?
    private let imageNameBuilder: ((String?, String) -> String)
    @Environment(\.imageService) private var imageService
    @Environment(\.loggingService) private var loggingService
    @State private var image: UIImage? = nil
    @ViewBuilder private let placeholder: Placeholder
    
    /// Creates an instance with a fully customised name-building strategy.
    /// - Parameters:
    ///   - imageName: The base filename, without prefix or extension.
    ///   - contentMode: How the loaded image is scaled inside its frame.
    ///   - imageNamePrefix: Optional directory prefix prepended by `imageNameBuilder`.
    ///   - imageNameBuilder: Closure that assembles the full path from prefix + base name.
    ///   - placeholder: View shown while the image loads.
    init(
        imageName: String,
        contentMode: ContentMode = .fill,
        imageNamePrefix: String?,
        imageNameBuilder: @escaping ((String?, String) -> String),
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.imageNamePrefix = imageNamePrefix
        self.imageName = imageName
        self.contentMode = contentMode
        self.placeholder = placeholder()
        self.imageNameBuilder = imageNameBuilder
    }
    
    /// Convenience initialiser for recipe image paths already stored with their directory and extension.
    /// - Parameters:
    ///   - imageName: The base filename without extension.
    ///   - contentMode: How the loaded image is scaled inside its frame.
    ///   - placeholder: View shown while the image loads.
    init(
        imageName: String,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.imageNamePrefix = nil
        self.imageName = imageName
        self.contentMode = contentMode
        self.placeholder = placeholder()
        self.imageNameBuilder = { _, imageFileName in imageFileName }
    }
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
            
        }
        .task(id: imageName) {
            let fullImageName = imageNameBuilder(self.imageNamePrefix, self.imageName)
            guard let imageService else { return }
            do {
                self.image = nil
                self.image = try await imageService.loadImage(named: fullImageName)
            } catch {
                loggingService?
                    .makeLogger(category: .asyncImageDisk)
                    .error("Failed to load disk image \(fullImageName): \(error)")
            }
        }
    }
}

/// Custom SwiftUI environment key that carries the shared `ImageServiceProtocol` instance
/// down the view hierarchy without explicit prop drilling.
private struct ImageServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any ImageServiceProtocol)? = nil
}

/// Custom SwiftUI environment key that carries the shared `LoggingServiceProtocol` instance
/// down the view hierarchy.
private struct LoggingServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any LoggingServiceProtocol)? = nil
}

/// Environment value accessors for shared image and logging services.
extension EnvironmentValues {
    /// The shared image-loading service injected at app startup.
    var imageService: (any ImageServiceProtocol)? {
        get { self[ImageServiceEnvironmentKey.self] }
        set { self[ImageServiceEnvironmentKey.self] = newValue }
    }

    /// The shared logging service injected at app startup.
    var loggingService: (any LoggingServiceProtocol)? {
        get { self[LoggingServiceEnvironmentKey.self] }
        set { self[LoggingServiceEnvironmentKey.self] = newValue }
    }
}

#Preview {
    AsyncImageDisk(
        imageName: "images/bloody-mary-tomato-toast-with-celery-and-horseradish.jpg",
        placeholder: ({
            Color.gray
        })
    )
}
