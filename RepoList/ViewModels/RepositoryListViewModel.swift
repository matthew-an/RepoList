import Foundation
import Observation

/**
 Make it observable so that whenever its properties changes, SwiftUI will refresh the UI automatically.
 */
@Observable
@MainActor
final class RepositoryListViewModel {
    
    var repositories: [Repository] = []
    var isLoading = false
    var isLoadingMore = false
    
    // Holds the api error message if there is any.
    var errorMessage: String?
    
    // Holds the loading status of the repos
    // the key is the repo's id.
    var starCounts: [Int: StarCountState] = [:]

    // The URL for the next page of repositories, extracted from the Link header.
    // nil means either we haven't fetched yet or there are no more pages.
    private var nextPageURL: URL?
    
    private var hasMorePages = true

    /// Number of items from the end of the list at which to trigger the next page fetch.
    private let prefetchThreshold = 5

    private let service: GitHubServiceProtocol

    // Make the initializer nonisolated and avoid calling a @MainActor init from here.
    nonisolated init(service: GitHubServiceProtocol) {
        self.service = service
    }

    convenience init() {
        self.init(service: GitHubService())
    }

    /**
     An enum indicating the status of loading star count.
     */
    enum StarCountState: Equatable {
        case loading
        case loaded(Int)
        case failed
    }

    func loadRepositories() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let page = try await service.fetchRepositories(nextPageURL: nil)
            repositories = page.repositories
            nextPageURL = page.nextPageURL
            hasMorePages = page.nextPageURL != nil
            starCounts = [:]
        } catch is CancellationError {
            // Task was cancelled (e.g. view disappeared); ignore silently.
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    func loadMoreIfNeeded(currentItem: Repository) async {
        // Trigger prefetch when the user is within `prefetchThreshold` items
        // of the end, and we aren't already loading.
        guard hasMorePages,
              !isLoadingMore,
              let index = repositories.firstIndex(where: { $0.id == currentItem.id }),
              index >= repositories.count - prefetchThreshold
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await service.fetchRepositories(nextPageURL: nextPageURL)
            
            // Append the result to the existing list.
            repositories.append(contentsOf: page.repositories)
            nextPageURL = page.nextPageURL
            hasMorePages = page.nextPageURL != nil
        } catch is CancellationError {
            // Task was cancelled; ignore silently.
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    func loadStarCount(for repo: Repository) async {
        // Allow retry when the previous attempt failed.
        // Skip if already loading or successfully loaded.
        if let existing = starCounts[repo.id], existing != .failed {
            return
        }
        
        // Mark it as start loading.
        starCounts[repo.id] = .loading

        do {
            let count = try await service.fetchStarCount(
                owner: repo.owner.login,
                repo: repo.name
            )
            starCounts[repo.id] = .loaded(count)
        } catch is CancellationError {
            // Revert to nil so the next appearance can retry.
            starCounts[repo.id] = nil
        } catch {
            starCounts[repo.id] = .failed
        }
    }
}
