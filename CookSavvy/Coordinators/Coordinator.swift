//
//  Coordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
protocol Coordinator: ObservableObject {
    associatedtype ContentView: View
    
    func start() -> ContentView
}
