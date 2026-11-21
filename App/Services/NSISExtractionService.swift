import Foundation

@_silgen_name("tangiextract_zip_extract")
private func tangiextract_zip_extract(
    _ inputPath: UnsafePointer<CChar>,
    _ outputPath: UnsafePointer<CChar>,
    _ errorBuffer: UnsafeMutablePointer<CChar>,
    _ errorCapacity: Int
) -> Int32

@_silgen_name("tangiextract_tar_extract")
private func tangiextract_tar_extract(_ inputPath: UnsafePointer<CChar>, _ outputPath: UnsafePointer<CChar>, _ gzip: Int32, _ errorBuffer: UnsafeMutablePointer<CChar>, _ errorCapacity: Int) -> Int32

@_silgen_name("tangiextract_cab_extract")
private func tangiextract_cab_extract(_ inputPath: UnsafePointer<CChar>, _ outputPath: UnsafePointer<CChar>, _ errorBuffer: UnsafeMutablePointer<CChar>, _ errorCapacity: Int) -> Int32

@_silgen_name("tangiextract_rar_extract")
private func tangiextract_rar_extract(_ inputPath: UnsafePointer<CChar>, _ outputPath: UnsafePointer<CChar>, _ errorBuffer: UnsafeMutablePointer<CChar>, _ errorCapacity: Int) -> Int32

@_silgen_name("tangiextract_7z_extract")
private func tangiextract_7z_extract(_ inputPath: UnsafePointer<CChar>, _ outputPath: UnsafePointer<CChar>, _ errorBuffer: UnsafeMutablePointer<CChar>, _ errorCapacity: Int) -> Int32

@_silgen_name("tangiextract_stream_extract")
private func tangiextract_stream_extract(_ inputPath: UnsafePointer<CChar>, _ outputPath: UnsafePointer<CChar>, _ kind: Int32, _ errorBuffer: UnsafeMutablePointer<CChar>, _ errorCapacity: Int) -> Int32

@_silgen_name("tangiextract_extended_extract")
private func tangiextract_extended_extract(_ inputPath: UnsafePointer<CChar>, _ outputPath: UnsafePointer<CChar>, _ errorBuffer: UnsafeMutablePointer<CChar>, _ errorCapacity: Int) -> Int32

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
            return "Supported formats include ZIP, 7Z, RAR, CAB, TAR and common compression streams, plus additional archive, disk-image, document and installer containers. Some formats expose embedded contents rather than a conventional file tree."
        case .cannotCreateStorage:
            return "TangiExtract could not prepare its temporary extraction folder."
        case .extractionFailed(let detail):
            return detail
        }
    }
}

enum ExtractionService {
    /// Extracts directly from the selected file URL. The source file is never
    /// copied into the app's storage; only extracted output is retained.
    static func extractFile(at sourceURL: URL) throws -> URL {
        // Keep the security-scoped permission active while coordinating and staging
        // provider-backed files (iCloud Drive, external providers, etc.).
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("TangiExtract", isDirectory: true)
            .appendingPathComponent("ImportedSources", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        let stagedURL = stagingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension)
        var coordinationError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try fileManager.copyItem(at: coordinatedURL, to: stagedURL)
            } catch {
                copyError = error
            }
        }
        if let copyError {
            throw ExtractionServiceError.extractionFailed("Could not read the selected file through the Files provider: \(copyError.localizedDescription)")
        }
        if let coordinationError {
            try? fileManager.removeItem(at: stagedURL)
            throw ExtractionServiceError.extractionFailed("iOS could not coordinate access to this file: \(coordinationError.localizedDescription)")
        }
        guard fileManager.fileExists(atPath: stagedURL.path) else {
            throw ExtractionServiceError.extractionFailed("The selected file was not made available by its Files provider.")
        }
        defer { try? fileManager.removeItem(at: stagedURL) }
        return try extractLocalFile(at: stagedURL, displayName: sourceURL.lastPathComponent)
    }

    private static func extractLocalFile(at sourceURL: URL, displayName: String) throws -> URL {
        let fileExtension = URL(fileURLWithPath: displayName).pathExtension.lowercased()
        let lowerName = displayName.lowercased()
        let tarCompression: Int32 = lowerName.hasSuffix(".tar.gz") || fileExtension == "tgz" ? 1 :
            (lowerName.hasSuffix(".tar.bz2") || fileExtension == "tbz2" ? 2 :
            (lowerName.hasSuffix(".tar.xz") || fileExtension == "txz" ? 3 :
            (lowerName.hasSuffix(".tar.zst") ? 4 : (lowerName.hasSuffix(".tar.lz4") ? 5 : 0))))
        let isTarCompressed = tarCompression != 0
        let isTar = fileExtension == "tar"
        let is7z = fileExtension == "7z"
        let isRar = fileExtension == "rar"
        let isCab = fileExtension == "cab"
        let streamKind: Int32 = fileExtension == "gz" ? 1 : (fileExtension == "bz2" ? 2 :
            (fileExtension == "xz" ? 3 : (fileExtension == "zst" ? 4 : (fileExtension == "lz4" ? 5 : 0))))
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
                            return tangiextract_zip_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                        } else if is7z {
                            return tangiextract_7z_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                        } else if isRar {
                            return tangiextract_rar_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                        } else if isCab {
                            return tangiextract_cab_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                        } else if streamKind != 0 && !isTarCompressed {
                            let outputFileName = URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent
                            let outputFile = outputDirectory.appendingPathComponent(outputFileName)
                            return outputFile.path.withCString { outputPath in
                                tangiextract_stream_extract(inputPath, outputPath, streamKind, buffer.baseAddress!, buffer.count)
                            }
                        } else if isTar || isTarCompressed {
                            return tangiextract_tar_extract(inputPath, outputPath, tarCompression, buffer.baseAddress!, buffer.count)
                        } else if fileExtension == "exe" {
                            return tangiextract_nsis_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
                        } else {
                            return tangiextract_extended_extract(inputPath, outputPath, buffer.baseAddress!, buffer.count)
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

            let rawName = URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent
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
