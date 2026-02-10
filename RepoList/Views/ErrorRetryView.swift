import SwiftUI

struct ErrorRetryView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retryAction)
                .buttonStyle(.bordered)
        }
    }
}
