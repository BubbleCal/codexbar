import Foundation

enum MenuBarIconResolver {
    static func iconName(
        accounts: [TokenAccount],
        activeProviderKind: CodexBarProviderKind?
    ) -> String {
        if let active = accounts.first(where: { $0.isActive }) {
            return self.iconName(
                for: [active],
                fallbackProviderKind: activeProviderKind
            )
        }

        if activeProviderKind == .openAICompatible || activeProviderKind == .openRouter {
            return "network"
        }

        return self.iconName(
            for: accounts,
            fallbackProviderKind: activeProviderKind
        )
    }

    private static func iconName(
        for accounts: [TokenAccount],
        fallbackProviderKind: CodexBarProviderKind?
    ) -> String {
        if accounts.contains(where: { $0.isBanned }) {
            return "xmark.circle.fill"
        }
        if fallbackProviderKind == .openAICompatible || fallbackProviderKind == .openRouter {
            return "network"
        }
        return "terminal.fill"
    }
}
