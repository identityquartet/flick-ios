import SwiftUI

struct MediaDetailView: View {
    let item: MediaItem
    @Bindable var vm: DiscoveryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var providers: [TMDBWatchProviders.Provider] = []
    @State private var seasons: [TMDBSeason] = []
    @State private var selectedSeasons: Set<Int> = []
    @State private var tvdbId: Int?
    @State private var isAdding = false
    @State private var addError: String?
    @State private var addSuccess = false
    @State private var isLoadingMeta = true

    private var status: DiscoveryViewModel.MediaStatus { vm.status(for: item) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Backdrop
                    AsyncImage(url: item.backdropURL ?? item.posterURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Rectangle().fill(Color.white.opacity(0.08))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .overlay(
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 80), alignment: .bottom
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        // Title & meta
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayTitle)
                                .font(.title2.bold())

                            HStack(spacing: 10) {
                                if let year = item.year {
                                    Label("\(year)", systemImage: "calendar")
                                }
                                Label(item.rating, systemImage: "star.fill")
                                    .foregroundStyle(.yellow)
                                Label(item.kind == .movie ? "Movie" : "Series", systemImage: item.kind == .movie ? "film" : "tv")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        // Overview
                        if let overview = item.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                        }

                        // Streaming platforms
                        if !providers.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Streaming in Ireland")
                                    .font(.subheadline.weight(.semibold))
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(providers) { p in
                                            ProviderBadge(provider: p)
                                        }
                                    }
                                }
                            }
                        }

                        // Season picker for TV shows
                        if item.kind == .tv && !seasons.isEmpty && status == .notInLibrary {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Seasons to monitor")
                                    .font(.subheadline.weight(.semibold))

                                Button("Select all") {
                                    selectedSeasons = Set(seasons.map { $0.seasonNumber })
                                }
                                .font(.caption)
                                .foregroundStyle(.cyan)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                                    ForEach(seasons) { season in
                                        SeasonToggle(
                                            season: season,
                                            selected: selectedSeasons.contains(season.seasonNumber)
                                        ) {
                                            if selectedSeasons.contains(season.seasonNumber) {
                                                selectedSeasons.remove(season.seasonNumber)
                                            } else {
                                                selectedSeasons.insert(season.seasonNumber)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Error
                        if let err = addError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        // Action button
                        actionButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadMeta() }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .inLibrary:
            Label("In Library", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

        case .notConfigured:
            Text("Configure \(item.kind == .movie ? "Radarr" : "Sonarr") in Settings")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

        case .notInLibrary:
            if addSuccess {
                Label("Added!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    Task { await add() }
                } label: {
                    HStack {
                        if isAdding {
                            ProgressView().tint(.black)
                        }
                        Text(isAdding ? "Adding…" : "Add to \(item.kind == .movie ? "Radarr" : "Sonarr")")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.black)
                }
                .disabled(isAdding || (item.kind == .tv && selectedSeasons.isEmpty && !seasons.isEmpty))
                .buttonStyle(.plain)
            }
        }
    }

    private func loadMeta() async {
        defer { isLoadingMeta = false }
        guard AppSettings.isTMDBConfigured else { return }
        async let providerTask = TMDBService.watchProviders(id: item.id, kind: item.kind)
        async let seasonTask: [TMDBSeason]? = item.kind == .tv ? TMDBService.seasons(tvId: item.id) : nil
        async let externalTask: TMDBExternalIDs? = item.kind == .tv ? TMDBService.externalIDs(tvId: item.id) : nil

        if let wp = try? await providerTask {
            providers = wp.results["IE"]?.flatrate ?? []
        }
        if let s = try? await seasonTask { seasons = s }
        if let ext = try? await externalTask { tvdbId = ext.tvdbId }

        // Default: select all seasons
        selectedSeasons = Set(seasons.map { $0.seasonNumber })
    }

    private func add() async {
        isAdding = true
        addError = nil
        do {
            if item.kind == .movie {
                try await vm.addMovie(item)
            } else {
                guard let tvdbId else {
                    addError = "Could not find TVDB ID for this series."
                    isAdding = false
                    return
                }
                try await vm.addSeries(item, tvdbId: tvdbId, seasons: Array(selectedSeasons))
            }
            addSuccess = true
        } catch {
            addError = error.localizedDescription
        }
        isAdding = false
    }
}

struct ProviderBadge: View {
    let provider: TMDBWatchProviders.Provider

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: provider.logoURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFit()
                } else {
                    Rectangle().fill(Color.white.opacity(0.1))
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(provider.providerName)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1), in: Capsule())
    }
}

struct SeasonToggle: View {
    let season: TMDBSeason
    let selected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 2) {
                Text("S\(season.seasonNumber)")
                    .font(.subheadline.weight(.semibold))
                if let count = season.episodeCount {
                    Text("\(count) eps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.cyan : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(selected ? .black : .white)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: selected)
    }
}
