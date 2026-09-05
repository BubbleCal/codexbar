import Foundation
import XCTest

final class CodexModelCatalogServiceTests: CodexBarTestCase {
    func testLoadsVisibleModelsAndPreservesHiddenOrUnknownCurrentSelection() throws {
        let cacheURL = self.cacheURL(named: "selection")
        try self.writeCache(
            """
            {
              "models": [
                {"slug":"future-visible","display_name":"Future","visibility":"list","priority":2},
                {"slug":"future-hidden","display_name":"Hidden","visibility":"hide","priority":1}
              ]
            }
            """,
            to: cacheURL
        )
        let catalog = CodexModelCatalogService(cacheURL: cacheURL).catalog()

        XCTAssertEqual(catalog.visibleModelIDs, ["future-visible"])
        XCTAssertEqual(
            CodexBarGlobalSettings.codexModelSelectionOptions(
                including: "future-hidden",
                catalog: catalog
            ),
            ["future-visible", "future-hidden"]
        )
        XCTAssertEqual(
            CodexBarGlobalSettings.codexModelSelectionOptions(
                including: "unknown-current",
                catalog: catalog
            ),
            ["future-visible", "unknown-current"]
        )
    }

    func testUsesFutureReasoningEffortsWithoutAWhitelist() throws {
        let cacheURL = self.cacheURL(named: "reasoning")
        try self.writeCache(
            """
            {"models":[{
              "slug":"future-model",
              "visibility":"list",
              "supported_reasoning_levels":[
                {"effort":"low","description":"quick"},
                {"effort":"hyperspace","description":"future"}
              ],
              "default_reasoning_level":"hyperspace"
            }]}
            """,
            to: cacheURL
        )
        let catalog = CodexModelCatalogService(cacheURL: cacheURL).catalog()

        XCTAssertEqual(
            CodexBarGlobalSettings.reasoningEffortOptions(for: "future-model", catalog: catalog),
            ["low", "hyperspace"]
        )
        XCTAssertTrue(
            CodexBarGlobalSettings.supportsReasoningEffort(
                "hyperspace",
                for: "future-model",
                catalog: catalog
            )
        )
        XCTAssertEqual(catalog.model(for: "future-model")?.defaultReasoningLevel, "hyperspace")
    }

    func testPrefersMaximumContextThenContextAndFallsBackOnlyWhenMissing() throws {
        let cacheURL = self.cacheURL(named: "contexts")
        try self.writeCache(
            """
            {"models":[
              {"slug":"gpt-6-astra","visibility":"list","context_window":272000,"max_context_window":872000},
              {"slug":"future-context","visibility":"list","context_window":333000},
              {"slug":"gpt-5.6-sol","visibility":"list"}
            ]}
            """,
            to: cacheURL
        )
        let catalog = CodexModelCatalogService(cacheURL: cacheURL).catalog()

        XCTAssertEqual(catalog.maximumContextWindow(for: "gpt-6-astra"), 872_000)
        XCTAssertEqual(catalog.maximumContextWindow(for: "future-context"), 333_000)
        XCTAssertEqual(catalog.maximumContextWindow(for: "gpt-5.6-sol"), 1_050_000)
        XCTAssertEqual(catalog.maximumContextWindow(for: "not-in-catalog"), nil)
        XCTAssertEqual(catalog.maximumContextWindow(for: "gpt-5.6"), 1_050_000)
    }

    func testUserContextOverrideWinsForDisplaySyncAndMenuOptions() throws {
        let cacheURL = self.cacheURL(named: "override")
        try self.writeCache(
            #"{"models":[{"slug":"gpt-6-astra","visibility":"list","context_window":272000,"max_context_window":872000}]}"#,
            to: cacheURL
        )
        let catalog = CodexModelCatalogService(cacheURL: cacheURL).catalog()
        let settings = CodexBarGlobalSettings(modelContextWindows: ["gpt-6-astra": 900_000])

        XCTAssertEqual(settings.displayContextWindow(for: "gpt-6-astra", catalog: catalog), 900_000)
        XCTAssertEqual(settings.syncContextWindow(for: "gpt-6-astra", catalog: catalog), 900_000)
        XCTAssertEqual(
            settings.contextWindowSelectionOptions(for: "gpt-6-astra", catalog: catalog),
            [258_000, 512_000, 872_000, 900_000]
        )
    }

    func testReloadsChangedFileAndKeepsLastGoodAfterDamageOrEmptyCatalog() throws {
        let cacheURL = self.cacheURL(named: "reload")
        let service = CodexModelCatalogService(cacheURL: cacheURL)

        try self.writeCache(
            #"{"models":[{"slug":"first","visibility":"list"}]}"#,
            to: cacheURL
        )
        XCTAssertEqual(service.catalog().visibleModelIDs, ["first"])

        try self.writeCache(
            #"{"models":[{"slug":"second","visibility":"list"}]}"#,
            to: cacheURL
        )
        XCTAssertEqual(service.catalog().visibleModelIDs, ["second"])

        try self.writeCache("{broken", to: cacheURL)
        XCTAssertEqual(service.catalog().visibleModelIDs, ["second"])

        try self.writeCache(#"{"models":[]}"#, to: cacheURL)
        XCTAssertEqual(service.catalog().visibleModelIDs, ["second"])
    }

    func testMissingFileUsesFallbackAndLastGoodIsIsolatedByPath() throws {
        let firstURL = self.cacheURL(named: "first-path")
        let secondURL = self.cacheURL(named: "second-path")
        let missingURL = self.cacheURL(named: "missing")
        try self.writeCache(
            #"{"models":[{"slug":"path-one","visibility":"list"}]}"#,
            to: firstURL
        )
        try self.writeCache(
            #"{"models":[{"slug":"path-two","visibility":"list"}]}"#,
            to: secondURL
        )
        let firstService = CodexModelCatalogService(cacheURL: firstURL)
        let secondService = CodexModelCatalogService(cacheURL: secondURL)

        XCTAssertEqual(firstService.catalog().visibleModelIDs, ["path-one"])
        XCTAssertEqual(secondService.catalog().visibleModelIDs, ["path-two"])
        XCTAssertEqual(
            CodexModelCatalogService(cacheURL: missingURL).catalog().visibleModelIDs,
            CodexBarGlobalSettings.codexModelOptions
        )

        try FileManager.default.removeItem(at: firstURL)
        XCTAssertEqual(firstService.catalog().visibleModelIDs, ["path-one"])
        XCTAssertEqual(secondService.catalog().visibleModelIDs, ["path-two"])
    }

    private func cacheURL(named name: String) -> URL {
        CodexPaths.codexRoot.appendingPathComponent("\(name)-models-cache.json")
    }

    private func writeCache(_ text: String, to url: URL) throws {
        try CodexPaths.writeSecureFile(Data(text.utf8), to: url)
    }
}
