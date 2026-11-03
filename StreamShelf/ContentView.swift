import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var history: HistoryStore
    @StateObject private var prefs = Preferences.shared
    @State private var tab = 0
    @State private var address = ""
    @State private var activeURL: URL?
    @State private var pageURLForHistory: String?
    @State private var pendingSeekSeconds: Double?
    @State private var metadata = PageMetadata()
    @State private var showPlayers = false
    @State private var launched = false

    var body: some View {
        TabView(selection: $tab) {
            watchTab.tabItem { Label("Watch", systemImage: "play.rectangle") }.tag(0)
            historyTab.tabItem { Label("History", systemImage: "clock") }.tag(1)
            settingsTab.tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
        }
        .onAppear {
            guard !launched else { return }
            launched = true
            if prefs.autoResume, let last = history.lastRecord,
               let url = URL(string: last.playerURL ?? last.pageURL) {
                address = last.pageURL
                pageURLForHistory = last.pageURL
                pendingSeekSeconds = last.positionSeconds > 0 ? last.positionSeconds : nil
                activeURL = url
            }
        }
    }

    private var watchTab: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack {
                    TextField("Paste film / episode URL", text: $address)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    Button { if let s = UIPasteboard.general.string { address = s } } label: {
                        Image(systemName: "doc.on.clipboard")
                    }.buttonStyle(.bordered)
                }
                HStack {
                    Button(action: openURL) {
                        Label("Open", systemImage: "arrow.up.right")
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(parseURL(address) == nil)
                    if !metadata.frames.isEmpty {
                        Button {
                            showPlayers = true
                        } label: {
                            Label("Players \(metadata.frames.count)", systemImage: "rectangle.stack")
                        }.buttonStyle(.bordered)
                    }
                    Spacer()
                    if let position = metadata.position, position > 0 {
                        Text(WatchRecord.time(position)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let activeURL {
                    WebViewContainer(url: activeURL, blockAds: prefs.adBlock,
                                    seekSeconds: pendingSeekSeconds,
                                    onMetadata: receiveMetadata, onNavigation: receiveNavigation)
                        .id(activeURL.absoluteString)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ContentUnavailableView("Paste a link", systemImage: "play.rectangle",
                                          description: Text("The app opens the exact page you provide; it does not search."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(10)
            .navigationTitle("StreamShelf")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPlayers) {
                NavigationStack {
                    List(metadata.frames) { frame in
                        Button {
                            guard let u = URL(string: frame.url) else { return }
                            let page = metadata.url.isEmpty ? address : metadata.url
                            history.progress(pageURL: page, playerURL: frame.url, title: metadata.title,
                                            season: metadata.season, episode: metadata.episode,
                                            position: metadata.position ?? 0, duration: metadata.duration)
                            activeURL = u
                            showPlayers = false
                        } label: {
                            VStack(alignment: .leading) {
                                Text(frame.title).font(.headline)
                                Text(frame.url).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                    .navigationTitle("Choose player")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showPlayers = false } } }
                }
            }
        }
    }

    private var historyTab: some View {
        NavigationStack {
            List {
                if history.records.isEmpty {
                    ContentUnavailableView("No history yet", systemImage: "clock")
                }
                ForEach(history.records) { item in
                    Button {
                        address = item.pageURL
                        pageURLForHistory = item.pageURL
                        pendingSeekSeconds = item.positionSeconds > 0 ? item.positionSeconds : nil
                        activeURL = URL(string: item.playerURL ?? item.pageURL)
                        tab = 0
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title.isEmpty ? item.pageURL : item.title).font(.headline).lineLimit(2)
                                Spacer()
                                if item.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                            }
                            if let s = item.season, let e = item.episode { Text("Season \(s), Episode \(e)").font(.subheadline) }
                            Text("Position: \(item.progressText) · \(item.lastWatched.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(item.pageURL).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .swipeActions {
                        Button { history.toggleFavorite(item) } label: { Label("Favorite", systemImage: "star") }.tint(.yellow)
                        Button(role: .destructive) { history.delete(item) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("Viewing history")
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("Audio preference", selection: $prefs.audio) {
                        ForEach(["Original", "Russian", "English", "German", "Other"], id: \.self) { Text($0) }
                    }
                    Picker("Video quality", selection: $prefs.quality) {
                        ForEach(["Auto", "480p", "720p", "1080p", "4K"], id: \.self) { Text($0) }
                    }
                    Toggle("Reopen last watched page on launch", isOn: $prefs.autoResume)
                }
                Section("Ads") {
                    Toggle("Block common ad domains / popups", isOn: $prefs.adBlock)
                    Text("Best effort only. Turn this off if a player fails to load.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("History") {
                    Button("Clear viewing history", role: .destructive) { history.clear() }
                }
                Section("Notes") {
                    Text("Audio and quality are saved preferences. Player-specific controls still need to be changed inside the player.")
                    Text("Playback time can only be read from video elements accessible to the page. Cross-origin iframe players may hide it from iOS.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func parseURL(_ raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let normalized = value.contains("://") ? value : "https://" + value
        guard let url = URL(string: normalized), url.host != nil,
              ["http","https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    private func openURL() {
        guard let url = parseURL(address) else { return }
        activeURL = url
        pageURLForHistory = url.absoluteString
        pendingSeekSeconds = nil
        metadata = PageMetadata(url: url.absoluteString)
        history.upsert(WatchRecord(pageURL: url.absoluteString, title: url.host ?? url.absoluteString))
    }

    private func receiveMetadata(_ m: PageMetadata) {
        metadata = m
        let page = pageURLForHistory ?? activeURL?.absoluteString ?? m.url
        history.progress(pageURL: page, playerURL: activeURL?.absoluteString == page ? nil : activeURL?.absoluteString,
                         title: MetadataParser.cleanTitle(m.title),
                         season: m.season, episode: m.episode,
                         position: m.position ?? 0, duration: m.duration)
    }

    private func receiveNavigation(_ url: URL) {
        // Record navigated player URL for the current page. The page URL remains the history key.
        guard let page = pageURLForHistory ?? activeURL?.absoluteString else { return }
        if page != url.absoluteString {
            history.progress(pageURL: page, playerURL: url.absoluteString,
                            title: metadata.title, season: metadata.season, episode: metadata.episode,
                            position: metadata.position ?? 0, duration: metadata.duration)
        }
    }
}
