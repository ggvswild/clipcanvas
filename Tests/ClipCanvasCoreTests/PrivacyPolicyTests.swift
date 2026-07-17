import Foundation
import XCTest
@testable import ClipCanvasCore

final class PrivacyPolicyTests: XCTestCase {
    func testInternalMarkerIsIgnoredFirst() {
        let policy = PrivacyPolicy(configuration: .init())
        let candidate = CaptureCandidate(
            sourceBundleID: "dev.clipcanvas.app",
            types: [PrivacyPolicy.internalMarkerType],
            plainText: "ordinary"
        )

        XCTAssertEqual(policy.evaluate(candidate), .ignored(.internalWrite))
    }

    func testConcealedAndTransientTypesAreIgnored() {
        let policy = PrivacyPolicy(configuration: .init())

        XCTAssertEqual(
            policy.evaluate(
                .init(
                    sourceBundleID: "com.apple.TextEdit",
                    types: ["org.nspasteboard.ConcealedType"],
                    plainText: "hidden"
                )
            ),
            .ignored(.concealed)
        )
        XCTAssertEqual(
            policy.evaluate(
                .init(
                    sourceBundleID: "com.apple.TextEdit",
                    types: ["org.nspasteboard.TransientType"],
                    plainText: "temporary"
                )
            ),
            .ignored(.transient)
        )
    }

    func testIgnoredBundleIDWins() {
        let policy = PrivacyPolicy(
            configuration: .init(ignoredBundleIDs: ["com.apple.Passwords"])
        )

        XCTAssertEqual(
            policy.evaluate(
                .init(
                    sourceBundleID: "com.apple.Passwords",
                    types: ["public.utf8-plain-text"],
                    plainText: "not inspected"
                )
            ),
            .ignored(.ignoredApplication)
        )
    }

    func testPrivateKeyAndHighConfidenceTokenAreConfidential() {
        let policy = PrivacyPolicy(configuration: .init())

        XCTAssertEqual(
            policy.evaluate(
                .init(
                    sourceBundleID: "com.apple.TextEdit",
                    types: ["public.utf8-plain-text"],
                    plainText: "-----BEGIN PRIVATE KEY-----\nabc"
                )
            ),
            .ignored(.confidential)
        )
        XCTAssertEqual(
            policy.evaluate(
                .init(
                    sourceBundleID: "com.apple.TextEdit",
                    types: ["public.utf8-plain-text"],
            plainText: "api_key = \"local_fixture_token_1234567890\""
                )
            ),
            .ignored(.confidential)
        )
    }

    func testOrdinaryCodeIsAllowedAndConfidentialDetectionCanBeDisabled() {
        XCTAssertEqual(
            PrivacyPolicy(configuration: .init()).evaluate(
                .init(
                    sourceBundleID: "com.apple.dt.Xcode",
                    types: ["public.utf8-plain-text"],
                    plainText: "let apiKeyName = \"example\""
                )
            ),
            .allowed
        )
        XCTAssertEqual(
            PrivacyPolicy(
                configuration: .init(ignoreConfidential: false)
            ).evaluate(
                .init(
                    sourceBundleID: "com.apple.TextEdit",
                    types: ["public.utf8-plain-text"],
                    plainText: "-----BEGIN PRIVATE KEY-----\nabc"
                )
            ),
            .allowed
        )
    }
}
