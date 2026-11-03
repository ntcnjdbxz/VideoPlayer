import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var history: HistoryStore
    @StateObject private var prefs = Preferences.shared

    @State private var tab = 0
    @State private var address = ""
    @State private var sourcePageURL: URL?
    @State private var selectedPlayerURL: URL?
    @State private var pageURLForHistory: String?
    @State private var pendingSeekSeconds: Double?
    @State private var metadata = PageMetadata()
    @State private var showPlayers = false
    @State private var showPlayer = false
    @State private var launched = false

    var body: some View {
        TabView(selection: $tab) {
            watchTab
                .tabItem { Label("Watch", systemImage: "play.rectangle") }
                .tag(0)

            historyTab
                .tabItem { Label("History", systemImage: "clock") }
                .tag(1)

            settingsTab
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .onAppear {
            guard !launched else { return }
            launched = true
            if prefs.autoResume, let last = history.lastRecord {
                address = last.pageURL
                pageURLForHistory = last.pageURL
                pendingSeekSeconds = last.positionSeconds > 0 ? last.positionSeconds : nil
                if let player = URL(string: last.playerURL ?? last.pageURL) {
                    selectedPlayerURL = player
                    showPlayer = true
                } else if let page = URL(string: last.pageURL) {
                    sourcePageURL = page
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let selectedPlayerURL {
                PlayerScreen(
                    url: selectedPlayerURL,
                    blockAds: prefs.adBlock,
                    seekSeconds: pendingSeekSeconds,
                    onMetadata: receivePlayerMetadata,
                    onNavigation: receivePlayerNavigation,
                    onClose: {
                        showPlayer = false
                        pendingSeekSeconds = nil
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    private var watchTab: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.blue)

                Text("StreamShelf")
                    .font(.largeTitle.weight(.semibold))

                Text("Вставь ссылку на фильм или серию")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField("https://…", text: $address)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Button {
                        if let pasted = UIPasteboard.general.string {
                            address = pasted
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: loadSourcePage) {
                    Label("Найти плееры", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(parseURL(address) == nil)

                if !metadata.frames.isEmpty {
                    Button {
                        showPlayers = true
                    } label: {
                        Label("Выбрать плеер · \(metadata.frames.count)",
                              systemImage: "rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let pageTitle = metadata.title.nilIfEmpty {
                    Text(pageTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }

                Spacer()
                Text("Выбор плеера остаётся за тобой")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 12)
            }
            .padding(22)
            .navigationTitle("Просмотр")
            .navigationBarTitleDisplayMode(.inline)
            // This invisible WKWebView only reads the source page and discovers iframe players.
            // The actual playback is presented separately in PlayerScreen.
            .overlay {
                if let sourcePageURL {
                    WebViewContainer(
                        url: sourcePageURL,
                        blockAds: prefs.adBlock,
                        seekSeconds: nil,
                        onMetadata: receiveSourceMetadata,
                        onNavigation: { _ in }
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .sheet(isPresented: $showPlayers) {
                NavigationStack {
                    List(metadata.frames) { frame in
                        Button {
                            guard let playerURL = URL(string: frame.url) else { return }
                            choosePlayer(playerURL, title: frame.title)
                            showPlayers = false
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(frame.title)
                                    .font(.headline)
                                Text(frame.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .navigationTitle("Выбери плеер")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Закрыть") { showPlayers = false }
                        }
                    }
                }
            }
        }
    }

    private var historyTab: some View {
        NavigationStack {
            List {
                if history.records.isEmpty {
                    ContentUnavailableView("История пуста", systemImage: "clock")
                }

                ForEach(history.records) { item in
                    Button {
                        address = item.pageURL
                        pageURLForHistory = item.pageURL
                        pendingSeekSeconds = item.positionSeconds > 0 ? item.positionSeconds : nil
                        if let url = URL(string: item.playerURL ?? item.pageURL) {
                            selectedPlayerURL = url
                            showPlayer = true
                        }
                        tab = 0
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title.isEmpty ? item.pageURL : item.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                Spacer()
                                if item.isFavorite {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                }
                            }
                            if let season = item.season, let episode = item.episode {
                                Text("Сезон \(season), серия \(episode)")
                                    .font(.subheadline)
                            }
                            Text("Просмотрено: \(item.progressText) · \(item.lastWatched.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.pageURL)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .swipeActions {
                        Button { history.toggleFavorite(item) } label: {
                            Label("Избранное", systemImage: "star")
                        }.tint(.yellow)

                        Button(role: .destructive) {
                            history.delete(item)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("История")
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            Form {
                Section("Настройки") {
                    Picker("Аудиодорожка", selection: $prefs.audio) {
                        ForEach(["Original", "Russian", "English", "German", "Other"], id: \.self) {
                            Text($0)
                        }
                    }
                    Picker("Качество видео", selection: $prefs.quality) {
                        ForEach(["Auto", "480p", "720p", "1080p", "4K"], id: \.self) {
                            Text($0)
                        }
                    }
                    Toggle("Открывать последний просмотр", isOn: $prefs.autoResume)
                }

                Section("Реклама") {
                    Toggle("Блокировать известные рекламные запросы", isOn: $prefs.adBlock)
                    Text("Блокировка пока экспериментальная. Реклама внутри сторонних плееров может потребовать отдельной настройки.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("История") {
                    Button("Очистить историю", role: .destructive) {
                        history.clear()
                    }
                }

                Section("О приложении") {
                    Text("Страница сайта используется только для поиска плееров. Сам выбранный плеер открывается отдельно.")
                    Text("Время просмотра может быть недоступно, если сторонний плеер скрывает видео внутри cross-origin iframe.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
        }
    }

    private func parseURL(_ raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let normalized = value.contains("://") ? value : "https://" + value
        guard let url = URL(string: normalized), url.host != nil,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    private func loadSourcePage() {
        guard let url = parseURL(address) else { return }
        sourcePageURL = nil
        metadata = PageMetadata(url: url.absoluteString)
        pageURLForHistory = url.absoluteString
        selectedPlayerURL = nil
        pendingSeekSeconds = nil
        history.upsert(WatchRecord(pageURL: url.absoluteString, title: url.host ?? url.absoluteString))
        // Recreate the hidden web view to force a fresh page load.
        DispatchQueue.main.async {
            sourcePageURL = url
        }
    }

    private func choosePlayer(_ playerURL: URL, title: String) {
        selectedPlayerURL = playerURL
        let page = pageURLForHistory ?? sourcePageURL?.absoluteString ?? address
        history.progress(
            pageURL: page,
            playerURL: playerURL.absoluteString,
            title: MetadataParser.cleanTitle(metadata.title.isEmpty ? title : metadata.title),
            season: metadata.season,
            episode: metadata.episode,
            position: 0,
            duration: nil
        )
        showPlayer = true
    }

    private func receiveSourceMetadata(_ m: PageMetadata) {
        metadata = m
        let page = pageURLForHistory ?? sourcePageURL?.absoluteString ?? m.url
        history.progress(
            pageURL: page,
            playerURL: nil,
            title: MetadataParser.cleanTitle(m.title),
            season: m.season,
            episode: m.episode,
            position: 0,
            duration: nil
        )
        // If the source page exposes exactly one iframe, still let the user choose explicitly.
    }

    private func receivePlayerMetadata(_ m: PageMetadata) {
        let page = pageURLForHistory ?? sourcePageURL?.absoluteString ?? m.url
        history.progress(
            pageURL: page,
            playerURL: selectedPlayerURL?.absoluteString,
            title: MetadataParser.cleanTitle(metadata.title.isEmpty ? m.title : metadata.title),
            season: metadata.season ?? m.season,
            episode: metadata.episode ?? m.episode,
            position: m.position ?? 0,
            duration: m.duration
        )
    }

    private func receivePlayerNavigation(_ url: URL) {
        guard let page = pageURLForHistory ?? sourcePageURL?.absoluteString else { return }
        if page != url.absoluteString {
            history.progress(
                pageURL: page,
                playerURL: url.absoluteString,
                title: metadata.title,
                season: metadata.season,
                episode: metadata.episode,
                position: metadata.position ?? 0,
                duration: metadata.duration
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private struct PlayerScreen: View {
    let url: URL
    let blockAds: Bool
    let seekSeconds: Double?
    let onMetadata: (PageMetadata) -> Void
    let onNavigation: (URL) -> Void
    let onClose: () -> Void

    @State private var showControls = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            WebViewContainer(
                url: url,
                blockAds: blockAds,
                seekSeconds: seekSeconds,
                onMetadata: onMetadata,
                onNavigation: onNavigation
            )
            .ignoresSafeArea()
            .background(Color.black)

            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.65), in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 12)
            .accessibilityLabel("Закрыть плеер")
        }
        .preferredColorScheme(.dark)
    }
}
