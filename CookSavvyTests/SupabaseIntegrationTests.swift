//
//  SupabaseIntegrationTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

@MainActor
final class SupabaseIntegrationTests: XCTestCase {
    private var harness: SupabaseTestHarness?

    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = try SupabaseTestHarness.makeOrSkip()
    }

    override func tearDownWithError() throws {
        harness = nil
        try super.tearDownWithError()
    }

    func testAnonymousAuthFlowProvidesAccessToken() async throws {
        let harness = try requireHarness()
        let authService = SupabaseAuthService(
            clientProvider: harness.clientProvider,
            analyticsService: MockAnalyticsService(),
            logger: MockLogger()
        )
        try await authService.signOut()

        XCTAssertEqual(authService.authState, AuthState.signedOut)
        XCTAssertNil(authService.currentUserId)

        try await authService.signInAnonymously()

        guard case .signedIn(let userId) = authService.authState else {
            return XCTFail("Expected signed-in auth state after anonymous sign-in")
        }

        XCTAssertFalse(userId.isEmpty)
        XCTAssertEqual(authService.currentUserId, userId)

        let token = try await authService.accessToken()
        XCTAssertFalse(token.isEmpty)

        try await authService.signOut()
        XCTAssertEqual(authService.authState, AuthState.signedOut)
        XCTAssertNil(authService.currentUserId)
    }

    func testRecipeSearchProviderEndToEndReturnsRecipes() async throws {
        let harness = try requireHarness()
        try await harness.ensureAnonymousSession()

        let provider = SupabaseRecipeAPIProvider(
            clientProvider: harness.clientProvider,
            configuration: harness.configuration
        )

        let isAvailable = await provider.isAvailable()
        XCTAssertTrue(isAvailable)

        let recipes = try await provider.fetchRecipes(
            for: [Ingredient(name: "chicken"), Ingredient(name: "rice"), Ingredient(name: "broccoli")],
            count: 3
        )

        XCTAssertFalse(recipes.isEmpty)
        XCTAssertLessThanOrEqual(recipes.count, 3)
        XCTAssertFalse(recipes[0].title.isEmpty)
        XCTAssertFalse(recipes[0].ingredients.isEmpty)
        XCTAssertFalse(recipes[0].instructions.isEmpty)
    }

    func testAIRecipeGenerationEndToEndReturnsRecipes() async throws {
        let harness = try requireHarness()
        try await harness.ensureAnonymousSession()

        let aiService = AIService(
            provider: SupabaseLLMProvider(clientProvider: harness.clientProvider)
        )

        let recipes = try await aiService.generateRecipes(
            for: [Ingredient(name: "tomato"), Ingredient(name: "basil"), Ingredient(name: "mozzarella")],
            count: 2
        )

        XCTAssertFalse(recipes.isEmpty)
        XCTAssertLessThanOrEqual(recipes.count, 2)
        XCTAssertFalse(recipes[0].title.isEmpty)
        XCTAssertFalse(recipes[0].ingredients.isEmpty)
        XCTAssertFalse(recipes[0].instructions.isEmpty)
    }

    func testIngredientDetectionEndToEndWithConfiguredFixtureImage() async throws {
        let harness = try requireHarness()
        let imageData = try XCTUnwrap(harness.fixtureImageData, "Set SUPABASE_TEST_IMAGE_BASE64 to enable the vision integration test")

        try await harness.ensureAnonymousSession()

        let aiService = AIService(
            provider: SupabaseLLMProvider(clientProvider: harness.clientProvider)
        )

        let ingredients = try await aiService.detectIngredients(from: imageData)

        XCTAssertFalse(ingredients.isEmpty)
        XCTAssertFalse(ingredients[0].name.isEmpty)
    }

    private func requireHarness() throws -> SupabaseTestHarness {
        try XCTUnwrap(harness)
    }
}

@MainActor
private final class SupabaseTestHarness {
    let configuration: SupabaseConfiguration
    let clientProvider: SupabaseClientProvider
    let fixtureImageData: Data?

    private init(
        configuration: SupabaseConfiguration,
        clientProvider: SupabaseClientProvider,
        fixtureImageData: Data?
    ) {
        self.configuration = configuration
        self.clientProvider = clientProvider
        self.fixtureImageData = fixtureImageData
    }

    static func makeOrSkip(file: StaticString = #filePath, line: UInt = #line) throws -> SupabaseTestHarness {
        let values = try SupabaseIntegrationConfiguration.loadOrSkip(file: file, line: line)
        let configuration = SupabaseConfiguration(
            projectURL: values.projectURL,
            anonKey: values.anonKey
        )
        let clientProvider = SupabaseClientProvider(
            projectURL: values.projectURL,
            anonKey: values.anonKey
        )

        return SupabaseTestHarness(
            configuration: configuration,
            clientProvider: clientProvider,
            fixtureImageData: values.fixtureImageData
        )
    }

    func ensureAnonymousSession() async throws {
        if clientProvider.client.auth.currentSession != nil {
            return
        }

        let authService = SupabaseAuthService(
            clientProvider: clientProvider,
            analyticsService: MockAnalyticsService(),
            logger: MockLogger()
        )
        try await authService.signInAnonymously()
    }
}

private struct SupabaseIntegrationConfiguration {
    let projectURL: URL
    let anonKey: String
    let fixtureImageData: Data?

    static func loadOrSkip(file: StaticString = #filePath, line: UInt = #line) throws -> SupabaseIntegrationConfiguration {
        let environment = ProcessInfo.processInfo.environment

        let projectURLString = environment["SUPABASE_URL"] ?? plistValue(for: "SUPABASE_URL")
        let anonKey = environment["SUPABASE_ANON_KEY"] ?? plistValue(for: "SUPABASE_ANON_KEY")

        guard
            let projectURLString,
            let projectURL = URL(string: projectURLString),
            let anonKey,
            !anonKey.isEmpty
        else {
            throw XCTSkip("""
                Supabase integration tests require SUPABASE_URL and SUPABASE_ANON_KEY.
                Provide them as environment variables or in CookSavvy/Support/APIKeys.plist.
                """)
        }
        
        let fixtureImageData =
            environment["SUPABASE_TEST_IMAGE_BASE64"].flatMap { encoded in
                Data(base64Encoded: encoded)
            } ?? bundledFixtureImageData()

        return SupabaseIntegrationConfiguration(
            projectURL: projectURL,
            anonKey: anonKey,
            fixtureImageData: fixtureImageData
        )
    }

    private static func plistValue(for key: String) -> String? {
        for bundle in candidateBundles {
            guard
                let path = bundle.path(forResource: "APIKeys", ofType: "plist"),
                let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any],
                let value = dictionary[key] as? String
            else {
                continue
            }

            return value
        }

        return nil
    }

    private static func bundledFixtureImageData() -> Data? {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixtureURL = testsDirectory.appendingPathComponent("Fixtures/supabase-test-image.png")
        return try? Data(contentsOf: fixtureURL)
    }

    private static var candidateBundles: [Bundle] {
        var bundles = [Bundle(for: BundleMarker.self), .main]

        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var seenPaths = Set<String>()
        return bundles.filter { bundle in
            let path = bundle.bundleURL.path
            guard !seenPaths.contains(path) else { return false }
            seenPaths.insert(path)
            return true
        }
    }

    private final class BundleMarker {}
}
