import SwiftUI

struct QueueView: View {
    @Bindable var vm: QueueViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.isEmpty {
                    ProgressView()
                } else if vm.isEmpty {
                    emptyState
                } else {
                    List {
                        if !vm.radarrQueue.isEmpty {
                            Section("Movies (Radarr)") {
                                ForEach(vm.radarrQueue) { item in
                                    RadarrQueueRow(item: item)
                                }
                            }
                        }

                        if !vm.sonarrQueue.isEmpty {
                            Section("TV Shows (Sonarr)") {
                                ForEach(vm.sonarrQueue) { item in
                                    SonarrQueueRow(item: item)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .refreshable { await vm.refresh() }
            .task { await vm.refresh() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Queue is empty")
                .font(.headline)
            Text("Add something from Discover to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct RadarrQueueRow: View {
    let item: RadarrQueueItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: item.status)
            }
            ProgressView(value: item.progress)
                .tint(.cyan)
            HStack {
                Text(item.progressText)
                Spacer()
                if let timeleft = item.timeleft {
                    Text(timeleft).foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct SonarrQueueRow: View {
    let item: SonarrQueueItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.series?.title ?? item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                StatusBadge(status: item.status)
            }
            ProgressView(value: item.progress)
                .tint(.purple)
            HStack {
                Text(item.progressText)
                Spacer()
                if let timeleft = item.timeleft {
                    Text(timeleft).foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct StatusBadge: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "downloading": .cyan
        case "queued": .orange
        case "paused": .yellow
        case "completed": .green
        case "warning", "failed": .red
        default: .secondary
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}
