//
//  OnboardingViewModel.swift
//  CookSavvy
//

import AVFoundation
import Foundation
import SwiftUI
import UIKit

/// ViewModel backing the first-launch onboarding flow.
///
/// The onboarding consists of two static intro pages followed by an embedded camera scan page.
/// On the camera page the user can scan ingredients immediately; a successful scan hands the
/// detected ingredients back to `onComplete` so the Discover screen can pre-populate them.
///
/// Supports three exit paths:
/// - Skip (top-right button) — exits without ingredients
/// - Type Instead — also exits without ingredients, navigating to Discover's text input
/// - Camera scan success — exits with detected ingredients for immediate Discover results
///
/// Guards against double-completion via `hasCompletedFlow`. Cancels in-flight detection tasks
/// on `deinit` or when a new photo is captured.
@Observable final class OnboardingViewModel {

    /// A single static onboarding page with a title, subtitle, and SF Symbol name.
    struct Page {
        let title: String
        let subtitle: String
        let symbolName: String
    }

    /// The phases of the embedded camera page within onboarding.
    enum CameraPageState {
        /// Camera page not yet entered.
        case idle
        /// Waiting for the user's response to the system permission dialog.
        case requestingPermission
        /// Permission was granted; ready to transition to `.capturing`.
        case permissionGranted
        /// The live camera preview is active and awaiting a photo.
        case capturing
        /// A photo was taken and is being sent to the detection service.
        case processing(UIImage)
        /// Detection succeeded and returned at least one ingredient.
        case detected([Ingredient])
        /// Detection succeeded but returned no ingredients.
        case noIngredientsFound
        /// Detection failed with the given error message.
        case error(String)
        /// Camera permission was denied or restricted.
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

    /// Zero-indexed index of the currently displayed page (0 and 1 are static; `pages.count` is the camera page).
    var currentPage: Int = 0
    /// The current state of the embedded camera page.
    var cameraState: CameraPageState = .idle

    private let analyticsService: AnalyticsServiceProtocol
    private let ingredientDetectionService: IngredientDetectionServiceProtocol
    private let cameraScanTracker: CameraScanTrackerProtocol
    private let completionDelayNanoseconds: UInt64
    private let onComplete: ([Ingredient]) -> Void
    private var hasCompletedFlow = false
    @ObservationIgnored private var detectionTask: Task<Void, Never>?
    @ObservationIgnored private var detectionCompletionTask: Task<Void, Never>?

    /// Creates the onboarding view model with dependencies and completion callback.
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

    /// Cancels any in-flight detection tasks when the view model is released.
    deinit {
        detectionTask?.cancel()
        detectionCompletionTask?.cancel()
    }

    /// Total number of pages including the camera page.
    var totalPages: Int {
        pages.count + 1
    }

    /// `true` when the user is on the embedded camera page (last page).
    var isCameraPage: Bool {
        currentPage == pages.count
    }

    /// `true` when the camera permission state should be re-checked on foreground transition
    /// (i.e. the user may have changed the permission in Settings).
    var shouldRefreshPermissionOnForeground: Bool {
        switch cameraState {
        case .idle, .requestingPermission, .permissionDenied:
            return true
        case .permissionGranted, .capturing, .processing, .detected, .noIngredientsFound, .error:
            return false
        }
    }

    /// `true` when the top-right Skip / Type Instead button should be visible.
    ///
    /// Hidden while the camera is processing or showing detected ingredients to avoid interrupting the flow.
    var canUseTopRightFallback: Bool {
        guard isCameraPage else { return true }

        switch cameraState {
        case .processing, .detected:
            return false
        case .idle, .requestingPermission, .permissionGranted, .capturing, .noIngredientsFound, .error, .permissionDenied:
            return true
        }
    }

    /// `true` on the static pages; `false` on the camera page (which has its own control layout).
    var showsBottomControls: Bool {
        !isCameraPage
    }

    /// The label for the primary CTA button: "Next" on static pages, "Get Started" on the camera page.
    var primaryButtonTitle: String {
        isCameraPage ? Strings.Onboarding.getStarted : Strings.Onboarding.next
    }

    /// Re-checks camera permission when the app returns to the foreground on the camera page.
    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard
            scenePhase == .active,
            isCameraPage,
            shouldRefreshPermissionOnForeground
        else { return }
        checkCameraPermission()
    }

    /// Handles the top-right Skip / Type Instead button tap by calling `skip()`.
    func handleTopRightAction() {
        skip()
    }

    /// Handles the primary CTA button tap: advances to the next page or finishes.
    func handlePrimaryAction() {
        nextPage()
    }

    /// Advances to the next page; enters the camera page if it is the next one.
    /// Finishes the flow if the user is already on the last page.
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

    /// Exits onboarding without ingredients, tracking a skip event.
    func skip() {
        analyticsService.track(.onboardingSkipped)
        finish(with: [], trackCompletion: false)
    }

    /// Completes onboarding without ingredients (called from "Get Started" on the camera page).
    func complete() {
        finish(with: [], trackCompletion: true)
    }

    /// Exits onboarding and navigates directly to the text-input ingredient screen, tracking the event.
    func typeInstead() {
        analyticsService.track(.onboardingTypeInsteadTapped)
        finish(with: [], trackCompletion: true)
    }

    /// Checks the current camera permission status and transitions `cameraState` accordingly.
    /// No-op if the camera page has not been entered yet.
    func enterCameraPageIfNeeded() {
        guard isCameraPage else { return }
        guard case .idle = cameraState else { return }
        checkCameraPermission()
    }

    /// Reads the current `AVCaptureDevice` authorization status and transitions `cameraState`.
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

    /// Receives a captured photo, deducts a scan, and begins AI ingredient detection.
    ///
    /// Cancels any previously running detection task. The scan is recorded without quota enforcement
    /// (onboarding scans are free of charge). Transitions `cameraState` through `.processing` →
    /// `.detected` or `.noIngredientsFound` or `.error`.
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

    /// Resets `cameraState` to `.capturing` so the user can take a new photo.
    func retryCapture() {
        cameraState = .capturing
    }

    /// Opens the iOS Settings app so the user can grant camera permission.
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    /// VoiceOver label describing the current page position (e.g. "Page 1 of 3").
    var pageIndicatorAccessibilityLabel: String {
        String(format: Strings.Accessibility.onboardingPage, currentPage + 1, totalPages)
    }

    /// Requests camera access from the system and updates `cameraState` based on the user's response.
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

    /// Transitions to `.detected`, tracks the analytics event, and schedules `finishAfterDetectedIngredients`
    /// after a short delay so the success state is briefly visible before the flow exits.
    private func completeWithIngredients(_ ingredients: [Ingredient]) {
        guard !hasCompletedFlow else { return }
        detectionCompletionTask?.cancel()
        cameraState = .detected(ingredients)
        analyticsService.track(.onboardingCameraScanCompleted)
        detectionCompletionTask = Task { [weak self] in
            if let self, self.completionDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: self.completionDelayNanoseconds)
            }
            self?.finishAfterDetectedIngredients(ingredients)
        }
    }

    /// Calls `finish` with the detected ingredients after the brief display delay has elapsed.
    private func finishAfterDetectedIngredients(_ ingredients: [Ingredient]) {
        guard !hasCompletedFlow else { return }
        finish(with: ingredients, trackCompletion: true)
    }

    /// Marks onboarding as completed, cancels pending tasks, persists the completion flag, and calls `onComplete`.
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
