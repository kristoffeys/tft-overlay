@testable import LCUClient
import XCTest

final class LCUClientTests: XCTestCase {
    func testClientReportsUnavailableOnMacOS() async {
        let client = LCUClient()
        XCTAssertFalse(client.isAvailable)

        do {
            try await client.connect()
            XCTFail("connect() should throw on macOS")
        } catch LCUError.unavailableOnMacOS {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
