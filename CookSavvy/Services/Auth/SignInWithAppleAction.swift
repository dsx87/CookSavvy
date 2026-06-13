import Foundation

/// The UI surface from which Sign in with Apple was initiated, used for context-specific analytics logging.
enum SignInWithAppleContext {
    case journey
    case settings

    /// The log message emitted on successful sign-in for this context.
    var successLogMessage: String {
        switch self {
        case .journey:
            return "Sign in with Apple completed from My Kitchen"
        case .settings:
            return "Sign in with Apple completed"
        }
    }
}

/// The outcome of a `SignInWithAppleAction.signIn(context:)` call.
enum SignInWithAppleActionResult: Equatable {
    /// The user signed in successfully and the session has been upgraded.
    case completed
    /// The user dismissed the Apple sign-in sheet without completing.
    case cancelled
    /// The sign-in attempt failed for a non-cancellation reason.
    case failed
    /// A sign-in attempt was already in progress; the new call was ignored.
    case alreadyInProgress

    /// A user-facing error message for `.failed`, or `nil` for non-error outcomes.
    var errorMessage: String? {
        switch self {
        case .failed:
            return Strings.Errors.actionFailed
        case .completed, .cancelled, .alreadyInProgress:
            return nil
        }
    }
}

/// Protocol for the shared Sign in with Apple action object.
@MainActor
protocol SignInWithAppleActionProtocol: AnyObject {
    /// `true` while a sign-in attempt is in progress.
    var isSigningIn: Bool { get }
    /// A stream that replays the current `isSigningIn`, then yields de-duplicated changes.
    var isSigningInUpdates: AsyncStream<Bool> { get }

    /// Starts the full Sign in with Apple flow for the given UI context.
    /// - Parameter context: The screen that triggered the action; used for analytics.
    /// - Returns: The outcome of the attempt.
    func signIn(context: SignInWithAppleContext) async -> SignInWithAppleActionResult
}

/// Shared action object that orchestrates the end-to-end Sign in with Apple user flow.
///
/// Coordinates three concerns that would otherwise need to be duplicated across every call site:
/// 1. **Concurrency guard** — `isSigningIn` prevents concurrent sign-in attempts from racing.
/// 2. **Credential acquisition** — delegates to `AppleSignInManaging` to present the system UI.
/// 3. **Session upgrade** — forwards the credential to `AuthServiceProtocol` to link it to the
///    existing anonymous Supabase session.
///
/// Analytics events are fired at the start, on completion, and on failure, regardless of the context.
@MainActor
final class SignInWithAppleAction: SignInWithAppleActionProtocol {
    /// Broadcasts de-duplicated `isSigningIn` changes to the `isSigningInUpdates` stream.
    private let isSigningInBroadcaster = AsyncValueBroadcaster<Bool>(false)

    private(set) var isSigningIn = false {
        didSet {
            if oldValue != isSigningIn { isSigningInBroadcaster.send(isSigningIn) }
        }
    }

    /// A stream that replays the current `isSigningIn`, then yields de-duplicated changes,
    /// useful for driving loading indicators.
    var isSigningInUpdates: AsyncStream<Bool> {
        isSigningInBroadcaster.updates
    }

    private let authService: AuthServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private let appleSignInManager: any AppleSignInManaging

    /// - Parameters:
    ///   - authService: The auth service that will receive the Apple credential for session linking.
    ///   - analyticsService: Tracks sign-in lifecycle events.
    ///   - logger: Used for debug/info/error logging throughout the flow.
    ///   - appleSignInManager: Defaults to `AppleSignInManager()`. Inject a mock in tests.
    init(
        authService: AuthServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        logger: any LoggerProtocol,
        appleSignInManager: (any AppleSignInManaging)? = nil
    ) {
        self.authService = authService
        self.analyticsService = analyticsService
        self.logger = logger
        self.appleSignInManager = appleSignInManager ?? AppleSignInManager()
    }

    /// Runs the full Sign in with Apple flow: presents the system UI, links the credential to the
    /// current Supabase session, and tracks analytics at each stage.
    ///
    /// Returns immediately with `.alreadyInProgress` if a concurrent call is detected. Sets
    /// `isSigningIn = true` for the duration so callers can show a loading state.
    /// - Parameter context: The originating UI context; used for context-specific success logging.
    func signIn(context: SignInWithAppleContext) async -> SignInWithAppleActionResult {
        guard !isSigningIn else { return .alreadyInProgress }

        isSigningIn = true
        analyticsService.track(.signInWithAppleStarted)
        defer { isSigningIn = false }

        do {
            let result = try await appleSignInManager.signIn()
            try await authService.signInWithApple(
                identityToken: result.identityToken,
                nonce: result.nonce
            )
            analyticsService.track(.signInWithAppleCompleted)
            logger.info(context.successLogMessage)
            return .completed
        } catch let error as AuthError where error == .signInCancelled {
            logger.debug("Sign in with Apple cancelled by user")
            return .cancelled
        } catch {
            analyticsService.track(.signInWithAppleFailed)
            // Log only the error type — the raw error can embed Apple/Supabase auth payloads and is
            // forwarded to the crash reporter (Sentry) by the logging service in RELEASE.
            logger.error("Sign in with Apple failed: \(type(of: error))")
            return .failed
        }
    }
}
