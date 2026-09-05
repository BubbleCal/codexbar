import Foundation

struct CodexModelCatalog: Equatable {
    struct ReasoningLevel: Equatable {
        var effort: String
        var description: String?
    }

    struct Model: Equatable {
        var slug: String
        var displayName: String
        var isVisible: Bool
        var supportedReasoningLevels: [ReasoningLevel]?
        var contextWindow: Int?
        var maxContextWindow: Int?
        var defaultReasoningLevel: String?
    }

    static let fallback = CodexModelCatalog(
        models: [
            Model(
                slug: "gpt-6-astra",
                displayName: "GPT-6-Astra",
                isVisible: true,
                supportedReasoningLevels: Self.reasoningLevels(["low", "medium", "high", "xhigh", "max", "ultra"]),
                contextWindow: 258_000,
                maxContextWindow: 1_050_000,
                defaultReasoningLevel: "medium"
            ),
            Model(
                slug: "gpt-5.6-sol",
                displayName: "GPT-5.6-Sol",
                isVisible: true,
                supportedReasoningLevels: Self.reasoningLevels(["low", "medium", "high", "xhigh", "max", "ultra"]),
                contextWindow: 258_000,
                maxContextWindow: 1_050_000,
                defaultReasoningLevel: "medium"
            ),
            Model(
                slug: "gpt-5.6-terra",
                displayName: "GPT-5.6-Terra",
                isVisible: true,
                supportedReasoningLevels: Self.reasoningLevels(["low", "medium", "high", "xhigh", "max", "ultra"]),
                contextWindow: 258_000,
                maxContextWindow: 1_050_000,
                defaultReasoningLevel: "medium"
            ),
            Model(
                slug: "gpt-5.6-luna",
                displayName: "GPT-5.6-Luna",
                isVisible: true,
                supportedReasoningLevels: Self.reasoningLevels(["low", "medium", "high", "xhigh", "max"]),
                contextWindow: 258_000,
                maxContextWindow: 1_050_000,
                defaultReasoningLevel: "medium"
            ),
            Model(
                slug: "gpt-5.6",
                displayName: "GPT-5.6",
                isVisible: false,
                supportedReasoningLevels: nil,
                contextWindow: 258_000,
                maxContextWindow: 1_050_000,
                defaultReasoningLevel: nil
            ),
        ]
    )

    var models: [Model]

    var visibleModelIDs: [String] {
        self.models.filter(\.isVisible).map(\.slug)
    }

    func model(for modelID: String) -> Model? {
        let normalizedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return self.models.first { $0.slug.lowercased() == normalizedModelID }
    }

    func reasoningEfforts(for modelID: String) -> [String]? {
        guard let model = self.model(for: modelID) else {
            return Self.fallbackModel(for: modelID)?.supportedReasoningLevels?.map(\.effort)
        }
        if let levels = model.supportedReasoningLevels {
            return levels.map(\.effort)
        }
        return Self.fallbackModel(for: model.slug)?.supportedReasoningLevels?.map(\.effort)
    }

    func maximumContextWindow(for modelID: String) -> Int? {
        guard let model = self.model(for: modelID) else {
            return Self.fallbackModel(for: modelID).flatMap(Self.maximumContextWindow(for:))
        }
        return Self.maximumContextWindow(for: model)
            ?? Self.fallbackModel(for: model.slug).flatMap(Self.maximumContextWindow(for:))
    }

    private static func maximumContextWindow(for model: Model) -> Int? {
        if let maxContextWindow = model.maxContextWindow, maxContextWindow > 0 {
            return maxContextWindow
        }
        if let contextWindow = model.contextWindow, contextWindow > 0 {
            return contextWindow
        }
        return nil
    }

    private static func fallbackModel(for modelID: String) -> Model? {
        let normalizedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Self.fallback.models.first { $0.slug.lowercased() == normalizedModelID }
    }

    private static func reasoningLevels(_ efforts: [String]) -> [ReasoningLevel] {
        efforts.map { ReasoningLevel(effort: $0, description: nil) }
    }
}

protocol CodexModelCatalogLoading: AnyObject {
    func catalog() -> CodexModelCatalog
}

final class CodexModelCatalogService: CodexModelCatalogLoading {
    private struct CachePayload: Decodable {
        var models: [ModelPayload]
    }

    private struct ModelPayload: Decodable {
        struct ReasoningLevelPayload: Decodable {
            var effort: String
            var description: String?
        }

        var slug: String
        var displayName: String?
        var visibility: String?
        var supportedReasoningLevels: [ReasoningLevelPayload]?
        var contextWindow: Int?
        var maxContextWindow: Int?
        var defaultReasoningLevel: String?
        var priority: Int?

        enum CodingKeys: String, CodingKey {
            case slug
            case displayName = "display_name"
            case visibility
            case supportedReasoningLevels = "supported_reasoning_levels"
            case contextWindow = "context_window"
            case maxContextWindow = "max_context_window"
            case defaultReasoningLevel = "default_reasoning_level"
            case priority
        }
    }

    private let cacheURL: URL
    private let readData: (URL) throws -> Data
    private let lock = NSLock()
    private var lastObservedData: Data?
    private var lastGoodCatalog: CodexModelCatalog?

    init(
        cacheURL: URL = CodexPaths.modelsCacheURL,
        readData: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) }
    ) {
        self.cacheURL = cacheURL
        self.readData = readData
    }

    func catalog() -> CodexModelCatalog {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let data = try? self.readData(self.cacheURL) else {
            self.lastObservedData = nil
            return self.lastGoodCatalog ?? .fallback
        }
        guard data != self.lastObservedData else {
            return self.lastGoodCatalog ?? .fallback
        }

        self.lastObservedData = data
        guard let payload = try? JSONDecoder().decode(CachePayload.self, from: data) else {
            return self.lastGoodCatalog ?? .fallback
        }

        var seenModelIDs: Set<String> = []
        let orderedModels = payload.models.enumerated().sorted { lhs, rhs in
            let leftPriority = lhs.element.priority ?? Int.max
            let rightPriority = rhs.element.priority ?? Int.max
            return leftPriority == rightPriority ? lhs.offset < rhs.offset : leftPriority < rightPriority
        }.map(\.element)
        let models = orderedModels.compactMap { model -> CodexModelCatalog.Model? in
            let slug = model.slug.trimmingCharacters(in: .whitespacesAndNewlines)
            guard slug.isEmpty == false,
                  seenModelIDs.insert(slug.lowercased()).inserted else {
                return nil
            }

            let displayName = model.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let supportedReasoningLevels = model.supportedReasoningLevels.map { levels in
                var seenEfforts: Set<String> = []
                return levels.compactMap { level -> CodexModelCatalog.ReasoningLevel? in
                    let effort = level.effort.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard effort.isEmpty == false,
                          seenEfforts.insert(effort).inserted else {
                        return nil
                    }
                    let description = level.description?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return CodexModelCatalog.ReasoningLevel(
                        effort: effort,
                        description: description?.isEmpty == false ? description : nil
                    )
                }
            }
            let defaultReasoningLevel = model.defaultReasoningLevel?.trimmingCharacters(in: .whitespacesAndNewlines)

            return CodexModelCatalog.Model(
                slug: slug,
                displayName: displayName?.isEmpty == false ? displayName! : slug,
                isVisible: model.visibility == "list",
                supportedReasoningLevels: supportedReasoningLevels,
                contextWindow: Self.positive(model.contextWindow),
                maxContextWindow: Self.positive(model.maxContextWindow),
                defaultReasoningLevel: defaultReasoningLevel?.isEmpty == false ? defaultReasoningLevel : nil
            )
        }

        guard models.isEmpty == false else {
            return self.lastGoodCatalog ?? .fallback
        }
        let catalog = CodexModelCatalog(models: models)
        self.lastGoodCatalog = catalog
        return catalog
    }

    private static func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
