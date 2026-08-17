import XCTest

final class MenuBarOpenRefreshGateTests: XCTestCase {
    func testMenuOpenRefreshScansSessionCacheWithThrottle() {
        XCTAssertTrue(MenuBarRefreshOrigin.menuOpen.refreshesSessionCache)
        XCTAssertEqual(MenuBarRefreshOrigin.menuOpen.localCostMinimumInterval, 2 * 60)
        XCTAssertFalse(MenuBarRefreshOrigin.menuOpen.forcesLocalCostRefresh)
    }

    func testManualRefreshScansSessionCacheImmediately() {
        XCTAssertTrue(MenuBarRefreshOrigin.manual.refreshesSessionCache)
        XCTAssertEqual(MenuBarRefreshOrigin.manual.localCostMinimumInterval, 0)
        XCTAssertTrue(MenuBarRefreshOrigin.manual.forcesLocalCostRefresh)
    }

    func testFirstOpenTriggersRefreshWhenIdle() {
        var gate = MenuBarOpenRefreshGate()

        XCTAssertTrue(gate.shouldTriggerRefresh(isRefreshing: false))
    }

    func testSecondOpenInSamePresentationDoesNotTriggerAgain() {
        var gate = MenuBarOpenRefreshGate()

        XCTAssertTrue(gate.shouldTriggerRefresh(isRefreshing: false))
        XCTAssertFalse(gate.shouldTriggerRefresh(isRefreshing: false))
    }

    func testCloseResetsGateForNextOpen() {
        var gate = MenuBarOpenRefreshGate()

        XCTAssertTrue(gate.shouldTriggerRefresh(isRefreshing: false))
        gate.resetForClose()

        XCTAssertTrue(gate.shouldTriggerRefresh(isRefreshing: false))
    }

    func testOpenWhileRefreshAlreadyRunningStillConsumesPresentation() {
        var gate = MenuBarOpenRefreshGate()

        XCTAssertFalse(gate.shouldTriggerRefresh(isRefreshing: true))
        XCTAssertFalse(gate.shouldTriggerRefresh(isRefreshing: false))
        gate.resetForClose()
        XCTAssertTrue(gate.shouldTriggerRefresh(isRefreshing: false))
    }
}
