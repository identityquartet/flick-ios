import SwiftUI
import UIKit

struct SettingsView: View {
    // Radarr
    @AppStorage("radarrURL") private var radarrURL = ""
    @AppStorage("radarrAPIKey") private var radarrAPIKey = ""
    @AppStorage("radarrProfileId") private var radarrProfileId = 0
    @AppStorage("radarrRootFolder") private var radarrRootFolder = ""

    // Sonarr
    @AppStorage("sonarrURL") private var sonarrURL = ""
    @AppStorage("sonarrAPIKey") private var sonarrAPIKey = ""
    @AppStorage("sonarrProfileId") private var sonarrProfileId = 0
    @AppStorage("sonarrRootFolder") private var sonarrRootFolder = ""

    // APIs
    @AppStorage("tmdbToken") private var tmdbToken = ""
    @AppStorage("streamingAPIKey") private var streamingAPIKey = ""

    @State private var radarrProfiles: [QualityProfile] = []
    @State private var radarrFolders: [RootFolder] = []
    @State private var sonarrProfiles: [QualityProfile] = []
    @State private var sonarrFolders: [RootFolder] = []
    @State private var fetchError: String?
    @State private var isFetching = false
    @State private var logEntryCount = 0
    @State private var showShareSheet = false
    @State private var logText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Version", value: "1.0")
                } header: {
                    Text("Flick")
                }

                // MARK: Radarr
                Section("Radarr (Movies)") {
                    TextField("URL (e.g. http://192.168.1.10:7878)", text: $radarrURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("API Key", text: $radarrAPIKey)

                    if !radarrProfiles.isEmpty {
                        Picker("Quality Profile", selection: $radarrProfileId) {
                            Text("Select…").tag(0)
                            ForEach(radarrProfiles) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                        Picker("Root Folder", selection: $radarrRootFolder) {
                            Text("Select…").tag("")
                            ForEach(radarrFolders) { f in
                                Text(f.path).tag(f.path)
                            }
                        }
                    }

                    Button(isFetching ? "Fetching…" : "Connect to Radarr") {
                        Task { await fetchRadarr() }
                    }
                    .disabled(radarrURL.isEmpty || radarrAPIKey.isEmpty || isFetching)
                }

                // MARK: Sonarr
                Section("Sonarr (TV Shows)") {
                    TextField("URL (e.g. http://192.168.1.10:8989)", text: $sonarrURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("API Key", text: $sonarrAPIKey)

                    if !sonarrProfiles.isEmpty {
                        Picker("Quality Profile", selection: $sonarrProfileId) {
                            Text("Select…").tag(0)
                            ForEach(sonarrProfiles) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                        Picker("Root Folder", selection: $sonarrRootFolder) {
                            Text("Select…").tag("")
                            ForEach(sonarrFolders) { f in
                                Text(f.path).tag(f.path)
                            }
                        }
                    }

                    Button(isFetching ? "Fetching…" : "Connect to Sonarr") {
                        Task { await fetchSonarr() }
                    }
                    .disabled(sonarrURL.isEmpty || sonarrAPIKey.isEmpty || isFetching)
                }

                // MARK: API Keys
                Section {
                    SecureField("TMDB Read Access Token", text: $tmdbToken)
                    SecureField("Streaming Availability Key (optional)", text: $streamingAPIKey)
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("TMDB token: get from themoviedb.org → Settings → API. Streaming API: optional, from movieofthenight.com for richer platform data.")
                        .font(.caption)
                }

                if let err = fetchError {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }

                // MARK: Logs
                Section("Logs") {
                    LabeledContent("Entries", value: "\(logEntryCount)")
                    Button("Share Logs") {
                        logText = AppLogger.shared.exportText()
                        showShareSheet = true
                    }
                    .disabled(logEntryCount == 0)
                    Button("Clear Logs", role: .destructive) {
                        AppLogger.shared.clearLogs()
                        logEntryCount = 0
                    }
                    .disabled(logEntryCount == 0)
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            await fetchAll()
            logEntryCount = AppLogger.shared.entryCount
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [logText])
        }
    }

    private func fetchAll() async {
        if !radarrURL.isEmpty && !radarrAPIKey.isEmpty { await fetchRadarr() }
        if !sonarrURL.isEmpty && !sonarrAPIKey.isEmpty { await fetchSonarr() }
    }

    private func fetchRadarr() async {
        isFetching = true
        fetchError = nil
        do {
            async let profiles = RadarrService.qualityProfiles()
            async let folders = RadarrService.rootFolders()
            radarrProfiles = try await profiles
            radarrFolders = try await folders
        } catch {
            fetchError = "Radarr: \(error.localizedDescription)"
        }
        isFetching = false
    }

    private func fetchSonarr() async {
        isFetching = true
        fetchError = nil
        do {
            async let profiles = SonarrService.qualityProfiles()
            async let folders = SonarrService.rootFolders()
            sonarrProfiles = try await profiles
            sonarrFolders = try await folders
        } catch {
            fetchError = "Sonarr: \(error.localizedDescription)"
        }
        isFetching = false
    }
}
