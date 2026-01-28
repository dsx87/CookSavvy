//
//  DeviceUtility.swift
//  CookSavvy
//

import Foundation

enum DeviceUtility {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
