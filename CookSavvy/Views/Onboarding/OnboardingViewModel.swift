//
//  OnboardingViewModel.swift
//  CookSavvy
//

import AVFoundation
import Foundation
import SwiftUI
import UIKit

@MainActor
final class OnboardingViewModel: ObservableObject {

    struct Page {
        let title: String
        let subtitle: String
        let symbolName: String
    }

    enum CameraPageState {
        case idle
        case requestingPermission
        case permissionGranted
        case capturing
        case processing(UIImage)
        case detected([Ingredient])
        case noIngredientsFound
        case error(String)
        case permissionDenied
    }

    let pages: [Page] = [
        Page(
            title: Strings.Onboarding.page1Title,
            subtitle: Strings.Onboarding.page1Subtitle,
            symbolName: "fork.knife.circle"
        ),
        Page(
            title: Strings.Onboarding.page2Title,
            subtitle: Strings.Onboarding.page2Subtitle,
            symbolName: "camera.viewfinder"
        )
    ]

    @Published var currentPage: Int = 0
    @Published var cameraState: CameraPageState = .idle

    private let analyticsService: AnalyticsServiceProtocol
    private let ingredientDetectionService: IngredientDetectionServiceProtocol
    private let cameraScanTracker: CameraScanTrackerProtocol
    private let completionDelayNanoseconds: UInt64
    private let onComplete: ([Ingredient]) -> Void
    private var hasCompletedFlow = false
    private var detectionTask: Task<Void, Never>?
    private var detectionCompletionTask: Task<Void, Never>?

    init(
        analyticsService: AnalyticsServiceProtocol,
        ingredientDetectionService: IngredientDetectionServiceProtocol,
        cameraScanTracker: CameraScanTrackerProtocol,
        completionDelayNanoseconds: UInt64 = UI.Onboarding.successDelayNanoseconds,
        onComplete: @escaping ([Ingredient]) -> Void
    ) {
        self.analyticsService = analyticsService
        self.ingredientDetectionService = ingredientDetectionService
        self.cameraScanTracker = cameraScanTracker
        self.completionDelayNanoseconds = completionDelayNanoseconds
        self.onComplete = onComplete
    }

    deinit {
        detectionTask?.cancel()
        detectionCompletionTask?.cancel()
    }

    var totalPages: Int {
        pages.count + 1
    }

    var isCameraPage: Bool {
        currentPage == pages.count
    }

    var shouldRefreshPermissionOnForeground: Bool {
        switch cameraState {
        case .idle, .requestingPermission, .permissionDenied:
            return true
        case .permissionGranted, .capturing, .processing, .detected, .noIngredientsFound, .error:
            return false
        }
    }

    var canUseTopRightFallback: Bool {
        guard isCameraPage else { return true }

        switch cameraState {
        case .processing, .detected:
            return false
        case .idle, .requestingPermission, .permissionGranted, .capturing, .noIngredientsFound, .error, .permissionDenied:
            return true
        }
    }

    var showsBottomControls: Bool {
        !isCameraPage
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard
            scenePhase == .active,
            isCameraPage,
            shouldRefreshPermissionOnForeground
        else { return }
        checkCameraPermission()
    }

    func handleTopRightAction() {
        skip()
    }

    func handlePrimaryAction() {
        nextPage()
    }

    func nextPage() {
        guard currentPage < totalPages - 1 else {
            finish(with: [], trackCompletion: true)
            return
        }

        currentPage += 1
        if isCameraPage {
            enterCameraPageIfNeeded()
        }
    }

    func skip() {
        analyticsService.track(.onboardingSkipped)
        finish(with: [], trackCompletion: false)
    }

    func complete() {
        finish(with: [], trackCompletion: true)
    }

    func typeInstead() {
        analyticsService.track(.onboardingTypeInsteadTapped)
        finish(with: [], trackCompletion: true)
    }

    func enterCameraPageIfNeeded() {
        guard isCameraPage else { return }
        guard case .idle = cameraState else { return }
        checkCameraPermission()
    }

    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            cameraState = .permissionGranted
            cameraState = .capturing
        case .notDetermined:
            cameraState = .requestingPermission
            requestCameraPermission()
        case .denied, .restricted:
            cameraState = .permissionDenied
        @unknown default:
            cameraState = .permissionDenied
        }
    }

    func photoCaptured(_ image: UIImage) {
        guard !hasCompletedFlow else { return }
        cameraScanTracker.recordScanWithoutQuota()
        cameraState = .processing(image)

        detectionTask?.cancel()
        detectionTask = Task { [weak self] in
            do {
                guard let self else { return }
                let ingredients = try await ingredientDetectionService.detectIngredients(in: image)
                guard !Task.isCancelled, !self.hasCompletedFlow else { return }
                if ingredients.isEmpty {
                    self.cameraState = .noIngredientsFound
                    return
                }
                self.completeWithIngredients(ingredients)
            } catch IngredientDetectionError.noIngredientsDetected {
                guard let self, !Task.isCancelled, !self.hasCompletedFlow else { return }
                self.cameraState = .noIngredientsFound
            } catch {
                guard let self, !Task.isCancelled, !self.hasCompletedFlow else { return }
                self.cameraState = .error(error.localizedDescription)
            }
        }
    }

    func retryCapture() {
        cameraState = .capturing
    }

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    var pageIndicatorAccessibilityLabel: String {
        String(format: Strings.Accessibility.onboardingPage, currentPage + 1, totalPages)
    }

    private func requestCameraPermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                cameraState = .permissionGranted
                cameraState = .capturing
            } else {
                cameraState = .permissionDenied
            }
        }
    }

    private func completeWithIngredients(_ ingredients: [Ingredient]) {
        guard !hasCompletedFlow else { return }
        detectionCompletionTask?.cancel()
        cameraState = .detected(ingredients)
        analyticsService.track(.onboardingCameraScanCompleted)
        detectionCompletionTask = Task { [weak self] in
            if let self, self.completionDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: self.completionDelayNanoseconds)
            }
            await self?.finishAfterDetectedIngredients(ingredients)
        }
    }

    private func finishAfterDetectedIngredients(_ ingredients: [Ingredient]) {
        guard !Task.isCancelled, !hasCompletedFlow else { return }
        finish(with: ingredients, trackCompletion: true)
    }

    private func finish(with ingredients: [Ingredient], trackCompletion: Bool) {
        guard !hasCompletedFlow else { return }
        hasCompletedFlow = true
        detectionTask?.cancel()
        detectionCompletionTask?.cancel()
        if trackCompletion {
            analyticsService.track(.onboardingCompleted)
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete(ingredients)
    }
}
