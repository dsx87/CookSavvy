//
//  CrashReportingServiceProtocol.swift
//  CookSavvy
//

import Foundation

/// Severity of a breadcrumb forwarded to the crash reporter.
///
/// Mirrors the subset of `os.Logger` levels the app forwards as breadcrumbs (see `LoggingService`):
/// recoverable warnings vs. non-fatal errors. Faults are recorded as captured errors, not
/// breadcrumbs.
enum CrashBreadcrumbLevel {
    case warning
    case error
}

/// Runtime crash-reporting surface used by the service layer.
///
/// Crash *capture itself* is automatic once the SDK is started at launch (see
/// `SentryCrashReportingService.bootstrapIfConfigured()`); this protocol covers the manual
/// signals services emit during normal operation — non-fatal error capture and breadcrumb trails
/// that give those errors and crashes context. Implementations are no-ops until the SDK is started.
protocol CrashReportingServiceProtocol: AnyObject {
    /// Records a non-fatal error so it appears in the crash dashboard with a stack trace.
    func record(_ error: Error)

    /// Appends a breadcrumb to the trail attached to subsequent crashes and captured errors.
    func addBreadcrumb(_ message: String, level: CrashBreadcrumbLevel)
}
