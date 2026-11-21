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
    static let ink = Color(red: 0.24, green: 0.21, blue: 0.32)
    static let softBackground = Color(red: 0.97, green: 0.95, blue: 1.00)
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
                DreamyBackground(animate: animateGlow)
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
                    .presentationDetents([.medium])
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
                .background(.white.opacity(0.72), in: Circle())
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

            Text("A little space
for all your files.")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(TangiPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pick an installer and unpack its contents right here. Your original file stays where it is.")
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
                Text("No source-file copy • On-device extraction")
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(TangiPalette.deepLavender.opacity(0.82))
        }
        .padding(21)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(0.96),
                        Color(red: 1.0, green: 0.94, blue: 0.98),
                        Color(red: 0.93, green: 0.91, blue: 1.0)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
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
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
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
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeading("What can it unpack?", trailing: "MORE SOON")
            HStack(spacing: 10) {
                formatChip("EXE", name: "NSIS", active: true)
                formatChip("ZIP", name: "Coming soon", active: false)
                formatChip("7Z", name: "Coming soon", active: false)
                formatChip("RAR", name: "Coming soon", active: false)
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
                .background(active ? TangiPalette.lavender.opacity(0.15) : Color.white.opacity(0.65),
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
                        try NSISExtractionService.extractInstaller(at: url)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                AppMark(size: 42)
                Text("A tiny bit of magic")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(TangiPalette.ink)
            }
            Label("Choose a supported installer from Files.", systemImage: "doc.badge.plus")
            Label("TangiExtract reads it directly. The source is never copied.", systemImage: "hand.raised.fill")
            Label("Extracted contents are saved in My Files.", systemImage: "folder.fill")
            Label("Windows programs are never executed.", systemImage: "shield.lefthalf.filled")
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(TangiPalette.ink.opacity(0.82))
        .padding(24)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.98, green: 0.95, blue: 1),
                                    Color(red: 1, green: 0.95, blue: 0.97)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
}

private struct DreamyBackground: View {
    let animate: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.94, blue: 1.0),
                        Color(red: 1.0, green: 0.95, blue: 0.97),
                        Color(red: 0.92, green: 0.95, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(TangiPalette.pink.opacity(0.25))
                    .frame(width: 210, height: 210)
                    .blur(radius: 45)
                    .position(x: proxy.size.width * 0.94, y: 160 + (animate ? 12 : -12))
                Circle()
                    .fill(TangiPalette.lavender.opacity(0.19))
                    .frame(width: 230, height: 230)
                    .blur(radius: 48)
                    .position(x: 0, y: proxy.size.height * 0.72 + (animate ? -10 : 10))
                Circle()
                    .fill(TangiPalette.peach.opacity(0.17))
                    .frame(width: 150, height: 150)
                    .blur(radius: 38)
                    .position(x: proxy.size.width * 0.8, y: proxy.size.height * 0.92)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animate)
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
                TangiPalette.softBackground.ignoresSafeArea()
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
                                    .listRowBackground(Color.white.opacity(0.75))
                                } else {
                                    Button {
                                        previewURL = item.url
                                    } label: {
                                        fileRow(item)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.white.opacity(0.75))
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
                TangiPalette.softBackground.ignoresSafeArea()
                List {
                    Section {
                        HStack(spacing: 13) {
                            AppMark(size: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TangiExtract")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                Text("Everything inside. Nothing left behind.")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 7)
                        .listRowBackground(Color.white.opacity(0.8))
                    }

                    Section("PERSONALIZE") {
                        Picker(selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        } label: {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                        }
                        .listRowBackground(Color.white.opacity(0.8))
                    }

                    Section("EXTRACTION") {
                        Toggle(isOn: $openFilesAfterExtraction) {
                            Label("Open files after extraction", systemImage: "folder.badge.plus")
                        }
                        .tint(TangiPalette.lavender)
                        .listRowBackground(Color.white.opacity(0.8))

                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic feedback", systemImage: "hand.tap")
                        }
                        .tint(TangiPalette.lavender)
                        .listRowBackground(Color.white.opacity(0.8))

                        LabeledContent {
                            Text("On this device")
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Processing", systemImage: "iphone")
                        }
                        .listRowBackground(Color.white.opacity(0.8))
                    }

                    Section("STORAGE") {
                        LabeledContent {
                            Text("Extracted")
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Output folder", systemImage: "folder")
                        }
                        .listRowBackground(Color.white.opacity(0.8))

                        LabeledContent {
                            Text("Temporary files are cleaned after each job")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Label("Temporary data", systemImage: "trash")
                        }
                        .listRowBackground(Color.white.opacity(0.8))
                    }

                    Section("ABOUT") {
                        LabeledContent("Version", value: "0.2.0")
                            .listRowBackground(Color.white.opacity(0.8))
                        Link(destination: URL(string: "https://github.com/TangiDev69/TangiExtract")!) {
                            Label("GitHub project", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        .listRowBackground(Color.white.opacity(0.8))
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
