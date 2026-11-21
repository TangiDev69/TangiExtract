# TangiExtract

**Everything inside. Nothing left behind.**

TangiExtract is a lightweight, on-device iOS extractor and file browser for supported installers, archives, and game data.

## Current development status

- [x] Native extraction of ZIP archives with traversal, symlink, and expansion-limit checks
- [x] Native extraction of TAR and TAR.GZ archives with path and entry-type checks
- [x] Native 7Z extraction with path and output-size checks
- [x] Standalone GZ, BZ2, and XZ stream decompression with output-size limits
- [x] Native extraction of supported NSIS-based Windows `.exe` installers
- [x] Direct extraction from the selected source URL without keeping a duplicate copy
- [x] Temporary job directories with cleanup after extraction
- [x] Pastel SwiftUI home screen, My Files browser, and Settings
- [x] Search, sort, Quick Look preview, share, rename, and delete for extracted files
- [x] Appearance preference and post-extraction navigation setting
- [x] Generated app icon and iOS ARM64 GitHub Actions build
- [x] Automated NSIS extraction regression test
- [ ] RAR support (pending a safe iOS-compatible integration)
- [ ] File signature detection and archive preview
- [ ] Batch extraction, persistent extraction history, progress, and cancellation
- [ ] Additional installer formats, including Inno Setup and MSI

**Format support:** A recognized file type is not necessarily an extractable file type. Unsupported formats are reported instead of being treated as extractable. Windows installers are parsed as data; TangiExtract never executes Windows programs.

## Storage behavior

The selected source file is read directly from its original location using iOS file access permissions. TangiExtract does **not** copy it into its own storage or retain a second copy.

Completed output is saved in:

`Files → On My iPhone → TangiExtract → Extracted`

A short-lived working directory is created in the app's temporary cache area while extraction runs and is removed when the job finishes. It is not exposed in the Files app. The original source remains untouched.

## Latest development build

- [Download the latest unsigned development IPA](https://github.com/TangiDev69/TangiExtract/releases/latest)
- [View GitHub Actions builds](https://github.com/TangiDev69/TangiExtract/actions)

**Current compatibility:** `.zip`, `.7z`, `.tar`, `.tar.gz` / `.tgz`, `.gz`, `.bz2`, and `.xz` archives and selected Windows `.exe` files that are valid NSIS installers. `.exe` is a generic executable container, not a single archive format; only NSIS-compatible installers are supported at present. RAR archives, ordinary applications, Inno Setup installers, MSI packages, and arbitrary EXE files are not currently supported. TangiExtract parses supported installers as data and never launches them. Physical-device installation and runtime testing are separate from CI build checks.

## Architecture

- **SwiftUI:** user interface, file browser, document access, and settings.
- **Swift services:** secure-scoped source access, temporary storage, and native-engine integration.
- **Rust:** format-specific extraction engines and parsers.
- **GitHub Actions:** automated Rust tests, iOS ARM64 compilation, unsigned IPA packaging.

## Build

GitHub Actions builds the app on macOS. The workflow tests the Rust crate, builds a generated NSIS fixture, compiles the Rust static library for `aarch64-apple-ios`, generates the app icon, creates the Xcode project with XcodeGen, builds without code signing, and packages an IPA.

Unsigned IPA output is intended for compatible sideloading workflows. It is not an App Store-signed application.

## Security and limitations

The NSIS parser reads installer data into memory. ZIP extraction rejects unsafe paths and symbolic links and enforces per-entry and total expansion limits. TAR extraction rejects unsafe paths and links or special entries. These engines are still evolving and are not a hardened universal extraction suite. Large or unusual installers may exceed device memory limits.

## License

See [NOTICE](NOTICE) and [LICENSE](LICENSE) for attribution and licensing information. Third-party dependencies retain their respective licenses.
