import SwiftUI

struct RepositoryRowView: View {
    let repository: Repository
    let starCountState: RepositoryListViewModel.StarCountState?

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(repository.owner.login)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            starCountView
        }
        .padding(.vertical, 4)
    }

    private var avatarView: some View {
        // Load the image asynchronously without blocking the main thread.
        AsyncImage(url: URL(string: repository.owner.avatarURL)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 44, height: 44)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            case .failure:
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.secondary)
            @unknown default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var starCountView: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .font(.caption)

            switch starCountState {
            case .none, .loading:
                ProgressView()
                    .controlSize(.small)
            case .loaded(let count):
                Text(Self.formatCount(count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .failed:
                // Show N/A; the view model will retry on next appearance
                // since it allows retries for the .failed state.
                Text("N/A")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func formatCount(_ count: Int) -> String {
        if count >= 999_950 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
