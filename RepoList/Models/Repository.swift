import Foundation

struct Repository: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
    let owner: Owner
}

struct Owner: Codable, Sendable {
    let id: Int
    let login: String
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case id, login
        case avatarURL = "avatar_url"
    }
}

struct RepositoryDetail: Codable, Sendable {
    let stargazersCount: Int

    enum CodingKeys: String, CodingKey {
        case stargazersCount = "stargazers_count"
    }
}
