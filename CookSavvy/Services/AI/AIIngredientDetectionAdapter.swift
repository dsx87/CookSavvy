//
//  AIIngredientDetectionAdapter.swift
//  CookSavvy
//

import UIKit

/// Bridges `AIServiceProtocol` to `IngredientDetectionServiceProtocol`.
///
/// `CameraViewModel` depends on `IngredientDetectionServiceProtocol` so it can be tested
/// independently of AI concerns. At runtime the actual implementation is `AIService`, which
/// requires raw image `Data` rather than `UIImage`. This adapter converts between the two
/// interfaces, compresses the image to JPEG, and maps `AIServiceError` cases to the
/// corresponding `IngredientDetectionError` values expected by the camera layer.
final class AIIngredientDetectionAdapter: IngredientDetectionServiceProtocol {
    
    private let aiService: AIServiceProtocol
    
    /// - Parameter aiService: The underlying AI service used for ingredient detection.
    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }
    
    /// Converts `image` to JPEG data and delegates to `AIServiceProtocol.detectIngredients(from:)`.
    ///
    /// The capture is downscaled to `UI.ImageProcessing.detectionMaxDimension` before encoding:
    /// the remote vision model downsamples large images regardless, so shrinking on-device trims
    /// the base64 payload and upload latency without affecting detection accuracy.
    ///
    /// - Parameter image: The captured camera image to analyse.
    /// - Returns: Detected `Ingredient` values.
    /// - Throws: `IngredientDetectionError.invalidImage` if JPEG encoding fails,
    ///   `IngredientDetectionError.noIngredientsDetected` if none are found,
    ///   or `IngredientDetectionError.processingFailed` for all other AI errors.
    func detectIngredients(in image: UIImage) async throws -> [Ingredient] {
        let resized = image.downscaled(toMaxDimension: UI.ImageProcessing.detectionMaxDimension)
        guard let imageData = resized.jpegData(compressionQuality: UI.ImageProcessing.detectionJPEGQuality) else {
            throw IngredientDetectionError.invalidImage
        }
        do {
            return try await aiService.detectIngredients(from: imageData)
        } catch let error as AIServiceError {
            switch error {
            case .noIngredientsDetected:
                throw IngredientDetectionError.noIngredientsDetected
            case .invalidImageData:
                throw IngredientDetectionError.invalidImage
            default:
                throw IngredientDetectionError.processingFailed(error)
            }
        }
    }
}
