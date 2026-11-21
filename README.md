# TangiExtract

**Everything inside. Nothing left behind.**

TangiExtract is a lightweight, on-device iOS archive and installer extractor with a built-in file browser. It is designed for importing game files, unpacking archives, and inspecting supported Windows installers—without sending files to a server.

## Features

- Extract supported archives and compression streams locally on iPhone or iPad.
- Parse supported NSIS Windows installers (`.exe`) as data; Windows programs are never executed.
- Keep the original source file in its original location.
- Browse extracted content in the in-app **My Files** browser.
- Search, sort, preview with Quick Look, share, rename, and delete extracted items.
- Light, dark, and system appearance settings.
- Clean up temporary working files after each extraction.

## Supported formats

| Format | Extensions | Status |
|---|---|---|
| ZIP | `.zip` | Implemented |
| 7-Zip | `.7z` | Implemented |
| TAR | `.tar` | Implemented |
| TAR + Gzip | `.tar.gz`, `.tgz` | Implemented |
| TAR + Bzip2 | `.tar.bz2`, `.tbz2` | Implemented |
| TAR + XZ | `.tar.xz`, `.txz` | Implemented |
| TAR + Zstandard | `.tar.zst` | Implemented |
| TAR + LZ4 | `.tar.lz4` | Implemented |
| Gzip | `.gz` | Implemented |
| Bzip2 | `.bz2` | Implemented |
| XZ | `.xz` | Implemented |
| Zstandard | `.zst` | Implemented |
| LZ4 | `.lz4` | Implemented |
| NSIS installers | compatible `.exe` | Implemented |
| RAR | `.rar` | Planned / under investigation |
| Other installer formats | MSI, Inno Setup, etc. | Planned |

**Device testing:** NSIS-compatible EXE extraction has been confirmed working on the developer's device. Other currently implemented formats have not yet been individually verified on a physical device. CI/build checks do not replace device testing.

A file extension alone does not guarantee support. EXE is a generic executable container; only supported NSIS installer files are handled. Unsupported or malformed files should return an error instead of being launched.

## How to use

1. Tap **Choose a file to extract** and pick the file from the iOS Files picker.
2. If choosing a file appears to do nothing, open it in Files, press and hold the file, tap **Share**, and choose **TangiExtract**. If using TangiExtract inside LiveContainer, share the file to LiveContainer first, then select TangiExtract from the LiveContainer app list.
3. When extraction completes, open **My Files** to browse the output.

## Privacy and storage

- Extraction is performed on-device; files are not uploaded to a service.
- The source is accessed directly through iOS file permissions and is not copied into TangiExtract's private storage.
- Finished output is stored under **Files → On My iPhone → TangiExtract → Extracted**.
- Temporary working files are created for each extraction and removed after the operation.

## Downloads

- **[Latest release / IPA](https://github.com/TangiDev69/TangiExtract/releases/latest)** — the latest GitHub release
- **[Build history](https://github.com/TangiDev69/TangiExtract/actions)** — automated builds and CI results

The IPA is unsigned and is intended for compatible sideloading tools such as SideStore, AltStore, and LiveContainer. Installation behavior varies by tool and device.

## Project status and roadmap

The project is actively developed. Current priorities are expanding archive-format coverage (starting with RAR), improving import/share workflows, and adding stronger automated fixtures for format-level regression tests. Additional potential formats include CAB, CPIO, AR, ISO/IMG, and more installer families; these will only be listed as supported after implementation and testing.

## Architecture

- **SwiftUI:** UI, document picker, file browser, settings, and iOS file access.
- **Swift services:** temporary output management and bridge to extraction engines.
- **Rust:** native parsing/extraction libraries.
- **GitHub Actions:** Rust tests, iOS ARM64 compilation, and unsigned IPA packaging.

## Security notes

Extraction is subject to resource limits and path validation. ZIP extraction rejects unsafe paths and symbolic links; TAR extraction rejects unsafe paths, links, and special entries. RAR and additional formats are not supported yet. This project is still evolving and should not be treated as a hardened universal archive-extraction suite. Be cautious with untrusted archives.

## License and third-party notices

See [LICENSE](LICENSE) and [NOTICE](NOTICE). Third-party dependencies retain their respective licenses.
