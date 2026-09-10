import Foundation
import XCTest

final class OpenAIAuthJSONImportServiceTests: CodexBarTestCase {
    private let service = OpenAIAuthJSONImportService()

    /// 按 Codex 真实 auth.json 的形状构造:顶层 auth_mode/client_id/last_refresh/OPENAI_API_KEY + tokens 子对象。
    private func makeAuthJSON(
        from account: TokenAccount,
        clientID: String? = "app_test_client",
        lastRefresh: String? = "2026-09-10T06:18:06Z",
        includeAccountID: Bool = true
    ) -> [String: Any] {
        var tokens: [String: Any] = [
            "access_token": account.accessToken,
            "refresh_token": account.refreshToken,
            "id_token": account.idToken,
        ]
        if includeAccountID {
            tokens["account_id"] = account.openAIAccountId
        }

        var auth: [String: Any] = [
            "auth_mode": "chatgpt",
            "OPENAI_API_KEY": NSNull(),
            "tokens": tokens,
        ]
        if let clientID {
            auth["client_id"] = clientID
        }
        if let lastRefresh {
            auth["last_refresh"] = lastRefresh
        }
        return auth
    }

    func testParseResolvesIdentityFromAuthJSONTokens() throws {
        let source = try self.makeOAuthAccount(
            accountID: "acct_import",
            email: "import@example.com",
            planType: "pro",
            localAccountID: "user-import__acct_import",
            remoteAccountID: "acct_import"
        )

        let parsed = try self.service.parse(self.makeAuthJSON(from: source))

        XCTAssertEqual(parsed.accountId, "user-import__acct_import")
        XCTAssertEqual(parsed.openAIAccountId, "acct_import")
        XCTAssertEqual(parsed.email, "import@example.com")
        XCTAssertEqual(parsed.planType, "pro")
        XCTAssertEqual(parsed.accessToken, source.accessToken)
        XCTAssertEqual(parsed.refreshToken, source.refreshToken)
        XCTAssertEqual(parsed.idToken, source.idToken)
        XCTAssertEqual(parsed.oauthClientID, "app_test_client")
        XCTAssertEqual(
            parsed.tokenLastRefreshAt,
            ISO8601DateFormatter().date(from: "2026-09-10T06:18:06Z")
        )
    }

    func testParseAcceptsDataPayload() throws {
        let source = try self.makeOAuthAccount(accountID: "acct_data", email: "data@example.com")
        let data = try JSONSerialization.data(withJSONObject: self.makeAuthJSON(from: source))

        let parsed = try self.service.parse(data)

        XCTAssertEqual(parsed.email, "data@example.com")
    }

    func testParseFallsBackToTokensClientIDWhenTopLevelMissing() throws {
        let source = try self.makeOAuthAccount(accountID: "acct_client", email: "client@example.com")
        var auth = self.makeAuthJSON(from: source, clientID: nil)
        var tokens = try XCTUnwrap(auth["tokens"] as? [String: Any])
        tokens["client_id"] = "app_nested_client"
        auth["tokens"] = tokens

        let parsed = try self.service.parse(auth)

        XCTAssertEqual(parsed.oauthClientID, "app_nested_client")
    }

    func testParseFallsBackToRemoteAccountIDWhenClaimsLackIdentity() throws {
        // JWT 里没有任何身份 claim 时,应退回 tokens.account_id,而不是产出无法寻址的空账号。
        let accessToken = try self.makeJWT(payload: ["exp": Date(timeIntervalSinceNow: 3_600).timeIntervalSince1970])
        let idToken = try self.makeJWT(payload: ["email": "fallback@example.com"])
        let auth: [String: Any] = [
            "auth_mode": "chatgpt",
            "tokens": [
                "access_token": accessToken,
                "refresh_token": "refresh-token",
                "id_token": idToken,
                "account_id": "acct_fallback",
            ],
        ]

        let parsed = try self.service.parse(auth)

        XCTAssertEqual(parsed.accountId, "acct_fallback")
        XCTAssertEqual(parsed.openAIAccountId, "acct_fallback")
        XCTAssertEqual(parsed.email, "fallback@example.com")
    }

    func testParseRejectsEmptyData() {
        XCTAssertThrowsError(try self.service.parse(Data())) { error in
            XCTAssertEqual(error as? OpenAIAuthJSONImportError, .emptyFile)
        }
    }

    func testParseRejectsInvalidJSON() {
        XCTAssertThrowsError(try self.service.parse(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? OpenAIAuthJSONImportError, .invalidJSON)
        }
    }

    func testParseRejectsAPIKeyOnlyAuthFile() {
        let auth: [String: Any] = ["auth_mode": "apikey", "OPENAI_API_KEY": "sk-test"]

        XCTAssertThrowsError(try self.service.parse(auth)) { error in
            XCTAssertEqual(error as? OpenAIAuthJSONImportError, .notOAuthAuthFile)
        }
    }

    func testParseRejectsAuthFileMissingIDToken() throws {
        let source = try self.makeOAuthAccount(accountID: "acct_partial", email: "partial@example.com")
        var auth = self.makeAuthJSON(from: source)
        var tokens = try XCTUnwrap(auth["tokens"] as? [String: Any])
        tokens.removeValue(forKey: "id_token")
        auth["tokens"] = tokens

        XCTAssertThrowsError(try self.service.parse(auth)) { error in
            XCTAssertEqual(error as? OpenAIAuthJSONImportError, .missingTokens)
        }
    }

    func testParseRejectsBlankTokenValues() throws {
        let source = try self.makeOAuthAccount(accountID: "acct_blank", email: "blank@example.com")
        var auth = self.makeAuthJSON(from: source)
        var tokens = try XCTUnwrap(auth["tokens"] as? [String: Any])
        tokens["refresh_token"] = "   "
        auth["tokens"] = tokens

        XCTAssertThrowsError(try self.service.parse(auth)) { error in
            XCTAssertEqual(error as? OpenAIAuthJSONImportError, .missingTokens)
        }
    }

    func testImportedAccountLandsInPoolWithoutActivating() throws {
        let accountService = CodexBarOAuthAccountService()
        let existing = try self.makeOAuthAccount(accountID: "acct_existing", email: "existing@example.com")
        _ = try accountService.importAccount(existing, activate: true)
        let authBefore = try Data(contentsOf: CodexPaths.authURL)

        let source = try self.makeOAuthAccount(
            accountID: "acct_added",
            email: "added@example.com",
            localAccountID: "user-added__acct_added",
            remoteAccountID: "acct_added"
        )
        let parsed = try self.service.parse(self.makeAuthJSON(from: source))
        let result = try accountService.importAccounts([parsed], activeAccountID: nil)

        XCTAssertEqual(result.addedCount, 1)
        XCTAssertFalse(result.activeChanged)

        let config = try CodexBarConfigStore().loadOrMigrate()
        let provider = try XCTUnwrap(config.providers.first { $0.kind == .openAIOAuth })
        XCTAssertTrue(provider.accounts.contains { $0.email == "added@example.com" })
        XCTAssertEqual(config.active.accountId, existing.accountId)

        // 导入不得覆盖用户当前正在使用的 auth.json 凭据。
        XCTAssertEqual(try Data(contentsOf: CodexPaths.authURL), authBefore)
    }

    func testImportingSameAuthJSONTwiceUpdatesInsteadOfDuplicating() throws {
        let accountService = CodexBarOAuthAccountService()
        let source = try self.makeOAuthAccount(
            accountID: "acct_dup",
            email: "dup@example.com",
            localAccountID: "user-dup__acct_dup",
            remoteAccountID: "acct_dup"
        )
        let auth = self.makeAuthJSON(from: source)

        let first = try accountService.importAccounts([try self.service.parse(auth)], activeAccountID: nil)
        let second = try accountService.importAccounts([try self.service.parse(auth)], activeAccountID: nil)

        XCTAssertEqual(first.addedCount, 1)
        XCTAssertEqual(second.addedCount, 0)
        XCTAssertEqual(second.updatedCount, 1)

        let config = try CodexBarConfigStore().loadOrMigrate()
        let provider = try XCTUnwrap(config.providers.first { $0.kind == .openAIOAuth })
        XCTAssertEqual(provider.accounts.filter { $0.email == "dup@example.com" }.count, 1)
    }
}
