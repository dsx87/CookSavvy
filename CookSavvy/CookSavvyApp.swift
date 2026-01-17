//
//  CookSavvyApp.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import SwiftUI

@main
struct CookSavvyApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            TabContainerView(coordinator: coordinator)
        }
    }
}
