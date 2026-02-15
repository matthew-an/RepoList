import Foundation

/**
 An enumeration indicating the possible error during the network/api layer.
 */
enum NetworkError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(String)
    case networkError(String)
    case rateLimited(retryAfter: Int?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code):
            return "Server returned an error (HTTP \(code))."
        case .decodingError(let detail):
            return "Failed to parse server response: \(detail)"
        case .networkError(let detail):
            return detail
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "API rate limit exceeded. Try again in \(seconds) seconds."
            }
            return "API rate limit exceeded. Please try again later."
        }
    }
}

struct RepositoryPage: Sendable {
    let repositories: [Repository]
    
    /**
     The full URL for the next page, extracted from the `Link` header.
     `nil` means there are no more pages.
     */
    let nextPageURL: URL?
}

/**
 A protocol that abstracts GitHub API operations.
 This enables dependency injection, making it easy to substitute a mock in tests.
 */
protocol GitHubServiceProtocol: Sendable {
    func fetchRepositories(nextPageURL: URL?) async throws -> RepositoryPage
    func fetchStarCount(owner: String, repo: String) async throws -> Int
}

struct GitHubService: GitHubServiceProtocol {
    
    private let baseURL = "https://api.github.com"
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    /**
     Fetches a page of repositories.
     Pass `nil` for the first page; subsequent pages use the URL from `RepositoryPage.nextPageURL`.
     */
    func fetchRepositories(nextPageURL: URL? = nil) async throws -> RepositoryPage {
        let url: URL
        if let nextPageURL {
            url = nextPageURL
        } else {
            guard let firstPageURL = URL(string: "\(baseURL)/repositories") else {
                throw NetworkError.invalidURL
            }
            url = firstPageURL
        }

        let (data, response) = try await performRequest(url: url)

        do {
            let repos = try decoder.decode([Repository].self, from: data)
            return RepositoryPage(repositories: repos, nextPageURL: Self.parseNextPageURL(from: response))
        } catch let error as DecodingError {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    /**
     The star count for the repo is within the response of api call `/repos/{owner}/{repo}`
     When we need to display the star count for a repo, we make a call this method
     to fetch the data.
     */
    func fetchStarCount(owner: String, repo: String) async throws -> Int {
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)"

        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await performRequest(url: url)

        do {
            let detail = try decoder.decode(RepositoryDetail.self, from: data)
            return detail.stargazersCount
        } catch let error as DecodingError {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    /**
     A general method to process the api response and handle the errors accordingly.
     */
    private func performRequest(url: URL) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw NetworkError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Handle the error when the api calls reaches
        // its rate limit, and also get the seconds it needs to wait.
        if httpResponse.statusCode == 403,
           httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap { Int($0) }
                .map { $0 - Int(Date().timeIntervalSince1970) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    /**
     Extracts the "next" page URL from the response's `Link` header.
     */
    private static func parseNextPageURL(from response: HTTPURLResponse) -> URL? {
        guard let linkHeader = response.value(forHTTPHeaderField: "Link") else {
            return nil
        }

        for link in linkHeader.components(separatedBy: ",") {
            let parts = link.components(separatedBy: ";")
            guard parts.count == 2,
                  parts[1].trimmingCharacters(in: .whitespaces).contains("rel=\"next\"")
            else { continue }

            let urlString = parts[0]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))

            return URL(string: urlString)
        }

        return nil
    }
}
