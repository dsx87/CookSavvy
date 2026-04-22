//
//  DeviceUtility.swift
//  CookSavvy
//

import Foundation

/// Provides compile-time and runtime information about the current device environment.
enum DeviceUtility {
    /// `true` when the app is running inside the iOS Simulator rather than on a physical device.
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
