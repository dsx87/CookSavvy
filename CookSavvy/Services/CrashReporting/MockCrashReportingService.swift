//
//  MockCrashReportingService.swift
//  CookSavvy
//

import Foundation

/// In-memory crash reporter used in DEBUG builds, in-memory containers, and tests.
///
/// Records every captured error and breadcrumb so test code can assert that the expected
/// signals were emitted (e.g. that a `LoggerProtocol.error` call forwarded a breadcrumb).
final class MockCrashReportingService: CrashReportingServiceProtocol {

    /// All errors captured since the mock was created, in chronological order.
    private(set) var recordedErrors: [Error] = []
    /// All breadcrumbs added since the mock was created, in chronological order.
    private(set) var breadcrumbs: [(message: String, level: CrashBreadcrumbLevel)] = []

    func record(_ error: Error) {
        recordedErrors.append(error)
    }

    func addBreadcrumb(_ message: String, level: CrashBreadcrumbLevel) {
        breadcrumbs.append((message, level))
    }
}
