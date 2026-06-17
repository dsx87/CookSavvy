//
//  UIImage+Resize.swift
//  CookSavvy
//

import UIKit

/// Image resizing conveniences used before transmitting captures to remote services.
extension UIImage {
    /// Returns a copy of the image scaled so its longer edge is at most `maxDimension` points,
    /// preserving aspect ratio. Returns `self` unchanged when the image already fits, so smaller
    /// captures are never upscaled (which would add bytes without adding detail).
    ///
    /// The redraw is performed at scale `1` so the output's pixel dimensions equal its point
    /// dimensions — important when the bytes are JPEG-encoded for upload, where on-screen scale
    /// is irrelevant and a higher scale would silently re-inflate the resolution.
    ///
    /// - Parameter maxDimension: The maximum allowed length, in pixels, of the longer edge.
    /// - Returns: A downscaled image, or the original if it already fits within `maxDimension`.
    ///
    /// `nonisolated` so it can run off the main actor: `UIGraphicsImageRenderer` rendering is
    /// thread-safe and this is invoked from a `@concurrent` task in `AIIngredientDetectionAdapter`.
    nonisolated func downscaled(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension else { return self }

        let scaleFactor = maxDimension / longestEdge
        let targetSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
