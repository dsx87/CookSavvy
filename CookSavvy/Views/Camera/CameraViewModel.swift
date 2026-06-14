//
//  CameraViewModel.swift
//  CookSavvy
//

import AVFoundation
import UIKit
import SwiftUI

/// ViewModel backing the Camera screen for AI ingredient detection.
///
/// Manages the full camera permission → capture → AI processing lifecycle:
/// - Requests camera access on first appearance
/// - Transitions through `State` cases as the user captures a photo
/// - Submits the captured image to `IngredientDetectionServiceProtocol`
/// - Calls `onIngredientsDetected` on success (with found ingredients) and then `onDismiss`
/// - Handles permission denial, empty results, and processing errors with appropriate states
@MainActor
@Observable final class CameraViewModel {

    /// Represents each phase of the camera capture and AI detection lifecycle.
    enum State: Equatable {
        case requestingPermission
        case permissionDenied
    /// The live camera + capture UI is shown and awaiting a photo.
        case capturing
        /// An image has been captured and is being sent to the AI detection service.
        case processing(UIImage)
        /// AI detection succeeded but returned an empty ingredient list.
        case noIngredientsFound
        /// An unrecoverable error occurred; the associated string is shown to the user.
        case error(String)
    }
    
    /// Camera-specific failures surfaced by the capture flow.
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
    
    /// The current lifecycle state, driving the camera view's displayed UI.
    private(set) var state: State = .requestingPermission
    /// Ingredients identified by the AI service from the last captured image.
    private(set) var detectedIngredients: [Ingredient] = []
    
    private let detectionService: IngredientDetectionServiceProtocol
    private let onDismiss: () -> Void
    private let onIngredientsDetected: ([Ingredient]) -> Void

    /// In-flight AI detection task. Cancelled on `deinit` and from the view's `onDisappear` so its
    /// completion callbacks cannot fire after the camera screen is dismissed mid-detection.
    @ObservationIgnored private var processingTask: Task<Void, Never>?

    /// Creates a camera view model with injected detection and completion callbacks.
    init(
        detectionService: IngredientDetectionServiceProtocol,
        onDismiss: @escaping () -> Void,
        onIngredientsDetected: @escaping ([Ingredient]) -> Void
    ) {
        self.detectionService = detectionService
        self.onDismiss = onDismiss
        self.onIngredientsDetected = onIngredientsDetected
    }

    deinit {
        processingTask?.cancel()
    }

    /// Checks the current camera authorization status and transitions to the appropriate state.
    /// Requests permission if it has not yet been determined.
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
    
    /// Opens the iOS Settings app so the user can grant camera permission.
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
    
    /// Dismisses the camera screen without returning any ingredients.
    func dismiss() {
        onDismiss()
    }

    /// Cancels any in-flight AI detection. Called from the view's `onDisappear` so a sheet dismissal
    /// (including an interactive swipe-down) stops detection before its callbacks mutate Discover state.
    func cancelProcessing() {
        processingTask?.cancel()
    }

    /// Called when the camera captures a photo; transitions to `.processing` and runs AI detection.
    func photoCaptured(_ image: UIImage) {
        state = .processing(image)

        processingTask = Task { [weak self] in
            await self?.processImage(image)
        }
    }
    
    /// Resets state to `.capturing` so the user can try taking a new photo.
    func retryCapture() {
        state = .capturing
    }
    
    /// Requests camera access from the system and updates `state` based on the user's decision.
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
    
    /// Sends the image to the detection service and handles all result/error transitions.
    ///
    /// On success with results: stores `detectedIngredients`, calls `onIngredientsDetected`, then `onDismiss`.
    /// On empty results: transitions to `.noIngredientsFound`.
    /// On error: transitions to `.error(message)` and auto-dismisses after 2 seconds.
    private func processImage(_ image: UIImage) async {
        do {
            let ingredients = try await detectionService.detectIngredients(in: image)
            // Bail out if the screen was dismissed mid-detection — otherwise the callbacks below
            // would mutate Discover's selection and re-trigger dismissal after the user cancelled.
            guard !Task.isCancelled else { return }

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
            // Briefly show the error, then auto-dismiss. The wait is a non-blocking suspension;
            // the dismissal runs on the main actor (this method's isolation).
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}
