import Foundation

/// 一份 Codex `auth.json` 解析出的账号快照。
struct OpenAIAuthJSONSnapshot {
    let account: TokenAccount
    let localAccountID: String
    let remoteAccountID: String
    let email: String?
    let tokenLastRefreshAt: Date?
}

/// Codex `auth.json` 的唯一解析入口。
///
/// `CodexBarConfigStore` 吸收 `~/.codex/auth.json` 和用户手动导入任意 auth.json
/// 都走这里，避免两处解析对字段回退规则的理解产生漂移。
enum OpenAIAuthJSONParser {
    static func snapshot(from auth: [String: Any]) -> OpenAIAuthJSONSnapshot? {
        guard let tokens = auth["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              let refreshToken = tokens["refresh_token"] as? String,
              let idToken = tokens["id_token"] as? String else {
            return nil
        }

        let lastRefresh = self.parseISO8601Date(auth["last_refresh"] as? String)
        let clientID = (auth["client_id"] as? String)
            ?? (tokens["client_id"] as? String)
            ?? (AccountBuilder.decodeJWT(accessToken)["client_id"] as? String)

        var account = AccountBuilder.build(
            from: OAuthTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                idToken: idToken,
                oauthClientID: clientID,
                tokenLastRefreshAt: lastRefresh
            )
        )

        let fallbackRemoteAccountID = tokens["account_id"] as? String ?? ""
        if account.accountId.isEmpty {
            account.accountId = AccountBuilder.localAccountID(fromAccessToken: accessToken)
        }
        if account.accountId.isEmpty {
            account.accountId = fallbackRemoteAccountID
        }
        if account.openAIAccountId.isEmpty {
            account.openAIAccountId = fallbackRemoteAccountID.isEmpty ? account.accountId : fallbackRemoteAccountID
        }
        account.oauthClientID = clientID ?? account.oauthClientID
        account.tokenLastRefreshAt = lastRefresh ?? account.tokenLastRefreshAt

        guard account.accountId.isEmpty == false || account.remoteAccountId.isEmpty == false else {
            return nil
        }

        return OpenAIAuthJSONSnapshot(
            account: account,
            localAccountID: account.accountId,
            remoteAccountID: account.remoteAccountId,
            email: account.email.isEmpty ? nil : account.email,
            tokenLastRefreshAt: lastRefresh ?? account.tokenLastRefreshAt
        )
    }

    static func parseISO8601Date(_ value: String?) -> Date? {
        guard let value, value.isEmpty == false else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
