import Combine
import Foundation

enum SignInWithAppleContext {
    case journey
    case settings

    var successLogMessage: String {
        switch self {
        case .journey:
            return "Sign in with Apple completed from My Kitchen"
        case .settings:
            return "Sign in with Apple completed"
        }
    }
}

enum SignInWithAppleActionResult: Equatable {
    case completed
    case cancelled
    case failed
    case alreadyInProgress

    var errorMessage: String? {
        switch self {
        case .failed:
            return Strings.Errors.actionFailed
        case .completed, .cancelled, .alreadyInProgress:
            return nil
        }
    }
}

@MainActor
protocol SignInWithAppleActionProtocol: AnyObject {
    var isSigningIn: Bool { get }
    var isSigningInPublisher: AnyPublisher<Bool, Never> { get }

    func signIn(context: SignInWithAppleContext) async -> SignInWithAppleActionResult
}

@MainActor
final class SignInWithAppleAction: SignInWithAppleActionProtocol {
    @Published private(set) var isSigningIn = false

    var isSigningInPublisher: AnyPublisher<Bool, Never> {
        $isSigningIn
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let authService: AuthServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private let appleSignInManager: any AppleSignInManaging

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
            logger.error("Sign in with Apple failed: \(String(describing: error))")
            return .failed
        }
    }
}
