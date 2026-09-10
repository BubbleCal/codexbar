import Foundation
import XCTest

@MainActor
final class OpenAIAuthJSONPanelServiceTests: XCTestCase {
    func testRequestImportURLActivatesAppBeforePresentingPanel() {
        var events: [String] = []
        let expected = URL(fileURLWithPath: "/tmp/auth.json")
        let service = OpenAIAuthJSONPanelService(
            activateApp: { events.append("activate") },
            requestImportURLAction: {
                events.append("panel")
                return expected
            }
        )

        XCTAssertEqual(service.requestImportURL(), expected)
        // 菜单栏应用不先激活就弹面板,面板会落在其它应用后面。
        XCTAssertEqual(events, ["activate", "panel"])
    }

    func testRequestImportURLReturnsNilWhenCancelled() {
        var didActivate = false
        let service = OpenAIAuthJSONPanelService(
            activateApp: { didActivate = true },
            requestImportURLAction: { nil }
        )

        XCTAssertNil(service.requestImportURL())
        XCTAssertTrue(didActivate)
    }
}
