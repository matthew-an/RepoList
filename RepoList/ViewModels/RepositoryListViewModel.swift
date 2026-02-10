import Foundation
import Observation

/**
 Make it observable so that whenever its properties changes, SwiftUI will refresh the UI automatically.
 */
@Observable
final class RepositoryListViewModel {
    
    var repositories: [Repository] = []
    var isLoading = false
    var isLoadingMore = false
    
    // Holds the api error message if there is any.
    var errorMessage: String?
    
    // Holds the loading status of the repos
    // the key is the repo's id.
    var starCounts: [Int: StarCountState] = [:]

    // Holds the `nextSince` value from the last call of fetching repos.
    // it's nil in the first place, meaning we are fetching the first page.
    private var nextSince: Int?
    
    private var hasMorePages = true

    /**
     An enum indicating the status of loading star count.
     */
    enum StarCountState {
        case loading
        case loaded(Int)
        case failed
    }

    func loadRepositories() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let page = try await GitHubService.fetchRepositories()
            repositories = page.repositories
            nextSince = page.nextSince
            hasMorePages = page.nextSince != nil
            starCounts = [:]
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: Repository) async {
        // Check whether the item is the last one in the repo.
        // If so, it means users scrolls to the end of the list,
        // then check whether we have more pages here
        // then check whether it is already in the progress of loading more pages.
        guard let lastItem = repositories.last,
              currentItem.id == lastItem.id,
              hasMorePages,
              !isLoadingMore
        else { return }

        isLoadingMore = true

        do {
            let page = try await GitHubService.fetchRepositories(since: nextSince)
            
            // Append the result to the existing list.
            repositories.append(contentsOf: page.repositories)
            nextSince = page.nextSince
            hasMorePages = page.nextSince != nil
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }

        isLoadingMore = false
    }

    func loadStarCount(for repo: Repository) async {
        // If it tried to load the star count for the repo
        // just return, don't need to load it again.
        guard starCounts[repo.id] == nil else { return }
        
        // Mark it as start loading.
        starCounts[repo.id] = .loading

        do {
            let count = try await GitHubService.fetchStarCount(
                owner: repo.owner.login,
                repo: repo.name
            )
            starCounts[repo.id] = .loaded(count)
        } catch {
            starCounts[repo.id] = .failed
        }
    }
}
