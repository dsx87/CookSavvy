//
//  Coordinator.swift
//  CookSavvy
//

import SwiftUI

/// Base protocol that all feature coordinators conform to.
///
/// Coordinators are `@Observable` so SwiftUI views can observe navigation state directly.
/// Each coordinator is responsible for building its root view via `start()`, owning its
/// `NavigationPath`, and creating view models for every destination it manages.
@MainActor
protocol Coordinator: AnyObject {
    /// The root view type produced by this coordinator.
    associatedtype ContentView: View

    /// Builds and returns the root view for this coordinator's navigation scope.
    func start() -> ContentView
}
