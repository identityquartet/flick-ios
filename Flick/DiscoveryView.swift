import SwiftUI

struct DiscoveryView: View {
    @Bindable var vm: DiscoveryViewModel
    @State private var selectedItem: MediaItem?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Platform tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DiscoveryTab.allCases) { tab in
                            TabChip(title: tab.rawValue, selected: vm.selectedTab == tab) {
                                vm.selectedTab = tab
                                vm.switchTo(tab: tab, kind: vm.selectedKind)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // Movie / TV toggle
                Picker("Type", selection: $vm.selectedKind) {
                    Text("Movies").tag(MediaKind.movie)
                    Text("TV Shows").tag(MediaKind.tv)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .onChange(of: vm.selectedKind) { _, kind in
                    vm.switchTo(tab: vm.selectedTab, kind: kind)
                }

                Divider().opacity(0.3)

                // Content grid
                if vm.isLoading && (vm.content[vm.selectedKind] ?? []).isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = vm.errorMessage, (vm.content[vm.selectedKind] ?? []).isEmpty {
                    Spacer()
                    ErrorView(message: error) { vm.refresh() }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(vm.content[vm.selectedKind] ?? []) { item in
                                MediaCardView(item: item, status: vm.status(for: item))
                                    .onTapGesture { selectedItem = item }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { vm.refresh() }
                }
            }
            .navigationTitle("Flick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vm.isLoading { ProgressView().scaleEffect(0.7) }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            MediaDetailView(item: item, vm: vm)
        }
    }
}

struct TabChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.cyan : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
    }
}
