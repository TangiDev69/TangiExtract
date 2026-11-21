import Foundation

@_silgen_name("ac_nsis_extract")
private func ac_nsis_extract(
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
            return "The first development build supports NSIS Windows installers (.exe) only."
        case .cannotCreateStorage:
            return "TangiExtract could not prepare its storage directories."
        case .extractionFailed(let detail):
            return detail
        }
    }
}

enum NSISExtractionService {
    static func extractInstaller(at sourceURL: URL) throws -> URL {
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard sourceURL.pathExtension.lowercased() == "exe" else {
            throw ExtractionServiceError.unsupportedFormat
        }

        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExtractionServiceError.cannotCreateStorage
        }

        let imports = documents.appendingPathComponent("Imports", isDirectory: true)
        let extracted = documents.appendingPathComponent("Extracted", isDirectory: true)
        let temporary = documents.appendingPathComponent("Temporary", isDirectory: true)

        do {
            try fileManager.createDirectory(at: imports, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: extracted, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        } catch {
            throw ExtractionServiceError.cannotCreateStorage
        }

        let jobDirectory = temporary.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let inputCopy = jobDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        let outputDirectory = jobDirectory.appendingPathComponent("Output", isDirectory: true)

        do {
            try fileManager.createDirectory(at: jobDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: jobDirectory) }

            // Copy into app-controlled temporary storage before invoking native code.
            try fileManager.copyItem(at: sourceURL, to: inputCopy)

            var errorBuffer = [CChar](repeating: 0, count: 2048)
            let status = inputCopy.path.withCString { inputPath in
                outputDirectory.path.withCString { outputPath in
                    errorBuffer.withUnsafeMutableBufferPointer { buffer in
                        ac_nsis_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                    }
                }
            }

            guard status == 0 else {
                let detail = String(cString: errorBuffer)
                throw ExtractionServiceError.extractionFailed(
                    detail.isEmpty ? "The NSIS extraction engine returned an unknown error." : detail
                )
            }

            let baseName = sourceURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
            let destination = extracted.appendingPathComponent(
                "\(baseName.isEmpty ? "Installer" : baseName)-\(UUID().uuidString.prefix(8))",
                isDirectory: true
            )

            // The native engine writes only into a unique temporary directory.
            // Publish the completed result with a same-volume directory move.
            try fileManager.moveItem(at: outputDirectory, to: destination)
            return destination
        } catch let error as ExtractionServiceError {
            throw error
        } catch {
            throw ExtractionServiceError.extractionFailed(error.localizedDescription)
        }
    }
}
