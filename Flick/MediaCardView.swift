import SwiftUI

struct MediaCardView: View {
    let item: MediaItem
    let status: DiscoveryViewModel.MediaStatus

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(Color.white.opacity(0.08))
                        .overlay(Image(systemName: "film").font(.title2).foregroundStyle(.tertiary))
                default:
                    Rectangle().fill(Color.white.opacity(0.05))
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .frame(width: 110, height: 165)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(6)

            // In-library badge
            if status == .inLibrary {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                    .padding(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: 110, height: 165)
    }
}
