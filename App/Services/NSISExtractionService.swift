import Foundation

@_silgen_name("tangiextract_zip_extract")
private func tangiextract_zip_extract(
    _ inputPath: UnsafePointer<CChar>,
    _ outputPath: UnsafePointer<CChar>,
    _ errorBuffer: UnsafeMutablePointer<CChar>,
    _ errorCapacity: Int
) -> Int32

@_silgen_name("tangiextract_nsis_extract")
private func tangiextract_nsis_extract(
    _ inputPath: UnsafePointer<CChar>,
    _ outputPath: UnsafePointer<CChar>,
    _ errorBuffer: UnsafeMutablePointer<CChar>,
    _ errorCapacity: Int
) -> Int32

enum ExtractionServiceError: LocalizedError {
    case unsupportedFormat
    case cannotCreateStorage
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Supported formats are ZIP archives and NSIS-based Windows installers (.exe)."
        case .cannotCreateStorage:
            return "TangiExtract could not prepare its temporary extraction folder."
        case .extractionFailed(let detail):
            return detail
        }
    }
}

enum NSISExtractionService {
    /// Extracts directly from the selected file URL. The source file is never
    /// copied into the app's storage; only extracted output is retained.
    static func extractInstaller(at sourceURL: URL) throws -> URL {
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        guard fileExtension == "exe" || fileExtension == "zip" else {
            throw ExtractionServiceError.unsupportedFormat
        }

        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExtractionServiceError.cannotCreateStorage
        }

        let extracted = documents.appendingPathComponent("Extracted", isDirectory: true)
        let temporary = fileManager.temporaryDirectory
            .appendingPathComponent("TangiExtract", isDirectory: true)
        do {
            try fileManager.createDirectory(at: extracted, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        } catch {
            throw ExtractionServiceError.cannotCreateStorage
        }

        let jobDirectory = temporary.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputDirectory = jobDirectory.appendingPathComponent("Output", isDirectory: true)

        do {
            try fileManager.createDirectory(at: jobDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: jobDirectory) }

            var errorBuffer = [CChar](repeating: 0, count: 2048)
            let status = sourceURL.path.withCString { inputPath in
                outputDirectory.path.withCString { outputPath in
                    errorBuffer.withUnsafeMutableBufferPointer { buffer in
                        if fileExtension == "zip" {
                            tangiextract_zip_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                        } else {
                            tangiextract_nsis_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                        }
                    }
                }
            }

            guard status == 0 else {
                let detail = String(cString: errorBuffer)
                throw ExtractionServiceError.extractionFailed(
                    detail.isEmpty ? "The NSIS extraction engine returned an unknown error." : detail
                )
            }

            let rawName = sourceURL.deletingPathExtension().lastPathComponent
            let safeName = rawName
                .components(separatedBy: CharacterSet(charactersIn: "/\\\\:"))
                .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
                .joined(separator: "-")
            let folderName = "\(safeName.isEmpty ? "Extracted files" : safeName)-\(UUID().uuidString.prefix(6))"
            let destination = extracted.appendingPathComponent(folderName, isDirectory: true)

            // Publish only a fully extracted result. Failed jobs remain temporary
            // and are removed by the defer above.
            try fileManager.moveItem(at: outputDirectory, to: destination)
            return destination
        } catch let error as ExtractionServiceError {
            throw error
        } catch {
            throw ExtractionServiceError.extractionFailed(error.localizedDescription)
        }
    }
}
