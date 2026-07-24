import Foundation

struct TodoTask: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var description: String?
    var tags: [String]
    var completed: Bool
    var reminderAt: Date?
    var reminderFiredAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Double

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        tags: [String] = [],
        completed: Bool = false,
        reminderAt: Date? = nil,
        reminderFiredAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.tags = Self.normalizedTags(tags)
        self.completed = completed
        self.reminderAt = reminderAt
        self.reminderFiredAt = reminderFiredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }

    static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { tag in
            let normalized = tag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard !normalized.isEmpty, seen.insert(normalized.lowercased()).inserted else { return nil }
            return normalized
        }
    }

    var reminderIsDue: Bool {
        guard !completed, reminderFiredAt == nil, let reminderAt else { return false }
        return reminderAt <= Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case tags
        case completed
        case dueDate
        case reminderAt
        case reminderFiredAt
        case createdAt
        case updatedAt
        case sortOrder
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        completed = try container.decode(Bool.self, forKey: .completed)
        reminderAt = try container.decodeIfPresent(Date.self, forKey: .reminderAt)
        reminderFiredAt = try container.decodeIfPresent(Date.self, forKey: .reminderFiredAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        sortOrder = try container.decode(Double.self, forKey: .sortOrder)

        let storedTags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        let legacyDueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        tags = Self.normalizedTags(storedTags + [legacyDueDate].compactMap { $0 })
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(tags, forKey: .tags)
        try container.encode(completed, forKey: .completed)
        try container.encodeIfPresent(reminderAt, forKey: .reminderAt)
        try container.encodeIfPresent(reminderFiredAt, forKey: .reminderFiredAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(sortOrder, forKey: .sortOrder)
    }
}

struct AppConfig {
    let convexUrl: String?
    let clerkPublishableKey: String?

    var isCloudConfigured: Bool {
        convexUrl?.isEmpty == false && clerkPublishableKey?.isEmpty == false
    }

    static func load() -> AppConfig {
        let env = ProcessInfo.processInfo.environment
        return AppConfig(
            convexUrl: env["TODOBAR_CONVEX_URL"],
            clerkPublishableKey: env["TODOBAR_CLERK_PUBLISHABLE_KEY"]
        )
    }
}
