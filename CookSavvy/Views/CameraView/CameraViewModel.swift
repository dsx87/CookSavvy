//
//  CameraViewModel.swift
//  CookSavvy
//

import AVFoundation
import UIKit
import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
    
    enum State: Equatable {
        case requestingPermission
        case permissionDenied
        case capturing
        case processing(UIImage)
        case noIngredientsFound
        case error(String)
    }
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case captureError(String)
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Camera is not available"
            case .captureError(let message):
                return message
            }
        }
    }
    
    @Published private(set) var state: State = .requestingPermission
    @Published private(set) var detectedIngredients: [Ingredient] = []
    
    private let detectionService: IngredientDetectionServiceProtocol
    private let onDismiss: () -> Void
    private let onIngredientsDetected: ([Ingredient]) -> Void
    
    init(
        detectionService: IngredientDetectionServiceProtocol,
        onDismiss: @escaping () -> Void,
        onIngredientsDetected: @escaping ([Ingredient]) -> Void
    ) {
        self.detectionService = detectionService
        self.onDismiss = onDismiss
        self.onIngredientsDetected = onIngredientsDetected
    }
    
    func checkCameraPermission() {
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            state = .capturing
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            state = .permissionDenied
        @unknown default:
            state = .permissionDenied
        }
    }
    
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
    
    func dismiss() {
        onDismiss()
    }
    
    func photoCaptured(_ image: UIImage) {
        state = .processing(image)
        
        Task {
            await processImage(image)
        }
    }
    
    func retryCapture() {
        state = .capturing
    }
    
    private func requestCameraPermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                state = .capturing
            } else {
                state = .permissionDenied
            }
        }
    }
    
    private func processImage(_ image: UIImage) async {
        do {
            let ingredients = try await detectionService.detectIngredients(in: image)
            
            if ingredients.isEmpty {
                state = .noIngredientsFound
            } else {
                detectedIngredients = ingredients
                onIngredientsDetected(ingredients)
                onDismiss()
            }
        } catch IngredientDetectionError.noIngredientsDetected {
            state = .noIngredientsFound
        } catch {
            state = .error(error.localizedDescription)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.onDismiss()
            }
        }
    }
}
