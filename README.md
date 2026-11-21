# TangiExtract

TangiExtract is a lightweight, on-device iOS archive and installer extractor with a built-in file browser. It is designed for importing game files, unpacking archives, and inspecting supported Windows installers—without sending files to a server.

## Features

- Extract supported archives and compression streams locally on iPhone or iPad.
- Parse supported NSIS Windows installers (`.exe`) as data; Windows programs are never executed.
- Open files directly from the iOS Files picker, including supported document-provider locations, using coordinated reads and temporary staging.
- Keep the original source file in its original location and unchanged.
- Browse extracted content in the in-app **My Files** browser.
- Search, sort, preview with Quick Look, share, rename, and delete extracted items.
- Light, dark, and system appearance settings.
- Clean up temporary working files after each extraction.

## Supported formats

The original extraction engines remain in place for the common formats. An additional pure-Rust engine adds broad archive, disk-image, document-container and installer-container support.

| Family | Formats / extensions | Notes |
|---|---|---|
| Common archives | ZIP, 7Z, RAR, CAB, TAR | Dedicated extraction paths; RAR is single-volume and unencrypted |
| TAR compression | TGZ, TAR.GZ, TBZ2, TAR.BZ2, TXZ, TAR.XZ, TAR.ZST, TAR.LZ4 | Dedicated extraction paths |
| Standalone compression | GZ, BZ2, XZ, ZST, LZ4 | Dedicated extraction paths |
| Additional archives | ARJ, LHA/LZH, ARC, ZOO, ALZ, EGG, AR, CPIO, XAR, RPM | Extended engine |
| Disk images / filesystems | ISO/UDF, DMG, VHD, VHDX, QCOW2, VMDK, WIM, FAT, exFAT, NTFS, ext, SquashFS, cramfs, romfs, EROFS | Extended engine; output depends on the image and filesystem |
| Installer / help containers | MSI/OLE2, Inno Setup, InstallShield containers, CHM, NSIS-compatible EXE | Extended engine where implemented; NSIS also has the dedicated path |
| Embedded-content containers | PDF, RTF, email/MIME, TNEF, OneNote, XDP, AppleSingle/AppleDouble, BinHex, SWF | Extracts supported embedded streams or attachments, not a full document conversion |

The extended engine recognises additional formats and uses a bounded extraction budget. Some formats are metadata-only, recognised but not fully decoded, or expose embedded streams rather than a conventional directory tree. Unsupported codecs, encrypted members, and malformed content return an error rather than being silently treated as extracted.

**Confirmed on the developer's device:** ZIP, 7Z, RAR, TAR, TAR.GZ, and standalone GZ. NSIS-compatible EXE extraction was confirmed in earlier testing. CAB and the newly added extended formats have not yet been device-tested. CI builds and parser integration do not replace real-file testing on iPhone.

**Known limitations:** password-protected and multipart RAR are not supported by the dedicated RAR path; multi-cabinet CAB sets are not supported by the dedicated CAB path. The extended engine has its own format-specific limitations and resource limits. A file extension alone does not guarantee that a file is supported. Windows executables are parsed as data and never run on iOS.
## How to use

1. Tap **Choose a file to extract** and pick the file from the iOS Files picker.
2. TangiExtract coordinates access to the selected file and makes a temporary working copy before extraction. You normally do not need to share the file into the app. If the picker cannot expose it in your sideloading environment, use **Share** as a fallback; LiveContainer may require importing the file into its own file area first.
3. When extraction completes, open **My Files** to browse the output.

## Privacy and storage

- Extraction is performed on-device; files are not uploaded to a service.
- Files-provider access is coordinated through iOS security-scoped access. A temporary working copy is made inside the app container for reliable native extraction, then deleted when the job finishes.
- Finished output is stored under **Files → On My iPhone → TangiExtract → Extracted**.
- Temporary working files are created for each extraction and removed after the operation.

## Downloads

- **[Latest release / IPA](https://github.com/TangiDev69/TangiExtract/releases/latest)** — the latest GitHub release
- **[Build history](https://github.com/TangiDev69/TangiExtract/actions)** — automated builds and CI results

The IPA is unsigned and is intended for compatible sideloading tools such as SideStore, AltStore, and LiveContainer. Installation behavior varies by tool and device.

## Architecture

- **SwiftUI:** UI, document picker, file browser, settings, and iOS file access.
- **Swift services:** temporary output management and bridge to extraction engines.
- **Rust:** native parsing/extraction libraries.
- **GitHub Actions:** Rust tests, iOS ARM64 compilation, and unsigned IPA packaging.

## Security notes

Extraction is subject to resource limits and path validation. ZIP extraction rejects unsafe paths and symbolic links; TAR extraction rejects unsafe paths, links, and special entries. RAR extraction is currently limited to single-volume, unencrypted archives; password-protected and multipart archives are not supported. CAB decoding is handled by the native CAB library; cabinet sets spanning multiple files are not supported. The extended engine covers additional archive, image, filesystem, document and installer containers; see the format table for representative families and limitations. This extractor is still evolving; be cautious with untrusted archives.

## License and third-party notices

See [LICENSE](LICENSE) and [NOTICE](NOTICE). Third-party dependencies retain their respective licenses.
