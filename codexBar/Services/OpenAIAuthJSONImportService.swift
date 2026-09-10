import Foundation

enum OpenAIAuthJSONImportError: LocalizedError, Equatable {
    case emptyFile
    case invalidJSON
    case notOAuthAuthFile
    case missingTokens
    case unresolvableAccount

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return L.openAIAuthJSONEmptyFile
        case .invalidJSON:
            return L.openAIAuthJSONInvalidFile
        case .notOAuthAuthFile:
            return L.openAIAuthJSONNotOAuthFile
        case .missingTokens:
            return L.openAIAuthJSONMissingTokens
        case .unresolvableAccount:
            return L.openAIAuthJSONUnresolvableAccount
        }
    }
}

/// 把用户挑选的任意 Codex `auth.json` 解析成可导入的账号。
///
/// 只负责读取与校验；写入账号池由 `CodexBarOAuthAccountService` 完成。
struct OpenAIAuthJSONImportService {
    func parse(_ data: Data) throws -> TokenAccount {
        guard data.isEmpty == false else {
            throw OpenAIAuthJSONImportError.emptyFile
        }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let auth = object as? [String: Any] else {
            throw OpenAIAuthJSONImportError.invalidJSON
        }
        return try self.parse(auth)
    }

    func parse(_ auth: [String: Any]) throws -> TokenAccount {
        guard auth.isEmpty == false else {
            throw OpenAIAuthJSONImportError.emptyFile
        }

        // 仅 API key 模式的 auth.json 没有 OAuth 账号可导入,单独区分以便给出可行动的提示。
        guard let tokens = auth["tokens"] as? [String: Any], tokens.isEmpty == false else {
            throw OpenAIAuthJSONImportError.notOAuthAuthFile
        }
        guard self.hasNonEmptyString(tokens["access_token"]),
              self.hasNonEmptyString(tokens["refresh_token"]),
              self.hasNonEmptyString(tokens["id_token"]) else {
            throw OpenAIAuthJSONImportError.missingTokens
        }
        guard let snapshot = OpenAIAuthJSONParser.snapshot(from: auth) else {
            throw OpenAIAuthJSONImportError.unresolvableAccount
        }

        var account = snapshot.account
        // 解析出的 JWT 声明可能不含身份信息,回退到 tokens.account_id 以免账号无法寻址。
        if account.accountId.isEmpty {
            account.accountId = snapshot.remoteAccountID
        }
        guard account.accountId.isEmpty == false else {
            throw OpenAIAuthJSONImportError.unresolvableAccount
        }
        return account
    }

    private func hasNonEmptyString(_ value: Any?) -> Bool {
        guard let text = value as? String else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
