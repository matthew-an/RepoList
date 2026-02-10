## Architecture

**MVVM (Model-View-ViewModel)** with a dedicated service layer:

- RepoListApp.swift              # App entry point
- ContentView.swift               # Root view

### Models
- Repository.swift            # Data models (Repository, Owner, RepositoryDetail)

### Services
- GitHubService.swift         # Network layer (actor-based)

### ViewModels
- RepositoryListViewModel.swift  # UI state management

### Views
- RepositoryListView.swift    # Main list with pagination
- RepositoryRowView.swift     # Individual row (avatar, name, stars)
- ErrorRetryView.swift        # Error state with retry action


## Key points and considerations

- **Stars**: The list endpoint doesn’t include star counts. The app fetches them per repo when a row appears, caches them, and shows a spinner or "N/A" on failure.
- **Pagination**: Uses GitHub’s `Link` header cursor. Next page loads when you reach the bottom; pull-to-refresh starts over.
- **Avatar loading** Use AsyncImage to loading image asynchronously, don't block the UI thread.
- **Concurrency** API calls are made in URLSession's managed background thread by leveragng the swift's async/await feature.
- **Errors**: Initial load failure shows a full-screen error and retry. Pagination failure shows an inline message. Rate limits (403) show a clear message; network and star failures don’t break the UI.
- **Loading**: Spinner for initial load, “Loading more…” at bottom for pagination, per-row spinners for stars and avatars, plus pull-to-refresh.

