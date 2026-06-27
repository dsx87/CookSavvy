//
//  CameraViewModelTests.swift
//  CookSavvyTests
//

import SwiftUI
import XCTest
@testable import CookSavvy

final class CameraViewModelTests: XCTestCase {

    @MainActor
    private func makeViewModel() -> CameraViewModel {
        CameraViewModel(
            detectionService: MockIngredientDetectionService(),
            onDismiss: {},
            onIngredientsDetected: { _ in }
        )
    }

    // MARK: - setupCamera failure recovery

    @MainActor
    func testCameraSetupFailedTransitionsToCameraUnavailable() async {
        let viewModel = makeViewModel()

        viewModel.cameraSetupFailed()

        XCTAssertEqual(viewModel.state, .cameraUnavailable)
    }

    @MainActor
    func testRetryFromCameraUnavailableReturnsToCapturing() async {
        let viewModel = makeViewModel()
        viewModel.cameraSetupFailed()

        viewModel.retryCapture()

        XCTAssertEqual(viewModel.state, .capturing)
    }

    // MARK: - Foreground permission re-check gating

    @MainActor
    func testShouldRefreshPermissionOnForegroundWhenAwaitingPermission() async {
        let viewModel = makeViewModel()
        // Initial state is `.requestingPermission`.
        XCTAssertTrue(viewModel.shouldRefreshPermissionOnForeground)
    }

    @MainActor
    func testShouldNotRefreshPermissionOnForegroundWhenCameraUnavailable() async {
        let viewModel = makeViewModel()
        viewModel.cameraSetupFailed()

        XCTAssertFalse(viewModel.shouldRefreshPermissionOnForeground)
    }

    @MainActor
    func testShouldNotRefreshPermissionOnForegroundWhileCapturing() async {
        let viewModel = makeViewModel()
        viewModel.retryCapture() // moves to `.capturing`

        XCTAssertFalse(viewModel.shouldRefreshPermissionOnForeground)
    }

    @MainActor
    func testHandleScenePhaseChangeIgnoresNonActivePhases() async {
        let viewModel = makeViewModel()
        viewModel.retryCapture() // `.capturing`

        viewModel.handleScenePhaseChange(.background)
        viewModel.handleScenePhaseChange(.inactive)

        // A non-active phase must never re-run the permission check or otherwise change state.
        XCTAssertEqual(viewModel.state, .capturing)
    }
}
