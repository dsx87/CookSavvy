//
//  NoOpCrashReportingService.swift
//  CookSavvy
//

import Foundation

/// Inert crash reporter used when no Sentry DSN is configured (and in DEBUG builds).
///
/// Lets the service layer call `record`/`addBreadcrumb` unconditionally without branching on
/// whether crash reporting is active — the calls simply do nothing.
final class NoOpCrashReportingService: CrashReportingServiceProtocol {
    func record(_ error: Error) {}
    func addBreadcrumb(_ message: String, level: CrashBreadcrumbLevel) {}
}
