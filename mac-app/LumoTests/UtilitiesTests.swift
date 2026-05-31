import Foundation
import Testing
@testable import Lumo

// NOTE ON CONTRACT DRIFT (read before editing):
// The provided CONTRACT does not match the real source in
// Lumo/Services/TranslationService.swift. The actual code is the source of
// truth here because this file must compile against `@testable import Lumo`:
//
//   * `asTranslationError(_:)` returns `Error` (not `TranslationError`) and
//     maps a `URLError` to `TranslationError.network(_:)` — there is no
//     `.http(status: -1, ...)` wrapping and no `.emptyResponse` case.
//     TranslationError's real cases are: .missingAPIKey, .invalidBaseURL,
//     .http(status:body:), .invalidResponse, .network(String).
//   * `friendlyBody(_:)` is a *private static* method on `TranslationError`
//     (NOT a free function, NOT in accessBumps). It is therefore NOT directly
//     accessible from tests, so it is exercised indirectly through
//     `TranslationError.http(...).errorDescription`, as the contract's own
//     accessBumps note recommends.
//   * `trimmedBaseURL(_:)` matches the contract (internal free function).
//
// This suite covers only the pure helpers the contract scopes for it
// (trimmedBaseURL, asTranslationError mapping, and the friendlyBody JSON
// extraction observed via errorDescription).

@Suite("Utilities helpers")
struct UtilitiesTests {
    // MARK: - trimmedBaseURL

    @Test("trimmedBaseURL strips trailing slashes")
    func trimsTrailingSlashes() {
        #expect(trimmedBaseURL("https://api.openai.com/v1/") == "https://api.openai.com/v1")
    }

    @Test("trimmedBaseURL strips multiple trailing slashes")
    func trimsMultipleTrailingSlashes() {
        #expect(trimmedBaseURL("https://example.test/v1///") == "https://example.test/v1")
    }

    @Test("trimmedBaseURL trims surrounding whitespace and newlines")
    func trimsWhitespace() {
        #expect(trimmedBaseURL("  https://example.test/v1  ") == "https://example.test/v1")
        #expect(trimmedBaseURL("\n\thttps://example.test/v1\n") == "https://example.test/v1")
    }

    @Test("trimmedBaseURL trims whitespace then trailing slashes together")
    func trimsWhitespaceThenSlashes() {
        #expect(trimmedBaseURL("  https://example.test/v1/  ") == "https://example.test/v1")
    }

    @Test("trimmedBaseURL leaves a clean URL intact")
    func leavesCleanURLIntact() {
        #expect(trimmedBaseURL("https://api.anthropic.com/v1") == "https://api.anthropic.com/v1")
    }

    @Test("trimmedBaseURL collapses whitespace/slashes via arguments",
          arguments: [
              ("https://a.test/v1/", "https://a.test/v1"),
              ("https://a.test/v1", "https://a.test/v1"),
              ("  https://a.test/v1//  ", "https://a.test/v1"),
              ("/", ""),
              ("///", ""),
          ])
    func trimsViaArguments(raw: String, expected: String) {
        #expect(trimmedBaseURL(raw) == expected)
    }

    // MARK: - asTranslationError

    @Test("asTranslationError maps a URLError to the .network case")
    func mapsURLErrorToNetwork() {
        let urlError = URLError(.notConnectedToInternet)
        let mapped = asTranslationError(urlError)
        guard case TranslationError.network = mapped else {
            Issue.record("Expected TranslationError.network, got \(mapped)")
            return
        }
    }

    @Test("asTranslationError passes an existing TranslationError through unchanged")
    func passesTranslationErrorThrough() {
        let original = TranslationError.missingAPIKey
        let mapped = asTranslationError(original)
        guard case TranslationError.missingAPIKey = mapped else {
            Issue.record("Expected TranslationError.missingAPIKey to pass through, got \(mapped)")
            return
        }
    }

    @Test("asTranslationError preserves an .http TranslationError's payload")
    func preservesHTTPCasePayload() {
        let original = TranslationError.http(status: 503, body: "boom")
        let mapped = asTranslationError(original)
        guard case let TranslationError.http(status, body) = mapped else {
            Issue.record("Expected TranslationError.http to pass through, got \(mapped)")
            return
        }
        #expect(status == 503)
        #expect(body == "boom")
    }

    @Test("asTranslationError wraps an arbitrary Error as .network")
    func wrapsArbitraryErrorAsNetwork() {
        struct UtilitiesSampleError: Error {}
        let mapped = asTranslationError(UtilitiesSampleError())
        guard case TranslationError.network = mapped else {
            Issue.record("Expected an arbitrary Error to become TranslationError.network, got \(mapped)")
            return
        }
    }

    // MARK: - friendlyBody (exercised via TranslationError.http(...).errorDescription)

    @Test("errorDescription extracts error.message from a JSON body")
    func errorDescriptionExtractsMessage() {
        let json = #"{"error":{"message":"Invalid API key","type":"auth_error"}}"#
        let error = TranslationError.http(status: 401, body: json)
        let description = error.errorDescription ?? ""
        #expect(description.contains("Invalid API key"))
        #expect(!description.contains("auth_error"))
        #expect(description.contains("401"))
    }

    @Test("errorDescription falls back to error.type when message is absent")
    func errorDescriptionFallsBackToType() {
        let json = #"{"error":{"type":"rate_limit_exceeded"}}"#
        let error = TranslationError.http(status: 429, body: json)
        let description = error.errorDescription ?? ""
        #expect(description.contains("rate_limit_exceeded"))
    }

    @Test("errorDescription falls back to the raw body for non-JSON content")
    func errorDescriptionFallsBackToRawBody() {
        let body = "Service Unavailable"
        let error = TranslationError.http(status: 503, body: body)
        let description = error.errorDescription ?? ""
        #expect(description.contains("Service Unavailable"))
    }

    @Test("errorDescription falls back to the raw body when JSON lacks an error object")
    func errorDescriptionFallsBackWhenNoErrorKey() {
        let json = #"{"choices":[]}"#
        let error = TranslationError.http(status: 500, body: json)
        let description = error.errorDescription ?? ""
        #expect(description.contains(json))
    }

    @Test("errorDescription handles an empty body gracefully")
    func errorDescriptionHandlesEmptyBody() {
        let error = TranslationError.http(status: 500, body: "")
        let description = error.errorDescription
        // Should produce a non-empty, descriptive message rather than crashing
        // or returning nil for the .http case.
        #expect(description != nil)
        #expect(!(description ?? "").isEmpty)
    }

    @Test("errorDescription is non-empty for the simple non-http cases")
    func errorDescriptionForSimpleCases() {
        #expect(!(TranslationError.missingAPIKey.errorDescription ?? "").isEmpty)
        #expect(!(TranslationError.invalidBaseURL.errorDescription ?? "").isEmpty)
        #expect(!(TranslationError.invalidResponse.errorDescription ?? "").isEmpty)
        #expect(!(TranslationError.network("offline").errorDescription ?? "").isEmpty)
    }
}
