import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingImporter = false
    @State private var isExtracting = false
    @State private var statusMessage = "Import a Windows NSIS installer to get started."
    @State private var extractedLocation: String?
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    importCard
                    capabilitySection
                    storageSection
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TangiExtract")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .alert("Extraction failed", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusMessage)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVERYTHING INSIDE.")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.tint)
            Text("Nothing left behind.")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Inspect and extract files from installers and archives. More formats are being added.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                Text("IMPORT")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }

            Text("Bring a file into TangiExtract")
                .font(.title3.weight(.bold))

            Text("Choose a Windows installer. The current development build extracts NSIS installers; unsupported executables are reported instead of being treated as archives.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showingImporter = true
            } label: {
                HStack(spacing: 10) {
                    if isExtracting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "folder")
                    }
                    Text(isExtracting ? "Extracting…" : "Choose a file")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isExtracting)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var capabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT CAPABILITIES")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(.secondary)

            capabilityRow("NSIS Windows installers", detail: "Initial native Rust backend", state: "Available", available: true)
            capabilityRow("ZIP, 7Z, RAR and TAR", detail: "Archive engine integration is next", state: "Planned", available: false)
            capabilityRow("APK, IPA, ISO and CAB", detail: "Identification and format-specific inspection", state: "Planned", available: false)
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LATEST ACTIVITY")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: extractedLocation == nil ? "clock" : "checkmark.circle.fill")
                    .foregroundStyle(extractedLocation == nil ? Color.secondary : Color.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text(extractedLocation == nil ? "Ready when you are" : "Extraction completed")
                        .font(.subheadline.weight(.semibold))
                    Text(extractedLocation ?? statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func capabilityRow(_ title: String, detail: String, state: String, available: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: available ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(available ? .green : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(state)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            statusMessage = error.localizedDescription
            isShowingError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            isExtracting = true
            statusMessage = "Preparing extraction…"

            Task {
                do {
                    let destination = try await Task.detached(priority: .userInitiated) {
                        try NSISExtractionService.extractInstaller(at: url)
                    }.value
                    extractedLocation = destination.lastPathComponent
                    statusMessage = "Saved in Documents/Extracted/\(destination.lastPathComponent)"
                } catch {
                    statusMessage = error.localizedDescription
                    isShowingError = true
                }
                isExtracting = false
            }
        }
    }
}
