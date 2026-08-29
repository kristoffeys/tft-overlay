@testable import TFTOverlay
import XCTest

final class DiagnosticsRedactorTests: XCTestCase {
    func testRedactsHomeDirectory() {
        let text = "Loaded fixture from /Users/kristof/Library/Application Support/TFTOverlay"
        let redacted = DiagnosticsRedactor.redact(
            text,
            userName: "kristof",
            fullName: "Kristof Feys",
            homeDirectory: "/Users/kristof"
        )
        XCTAssertFalse(redacted.contains("/Users/kristof"))
        XCTAssertTrue(redacted.contains("/Users/<redacted>"))
    }

    func testRedactsUserNameAndFullNameOccurrences() {
        let text = "Signed in as kristof (Kristof Feys) via some log line"
        let redacted = DiagnosticsRedactor.redact(
            text,
            userName: "kristof",
            fullName: "Kristof Feys",
            homeDirectory: ""
        )
        XCTAssertFalse(redacted.contains("kristof"))
        XCTAssertFalse(redacted.contains("Kristof Feys"))
    }

    func testRedactsEmailAddresses() {
        let text = "Crash report submitted by kristof@weareantenna.be"
        let redacted = DiagnosticsRedactor.redact(text, userName: "", fullName: "", homeDirectory: "")
        XCTAssertFalse(redacted.contains("kristof@weareantenna.be"))
        XCTAssertTrue(redacted.contains("<redacted-email>"))
    }

    func testRedactsOtherUsersHomeDirectoryEvenIfNotCurrentUser() {
        // A log line referencing a *different* account's home directory
        // than the one running the export must still be caught.
        let text = "Found stray file at /Users/someoneElse/Downloads/thing.txt"
        let redacted = DiagnosticsRedactor.redact(
            text,
            userName: "kristof",
            fullName: "Kristof Feys",
            homeDirectory: "/Users/kristof"
        )
        XCTAssertFalse(redacted.contains("someoneElse"))
    }

    func testLeavesUnrelatedTextUntouched() {
        let text = "Overlay opacity set to 0.9, layoutMode=expanded"
        XCTAssertEqual(
            DiagnosticsRedactor
                .redact(text, userName: "kristof", fullName: "Kristof Feys", homeDirectory: "/Users/kristof"),
            text
        )
    }

    @MainActor
    func testReportRenderingAppliesRedaction() {
        let report = DiagnosticsReport(
            generatedAt: Date(timeIntervalSince1970: 0),
            appVersion: "0.1.0",
            osVersion: "macOS 14.0",
            activeDataPatch: "auto",
            overlayGeometryDescription: "frame=(0,0,1,1)",
            recentLogLines: ["Loaded settings from /Users/kristof/Library/Preferences/dev.tftoverlay.app.plist"]
        )

        let rendered = report.renderedText { text in
            DiagnosticsRedactor.redact(
                text,
                userName: "kristof",
                fullName: "Kristof Feys",
                homeDirectory: "/Users/kristof"
            )
        }

        XCTAssertFalse(rendered.contains("/Users/kristof"))
        XCTAssertTrue(rendered.contains("App version: 0.1.0"))
    }
}
