import XCTest

@MainActor
final class AppLifecycleDiagnosticsTests: XCTestCase {
    private final class LifecycleSpy: LifecycleControlling {
        private(set) var startCount = 0
        private(set) var stopCount = 0

        func start() {
            self.startCount += 1
        }

        func stop() {
            self.stopCount += 1
        }
    }

    private final class OAuthRefreshSpy: OAuthRefreshLifecycleControlling {
        private(set) var startCount = 0
        private(set) var stopCount = 0
        private(set) var refreshDueAccountsCount = 0

        func start() {
            self.startCount += 1
        }

        func stop() {
            self.stopCount += 1
        }

        func refreshDueAccountsNow() async {
            self.refreshDueAccountsCount += 1
        }
    }

    private final class TokenStoreSpy: TokenStoreReloading {
        private(set) var loadCount = 0

        func load() {
            self.loadCount += 1
        }
    }

    private final class MenuHostCleanerSpy: MenuHostLegacyCleaning {
        var result = MenuHostLegacyCleanupResult()
        private(set) var cleanupCount = 0

        func cleanupLegacyArtifacts() -> MenuHostLegacyCleanupResult {
            self.cleanupCount += 1
            return self.result
        }
    }

    func testStartCleansLegacyArtifactsThenStartsSingleProcessServices() {
        let host = LifecycleSpy()
        let usage = LifecycleSpy()
        let oauth = OAuthRefreshSpy()
        let store = TokenStoreSpy()
        let cleaner = MenuHostCleanerSpy()
        cleaner.result = MenuHostLegacyCleanupResult(removedLease: true)
        var events: [String] = []

        let controller = SingleProcessAppRuntimeController(
            statusItemHost: host,
            usagePolling: usage,
            oauthRefresh: oauth,
            tokenStore: store,
            legacyMenuHostCleaner: cleaner
        ) { type, _ in
            events.append(type)
        }

        controller.start()

        XCTAssertEqual(cleaner.cleanupCount, 1)
        XCTAssertEqual(store.loadCount, 1)
        XCTAssertEqual(host.startCount, 1)
        XCTAssertEqual(usage.startCount, 1)
        XCTAssertEqual(oauth.startCount, 1)
        XCTAssertEqual(events, ["legacy_menu_host_cleaned", "single_process_runtime_services_started"])
    }

    func testStartSkipsLegacyCleanupEventWhenNothingNeededCleaning() {
        var events: [String] = []
        let controller = SingleProcessAppRuntimeController(
            statusItemHost: LifecycleSpy(),
            usagePolling: LifecycleSpy(),
            oauthRefresh: OAuthRefreshSpy(),
            tokenStore: TokenStoreSpy(),
            legacyMenuHostCleaner: MenuHostCleanerSpy()
        ) { type, _ in
            events.append(type)
        }

        controller.start()

        XCTAssertEqual(events, ["single_process_runtime_services_started"])
    }

    func testHandleApplicationDidBecomeActiveReloadsStoreAndRefreshesOAuth() async {
        let store = TokenStoreSpy()
        let oauth = OAuthRefreshSpy()
        let controller = SingleProcessAppRuntimeController(
            statusItemHost: LifecycleSpy(),
            usagePolling: LifecycleSpy(),
            oauthRefresh: oauth,
            tokenStore: store,
            legacyMenuHostCleaner: MenuHostCleanerSpy()
        ) { _, _ in }

        await controller.handleApplicationDidBecomeActive()

        XCTAssertEqual(store.loadCount, 1)
        XCTAssertEqual(oauth.refreshDueAccountsCount, 1)
    }

    func testStopStopsRuntimeServicesAndRecordsEvent() {
        let host = LifecycleSpy()
        let usage = LifecycleSpy()
        let oauth = OAuthRefreshSpy()
        var events: [String] = []

        let controller = SingleProcessAppRuntimeController(
            statusItemHost: host,
            usagePolling: usage,
            oauthRefresh: oauth,
            tokenStore: TokenStoreSpy(),
            legacyMenuHostCleaner: MenuHostCleanerSpy()
        ) { type, _ in
            events.append(type)
        }

        controller.stop()

        XCTAssertEqual(oauth.stopCount, 1)
        XCTAssertEqual(usage.stopCount, 1)
        XCTAssertEqual(host.stopCount, 1)
        XCTAssertEqual(events, ["single_process_runtime_services_stopped"])
    }
}
