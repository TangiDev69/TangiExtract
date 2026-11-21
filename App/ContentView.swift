import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import UIKit

private enum TangiPalette {
    static let lavender = Color(red: 0.57, green: 0.43, blue: 0.88)
    static let deepLavender = Color(red: 0.39, green: 0.29, blue: 0.70)
    static let pink = Color(red: 1.00, green: 0.72, blue: 0.82)
    static let peach = Color(red: 1.00, green: 0.82, blue: 0.68)
    static let mint = Color(red: 0.65, green: 0.86, blue: 0.78)
    static let ink = Color(uiColor: .label)
    static let softBackground = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let subtleCard = Color(uiColor: .tertiarySystemGroupedBackground)
}

struct ContentView: View {
    @AppStorage("tangi.appearance") private var appearance = "system"
    @AppStorage("tangi.openFilesAfterExtraction") private var openFilesAfterExtraction = true
    @State private var selectedTab = 0

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(onOpenFiles: { selectedTab = 1 }) {
                if openFilesAfterExtraction { selectedTab = 1 }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            FileBrowserView()
                .tabItem { Label("My Files", systemImage: "folder.fill") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(2)
        }
            .tint(TangiPalette.deepLavender)
        .preferredColorScheme(preferredScheme)
    }
}

private struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onOpenFiles: () -> Void
    let onExtractionCompleted: () -> Void
    @State private var showingFilePicker = false
    @State private var isExtracting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var recentFolder: URL?
    @State private var recentFileName: String?
    @State private var animateGlow = false
    @State private var showingHowItWorks = false
    @AppStorage("tangi.haptics") private var hapticsEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                DreamyBackground(animate: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        topBar
                        heroCard
                        quickActions
                        recentSection
                        formatSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false,
                onCompletion: handleSelectedFile
            )
            .sheet(isPresented: $showingHowItWorks) {
                HowItWorksSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Couldn't extract this file", isPresented: $showError) {
                Button("Okay", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                animateGlow = true
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            AppMark(size: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text("TangiExtract")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(TangiPalette.ink)
                Text("your files, all unpacked ♡")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(TangiPalette.lavender)
                .padding(11)
                .background(TangiPalette.card, in: Circle())
        }
        .padding(.top, 8)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("FILE EXTRACTOR", systemImage: "wand.and.stars")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(TangiPalette.deepLavender)
                Spacer()
                Text("♡")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TangiPalette.pink)
            }

            Text("A little space\nfor all your files.")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(TangiPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pick an archive or compatible installer and unpack its contents here. Your original file stays where it is.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(TangiPalette.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showingFilePicker = true
            } label: {
                HStack(spacing: 10) {
                    if isExtracting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                    }
                    Text(isExtracting ? "Unpacking your files…" : "Choose a file to extract")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [TangiPalette.lavender, TangiPalette.deepLavender],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: TangiPalette.deepLavender.opacity(0.22), radius: 12, x: 0, y: 7)
            }
            .disabled(isExtracting)
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                Text("Temporary working copy • On-device extraction")
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(TangiPalette.deepLavender.opacity(0.82))
        }
        .padding(21)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: colorScheme == .dark ? [Color(uiColor: .secondarySystemBackground), Color(uiColor: .tertiarySystemBackground)] : [Color.white, Color(red: 1.0, green: 0.94, blue: 0.98), Color(red: 0.93, green: 0.91, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(TangiPalette.pink.opacity(0.22))
                        .frame(width: 110, height: 110)
                        .blur(radius: 28)
                        .offset(x: 24, y: -28)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: TangiPalette.deepLavender.opacity(0.09), radius: 18, x: 0, y: 9)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickAction("Browse files", subtitle: "Your extracted folders", icon: "folder.fill",
                        tint: TangiPalette.lavender) {
                onOpenFiles()
            }
            quickAction("How it works", subtitle: "Safe & on-device", icon: "heart.text.square.fill",
                        tint: Color(red: 0.91, green: 0.55, blue: 0.69)) {
                showingHowItWorks = true
            }
        }
    }

    private func quickAction(_ title: String, subtitle: String, icon: String, tint: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(TangiPalette.ink)
                    Text(subtitle).font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TangiPalette.card, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeading("Recently unpacked", trailing: "MY FILES")
            HStack(spacing: 12) {
                Image(systemName: recentFolder == nil ? "tray" : "checkmark.folder.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(TangiPalette.lavender)
                    .frame(width: 44, height: 44)
                    .background(TangiPalette.lavender.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(recentFileName ?? "Nothing unpacked yet")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TangiPalette.ink)
                        .lineLimit(1)
                    Text(recentFolder?.lastPathComponent ?? "Your finished extractions will appear here.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if recentFolder != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                }
            }
            .padding(14)
            .background(TangiPalette.card, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeading("Supported formats", trailing: "SUPPORTED")
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    formatChip("ZIP", name: "Archive", active: true)
                    formatChip("7Z", name: "7-Zip", active: true)
                    formatChip("RAR", name: "RAR", active: true)
                    formatChip("CAB", name: "Cabinet", active: true)
                }
                HStack(spacing: 8) {
                    formatChip("TAR", name: "Archive", active: true)
                    formatChip("TGZ", name: "TAR + Gzip", active: true)
                    formatChip("TBZ2", name: "TAR + Bzip2", active: true)
                    formatChip("TXZ", name: "TAR + XZ", active: true)
                }
                HStack(spacing: 8) {
                    formatChip("TZST", name: "TAR + Zstd", active: true)
                    formatChip("TLZ4", name: "TAR + LZ4", active: true)
                    formatChip("GZ", name: "Gzip", active: true)
                    formatChip("BZ2", name: "Bzip2", active: true)
                }
                HStack(spacing: 8) {
                    formatChip("XZ", name: "XZ", active: true)
                    formatChip("ZST", name: "Zstandard", active: true)
                    formatChip("LZ4", name: "LZ4", active: true)
                    formatChip("EXE", name: "NSIS", active: true)
                }
                HStack(spacing: 8) { formatChip("ISO", name: "Disc image", active: true); formatChip("CPIO", name: "Archive", active: true); formatChip("AR", name: "Unix archive", active: true); formatChip("LHA", name: "LZH", active: true) }
                HStack(spacing: 8) { formatChip("ARJ", name: "Archive", active: true); formatChip("XAR", name: "Archive", active: true); formatChip("WIM", name: "Windows image", active: true); formatChip("DMG", name: "Apple image", active: true) }
                HStack(spacing: 8) { formatChip("MSI", name: "Installer data", active: true); formatChip("CHM", name: "Help archive", active: true); formatChip("RPM", name: "Package", active: true); formatChip("LZIP", name: "Compression", active: true) }
                HStack(spacing: 8) { formatChip("LZMA", name: "Compression", active: true); formatChip("ZOO", name: "Archive", active: true); formatChip("ALZ", name: "Archive", active: true); formatChip("EGG", name: "Archive", active: true) }
            }
        }
    }

    private func formatChip(_ type: String, name: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Text(type)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(active ? TangiPalette.deepLavender : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(active ? TangiPalette.lavender.opacity(0.15) : TangiPalette.subtleCard.opacity(0.92),
                            in: RoundedRectangle(cornerRadius: 13))
            Text(name)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("made with a little magic ✦")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.8))
            Spacer()
        }
        .padding(.top, 2)
    }

    private func sectionHeading(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TangiPalette.ink)
            Spacer()
            Text(trailing)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(TangiPalette.deepLavender.opacity(0.75))
        }
    }

    private func handleSelectedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            isExtracting = true
            Task {
                do {
                    let destination = try await Task.detached(priority: .userInitiated) {
                        try ExtractionService.extractFile(at: url)
                    }.value
                    recentFolder = destination
                    recentFileName = url.lastPathComponent
                    if hapticsEnabled {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    onExtractionCompleted()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                isExtracting = false
            }
        }
    }
}

private struct HowItWorksSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 10) {
                    AppMark(size: 42)
                    Text("How TangiExtract works")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(TangiPalette.ink)
                }

                instructionCard(
                    title: "1. Choose a file",
                    detail: "Tap “Choose a file to extract” and select a supported archive or container in Files. TangiExtract coordinates access and stages a temporary working copy before extraction.",
                    icon: "doc.badge.plus"
                )
                instructionCard(
                    title: "If selecting the file does nothing",
                    detail: "You normally should not need Share. If the Files picker cannot expose a file in your sideloading environment, use Share as a fallback; LiveContainer may require importing it into its own file area first.",
                    icon: "square.and.arrow.up"
                )
                instructionCard(
                    title: "2. Extract on your device",
                    detail: "TangiExtract makes a temporary, coordinated local working copy, extracts on-device, then removes that temporary copy. Your original file is left unchanged.",
                    icon: "hand.raised.fill"
                )
                instructionCard(
                    title: "3. Find your files",
                    detail: "Extracted contents appear in My Files. You can browse, preview, share, rename, or delete them.",
                    icon: "folder.fill"
                )
                instructionCard(
                    title: "Safety",
                    detail: "Supported Windows installers are read as data. Windows programs are never run on your iPhone.",
                    icon: "shield.lefthalf.filled"
                )
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(TangiPalette.ink.opacity(0.82))
            .padding(24)
            .padding(.top, 10)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    private func instructionCard(title: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(TangiPalette.deepLavender)
            Text(detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(TangiPalette.ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TangiPalette.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

private struct DreamyBackground: View {
    let animate: Bool
    @Environment(\.colorScheme) private var colorScheme
    private let particles: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("🍓",0.08,0.08,19),("🍊",0.83,0.12,17),("🍒",0.28,0.22,16),("📄",0.68,0.29,15),
        ("🍋",0.14,0.39,18),("📁",0.91,0.47,17),("🫐",0.42,0.55,16),("🍑",0.76,0.68,18),
        ("📦",0.20,0.79,17),("🍇",0.56,0.91,18),("✨",0.94,0.88,13),("🍏",0.04,0.64,15),
        ("🗂️",0.36,0.12,15),("🍉",0.61,0.43,17),("📃",0.10,0.94,14),("🍍",0.88,0.30,17),
        ("🍐",0.48,0.76,16),("🧃",0.31,0.48,15),("🧸",0.72,0.08,16),("💌",0.06,0.28,14)
    ]
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: colorScheme == .dark
                    ? [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)]
                    : [Color(red: 1, green: 0.97, blue: 0.99), Color(red: 0.96, green: 0.94, blue: 1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !animate)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        for (index, particle) in particles.enumerated() {
                            let (symbol, x, y, fontSize) = particle
                            let fall = (time * (8 + Double(index % 5) * 2) + Double(index) * 61).truncatingRemainder(dividingBy: Double(size.height + 100))
                            let sway = CGFloat(sin(time * 0.55 + Double(index) * 1.31) * 15)
                            let px = x * size.width + sway
                            let py = CGFloat(fall) - 45 + y * 20
                            context.opacity = colorScheme == .dark ? 0.52 : 0.76
                            context.draw(Text(symbol).font(.system(size: fontSize)), at: CGPoint(x: px, y: py))
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private struct AppMark: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(LinearGradient(colors: [TangiPalette.pink, TangiPalette.lavender],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "shippingbox.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.24, weight: .bold))
                        .foregroundStyle(Color.yellow)
                        .offset(x: 5, y: -5)
                }
        }
        .frame(width: size, height: size)
        .shadow(color: TangiPalette.deepLavender.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

private struct FileBrowserView: View {
    let directory: URL
    @State private var items: [LocalFileItem] = []
    @State private var searchText = ""
    @State private var previewURL: URL?
    @State private var renameTarget: URL?
    @State private var renameText = ""
    @State private var showingRename = false
    @State private var showingDeleteAlert = false
    @State private var deleteTarget: URL?
    @State private var errorText: String?
    @State private var sortNewestFirst = true

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.directory = documents.appendingPathComponent("Extracted", isDirectory: true)
        }
    }

    private var visibleItems: [LocalFileItem] {
        let filtered = searchText.isEmpty ? items : items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return sortNewestFirst ? $0.modified > $1.modified : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DreamyBackground(animate: true)
                if items.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(visibleItems) { item in
                                if item.isDirectory {
                                    NavigationLink {
                                        FileBrowserView(directory: item.url)
                                    } label: {
                                        fileRow(item)
                                    }
                                    .listRowBackground(TangiPalette.card.opacity(0.90))
                                } else {
                                    Button {
                                        previewURL = item.url
                                    } label: {
                                        fileRow(item)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(TangiPalette.card.opacity(0.90))
                                    .contextMenu {
                                        ShareLink(item: item.url) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        Button {
                                            renameTarget = item.url
                                            renameText = item.name
                                            showingRename = true
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            deleteTarget = item.url
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("\(items.count) ITEMS")
                                Spacer()
                                Text(directory.lastPathComponent.uppercased())
                            }
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(directory.lastPathComponent == "Extracted" ? "My Files" : directory.lastPathComponent)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Find a file or folder")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            sortNewestFirst = true
                        } label: {
                            Label("Newest first", systemImage: sortNewestFirst ? "checkmark" : "clock")
                        }
                        Button {
                            sortNewestFirst = false
                        } label: {
                            Label("Name A–Z", systemImage: !sortNewestFirst ? "checkmark" : "textformat")
                        }
                        Button {
                            loadItems()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear(perform: loadItems)
            .onChange(of: directory) { _ in loadItems() }
            .quickLookPreview($previewURL)
            .alert("Rename file", isPresented: $showingRename) {
                TextField("New name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") { renameFile() }
            } message: {
                Text("Choose a new name for this item.")
            }
            .alert("Delete this item?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteFile() }
            } message: {
                Text("This permanently removes the selected item from TangiExtract.")
            }
            .alert("File operation failed", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("Okay", role: .cancel) { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(TangiPalette.lavender.opacity(0.12)).frame(width: 116, height: 116)
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(TangiPalette.lavender)
            }
            Text("It's a little empty here")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(TangiPalette.ink)
            Text("Once you unpack something, its files and folders will show up here.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .padding(28)
    }

    private func fileRow(_ item: LocalFileItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : iconForExtension(item.url.pathExtension))
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(item.isDirectory ? TangiPalette.lavender : TangiPalette.deepLavender.opacity(0.8))
                .frame(width: 42, height: 42)
                .background(TangiPalette.lavender.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TangiPalette.ink)
                    .lineLimit(1)
                Text(item.isDirectory ? "Folder" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !item.isDirectory {
                ShareLink(item: item.url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TangiPalette.deepLavender)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif": return "photo"
        case "mp4", "mov", "m4v": return "video"
        case "mp3", "wav", "m4a": return "waveform"
        case "txt", "md", "cfg", "ini", "json", "xml": return "doc.text"
        case "pdf": return "doc.richtext"
        case "exe", "dll", "so", "dylib": return "curlybraces"
        default: return "doc"
        }
    }

    private func loadItems() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            items = urls.map { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                return LocalFileItem(url: url, isDirectory: values?.isDirectory ?? false,
                                     size: Int64(values?.fileSize ?? 0),
                                     modified: values?.contentModificationDate ?? .distantPast)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func renameFile() {
        guard let target = renameTarget else { return }
        let clean = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.contains("/"), clean != ".", clean != ".." else {
            errorText = "That name isn't valid."
            return
        }
        do {
            let destination = target.deletingLastPathComponent().appendingPathComponent(clean)
            try FileManager.default.moveItem(at: target, to: destination)
            loadItems()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func deleteFile() {
        guard let target = deleteTarget else { return }
        do {
            try FileManager.default.removeItem(at: target)
            loadItems()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct LocalFileItem: Identifiable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modified: Date
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

private struct SettingsView: View {
    @AppStorage("tangi.appearance") private var appearance = "system"
    @AppStorage("tangi.openFilesAfterExtraction") private var openFilesAfterExtraction = true
    @AppStorage("tangi.haptics") private var hapticsEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                DreamyBackground(animate: true)
                List {
                    Section {
                        HStack(spacing: 13) {
                            AppMark(size: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TangiExtract")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                Text("Archive and installer extraction for iOS.")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 7)
                        .listRowBackground(TangiPalette.card.opacity(0.92))
                    }

                    Section("PERSONALIZE") {
                        Picker(selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        } label: {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                        }
                        .listRowBackground(TangiPalette.card.opacity(0.92))
                    }

                    Section("EXTRACTION") {
                        Toggle(isOn: $openFilesAfterExtraction) {
                            Label("Open files after extraction", systemImage: "folder.badge.plus")
                        }
                        .tint(TangiPalette.lavender)
                        .listRowBackground(TangiPalette.card.opacity(0.92))

                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic feedback", systemImage: "hand.tap")
                        }
                        .tint(TangiPalette.lavender)
                        .listRowBackground(TangiPalette.card.opacity(0.92))

                        LabeledContent {
                            Text("On this device")
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Processing", systemImage: "iphone")
                        }
                        .listRowBackground(TangiPalette.card.opacity(0.92))
                    }

                    Section("STORAGE") {
                        LabeledContent {
                            Text("Extracted")
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Output folder", systemImage: "folder")
                        }
                        .listRowBackground(TangiPalette.card.opacity(0.92))

                        LabeledContent {
                            Text("Temporary files are cleaned after each job")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Label("Temporary data", systemImage: "trash")
                        }
                        .listRowBackground(TangiPalette.card.opacity(0.92))
                    }

                    Section("ABOUT") {
                        LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")
                            .listRowBackground(TangiPalette.card.opacity(0.92))
                        Link(destination: URL(string: "https://github.com/TangiDev69/TangiExtract")!) {
                            Label("GitHub project", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        .listRowBackground(TangiPalette.card.opacity(0.92))
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
