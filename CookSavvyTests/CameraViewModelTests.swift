//
//  CameraViewModelTests.swift
//  CookSavvyTests
//

import SwiftUI
import XCTest
@testable import CookSavvy

@MainActor
final class CameraViewModelTests: XCTestCase {

    private func makeViewModel() -> CameraViewModel {
        CameraViewModel(
            detectionService: MockIngredientDetectionService(),
            onDismiss: {},
            onIngredientsDetected: { _ in }
        )
    }

    // MARK: - setupCamera failure recovery

    func testCameraSetupFailedTransitionsToCameraUnavailable() {
        let viewModel = makeViewModel()

        viewModel.cameraSetupFailed()

        XCTAssertEqual(viewModel.state, .cameraUnavailable)
    }

    func testRetryFromCameraUnavailableReturnsToCapturing() {
        let viewModel = makeViewModel()
        viewModel.cameraSetupFailed()

        viewModel.retryCapture()

        XCTAssertEqual(viewModel.state, .capturing)
    }

    // MARK: - Foreground permission re-check gating

    func testShouldRefreshPermissionOnForegroundWhenAwaitingPermission() {
        let viewModel = makeViewModel()
        // Initial state is `.requestingPermission`.
        XCTAssertTrue(viewModel.shouldRefreshPermissionOnForeground)
    }

    func testShouldNotRefreshPermissionOnForegroundWhenCameraUnavailable() {
        let viewModel = makeViewModel()
        viewModel.cameraSetupFailed()

        XCTAssertFalse(viewModel.shouldRefreshPermissionOnForeground)
    }

    func testShouldNotRefreshPermissionOnForegroundWhileCapturing() {
        let viewModel = makeViewModel()
        viewModel.retryCapture() // moves to `.capturing`

        XCTAssertFalse(viewModel.shouldRefreshPermissionOnForeground)
    }

    func testHandleScenePhaseChangeIgnoresNonActivePhases() {
        let viewModel = makeViewModel()
        viewModel.retryCapture() // `.capturing`

        viewModel.handleScenePhaseChange(.background)
        viewModel.handleScenePhaseChange(.inactive)

        // A non-active phase must never re-run the permission check or otherwise change state.
        XCTAssertEqual(viewModel.state, .capturing)
    }
}
