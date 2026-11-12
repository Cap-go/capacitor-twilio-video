import XCTest
@testable import CapacitorTwilioVideoPlugin

class CapacitorTwilioVideoTests: XCTestCase {
    private let validToken =
        "eyJhbGciOiJub25lIn0.eyJleHAiOjQxMDI0NDQ4MDAsImdyYW50cyI6eyJpZGVudGl0eSI6InRlc3QifX0.x"
    private let expiredToken =
        "eyJhbGciOiJub25lIn0.eyJleHAiOjEsImdyYW50cyI6eyJpZGVudGl0eSI6InRlc3QifX0.x"

    func testEcho() {
        let implementation = CapacitorTwilioVideo()
        let value = "Hello, World!"
        let result = implementation.echo(value)

        XCTAssertEqual(value, result)
    }

    func testTokenValidationAcceptsFutureExpiration() {
        let implementation = CapacitorTwilioVideo()
        XCTAssertTrue(implementation.isTokenValid(validToken))
    }

    func testTokenValidationRejectsExpiredToken() {
        let implementation = CapacitorTwilioVideo()
        XCTAssertFalse(implementation.isTokenValid(expiredToken))
    }

    func testExtractIdentityFromGrant() {
        let implementation = CapacitorTwilioVideo()
        XCTAssertEqual(implementation.extractIdentity(from: validToken), "test")
    }
}
