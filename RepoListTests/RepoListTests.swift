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

struct ViewModelTests {

    @Test func starCountStateTracking() async {
        let viewModel = RepositoryListViewModel()

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isLoadingMore == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.starCounts.isEmpty)
    }
}
