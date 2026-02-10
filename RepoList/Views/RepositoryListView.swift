import SwiftUI

struct RepositoryListView: View {
    @State private var viewModel = RepositoryListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                //
                if viewModel.isLoading && viewModel.repositories.isEmpty {
                    // Show loading view when it's loading and there is no repo yet.
                    loadingView
                } else if let error = viewModel.errorMessage,
                          viewModel.repositories.isEmpty {
                    // When loading is finished, show error message if there is any.
                    ErrorRetryView(message: error) {
                        Task { await viewModel.loadRepositories() }
                    }
                } else {
                    // Happy path, show the repo list.
                    repositoryList
                }
            }
            .navigationTitle("Repositories")
        }
        .task {
            // When screen appears and there is no repo,
            // trigger the api to fetch repos.
            if viewModel.repositories.isEmpty {
                await viewModel.loadRepositories()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading repositories...")
                .foregroundStyle(.secondary)
        }
    }

    private var repositoryList: some View {
        List {
            ForEach(viewModel.repositories) { repo in
                RepositoryRowView(
                    repository: repo,
                    starCountState: viewModel.starCounts[repo.id]
                )
                .task {
                    // when the row appears on screen, fetches the star count for the repo
                    // this is lazy loading - only make api calls for rows that users actually scrolls to.
                    await viewModel.loadStarCount(for: repo)
                }
                .task {
                    // Check whether the row is near the end of the list
                    // if so, load next page of repos.
                    await viewModel.loadMoreIfNeeded(currentItem: repo)
                }
            }

            // Show loading more indicator at the end of the list
            // if it's loading next page of repos.
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView("Loading more...")
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            // Show error message if there is any when loading more pages.
            if let error = viewModel.errorMessage,
               !viewModel.repositories.isEmpty {
                HStack {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            // Adds a pull-to-refresh feature to the list
            // It will reload the repos from the start.
            await viewModel.loadRepositories()
        }
    }
}

#Preview {
    RepositoryListView()
}
