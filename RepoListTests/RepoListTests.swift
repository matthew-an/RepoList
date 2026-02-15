import Testing
import Foundation
@testable import RepoList

struct RepositoryModelTests {

    @Test func decodesRepositoryFromJSON() throws {
        let json = """
        {
            "id": 1,
            "name": "grit",
            "full_name": "mojombo/grit",
            "owner": {
                "id": 1,
                "login": "mojombo",
                "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4"
            }
        }
        """.data(using: .utf8)!

        let repo = try JSONDecoder().decode(Repository.self, from: json)

        #expect(repo.id == 1)
        #expect(repo.name == "grit")
        #expect(repo.owner.login == "mojombo")
        #expect(repo.owner.avatarURL == "https://avatars.githubusercontent.com/u/1?v=4")
    }

    @Test func decodesRepositoryDetailFromJSON() throws {
        let json = """
        {
            "stargazers_count": 42
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(RepositoryDetail.self, from: json)

        #expect(detail.stargazersCount == 42)
    }

    @Test func repositoryConformsToIdentifiable() {
        let owner = Owner(id: 1, login: "test", avatarURL: "https://example.com/avatar.png")
        let repo = Repository(id: 99, name: "test-repo", owner: owner)

        #expect(repo.id == 99)
    }
}

struct RepositoryRowViewTests {

    @Test func formatCountShowsRawNumberUnder1000() {
        #expect(RepositoryRowView.formatCount(0) == "0")
        #expect(RepositoryRowView.formatCount(999) == "999")
    }

    @Test func formatCountShowsKForThousands() {
        #expect(RepositoryRowView.formatCount(1_000) == "1.0K")
        #expect(RepositoryRowView.formatCount(1_500) == "1.5K")
        #expect(RepositoryRowView.formatCount(999_999) == "1000.0K")
    }

    @Test func formatCountShowsMForMillions() {
        #expect(RepositoryRowView.formatCount(1_000_000) == "1.0M")
        #expect(RepositoryRowView.formatCount(2_500_000) == "2.5M")
    }
}

// MARK: - Mock Service

struct MockGitHubService: GitHubServiceProtocol {
    var repositoryPages: [RepositoryPage] = []
    var starCounts: [String: Int] = [:]
    var shouldThrow: Error?

    /// Tracks how many times fetchRepositories has been called.
    private let fetchRepositoriesCallCount = MutableBox(0)
    
    func fetchRepositories(nextPageURL: URL?) async throws -> RepositoryPage {
        if let error = shouldThrow { throw error }
        fetchRepositoriesCallCount.value += 1
        // Return the first page for initial load, second for pagination, etc.
        let index = fetchRepositoriesCallCount.value - 1
        guard index < repositoryPages.count else {
            return RepositoryPage(repositories: [], nextPageURL: nil)
        }
        return repositoryPages[index]
    }

    func fetchStarCount(owner: String, repo: String) async throws -> Int {
        if let error = shouldThrow { throw error }
        let key = "\(owner)/\(repo)"
        guard let count = starCounts[key] else {
            throw NetworkError.networkError("Not found")
        }
        return count
    }
}

/// A simple mutable reference box used to track call counts inside a Sendable struct.
final class MutableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// MARK: - ViewModel Tests

struct ViewModelTests {

    private static let sampleOwner = Owner(id: 1, login: "octocat", avatarURL: "https://example.com/avatar.png")

    private static func makeRepos(_ count: Int, startingId: Int = 1) -> [Repository] {
        (0..<count).map { i in
            Repository(id: startingId + i, name: "repo-\(startingId + i)", owner: sampleOwner)
        }
    }

    @Test func initialStateIsEmpty() async {
        let viewModel = await RepositoryListViewModel(service: MockGitHubService())

        await #expect(viewModel.repositories.isEmpty)
        await #expect(viewModel.isLoading == false)
        await #expect(viewModel.isLoadingMore == false)
        await #expect(viewModel.errorMessage == nil)
        await #expect(viewModel.starCounts.isEmpty)
    }

    @Test func loadRepositoriesPopulatesList() async {
        let repos = Self.makeRepos(3)
        let mock = MockGitHubService(
            repositoryPages: [RepositoryPage(repositories: repos, nextPageURL: URL(string: "https://api.github.com/repositories?since=100"))]
        )
        let viewModel = await RepositoryListViewModel(service: mock)

        await viewModel.loadRepositories()

        await #expect(viewModel.repositories.count == 3)
        await #expect(viewModel.repositories.first?.name == "repo-1")
        await #expect(viewModel.isLoading == false)
        await #expect(viewModel.errorMessage == nil)
    }

    @Test func loadRepositoriesSetsErrorOnFailure() async {
        let mock = MockGitHubService(
            shouldThrow: NetworkError.networkError("Connection failed")
        )
        let viewModel = await RepositoryListViewModel(service: mock)

        await viewModel.loadRepositories()

        await #expect(viewModel.repositories.isEmpty)
        await #expect(viewModel.errorMessage == "Connection failed")
        await #expect(viewModel.isLoading == false)
    }

    @Test func loadMoreAppendsNextPage() async {
        let firstPage = Self.makeRepos(2, startingId: 1)
        let secondPage = Self.makeRepos(2, startingId: 3)
        let mock = MockGitHubService(
            repositoryPages: [
                RepositoryPage(repositories: firstPage, nextPageURL: URL(string: "https://api.github.com/repositories?since=2")),
                RepositoryPage(repositories: secondPage, nextPageURL: nil)
            ]
        )
        let viewModel = await RepositoryListViewModel(service: mock)

        // Load first page.
        await viewModel.loadRepositories()
        await #expect(viewModel.repositories.count == 2)

        // Trigger pagination by passing the last item.
        let lastItem = await viewModel.repositories.last!
        await viewModel.loadMoreIfNeeded(currentItem: lastItem)

        await #expect(viewModel.repositories.count == 4)
        await #expect(viewModel.repositories.last?.name == "repo-4")
        await #expect(viewModel.isLoadingMore == false)
    }

    @Test func loadStarCountSetsLoadedState() async {
        let repos = Self.makeRepos(1)
        let mock = MockGitHubService(
            repositoryPages: [RepositoryPage(repositories: repos, nextPageURL: nil)],
            starCounts: ["octocat/repo-1": 42]
        )
        let viewModel = await RepositoryListViewModel(service: mock)

        await viewModel.loadRepositories()
        await viewModel.loadStarCount(for: repos[0])

        let state = await viewModel.starCounts[repos[0].id]
        if case .loaded(let count) = state {
            #expect(count == 42)
        } else {
            Issue.record("Expected .loaded(42), got \(String(describing: state))")
        }
    }

    @Test func loadStarCountSetsFailedOnError() async {
        let repos = Self.makeRepos(1)
        // No star counts in mock → will throw.
        let mock = MockGitHubService(
            repositoryPages: [RepositoryPage(repositories: repos, nextPageURL: nil)]
        )
        let viewModel = await RepositoryListViewModel(service: mock)

        await viewModel.loadRepositories()
        await viewModel.loadStarCount(for: repos[0])

        let state = await viewModel.starCounts[repos[0].id]
        if case .failed = state {
            // Expected
        } else {
            Issue.record("Expected .failed, got \(String(describing: state))")
        }
    }

    @Test func loadStarCountSkipsIfAlreadyLoaded() async {
        let repos = Self.makeRepos(1)
        let mock = MockGitHubService(
            repositoryPages: [RepositoryPage(repositories: repos, nextPageURL: nil)],
            starCounts: ["octocat/repo-1": 42]
        )
        let viewModel = await RepositoryListViewModel(service: mock)

        await viewModel.loadRepositories()
        await viewModel.loadStarCount(for: repos[0])
        await viewModel.loadStarCount(for: repos[0]) // Second call should be a no-op.

        let state = await viewModel.starCounts[repos[0].id]
        if case .loaded(let count) = state {
            #expect(count == 42)
        } else {
            Issue.record("Expected .loaded(42), got \(String(describing: state))")
        }
    }
}
