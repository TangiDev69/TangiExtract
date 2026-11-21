# TangiExtract

**Everything inside. Nothing left behind.**

TangiExtract is a standalone iOS file inspection and extraction application for archives, Windows installers, and game data.

## Current development status

- [x] Independent iOS application and Rust extraction core
- [x] Native NSIS Windows installer extraction
- [x] SwiftUI application shell and document-picker integration
- [x] iOS ARM64 GitHub Actions build pipeline
- [x] Automated NSIS fixture regression test
- [ ] Harden the NSIS engine for general-purpose extraction (streaming, configurable limits, cancellation, and collision policy)
- [ ] Add ZIP, 7Z, RAR, TAR, GZ, BZ2, and XZ archive support
- [ ] Add file identification by signatures rather than extensions alone
- [ ] Add archive inspection, history, batch jobs, and storage management
- [ ] Add share-sheet import support
- [ ] Add further installer formats, including Inno Setup and MSI

**Format support:** A recognized file type is not necessarily an extractable file type. TangiExtract will report unsupported formats rather than claim universal executable or proprietary-format support. Windows installers are parsed as data; TangiExtract does not execute Windows programs.

## Latest development build

An unsigned iOS ARM64 development IPA has been built and published successfully. The current implementation supports NSIS Windows installers only.

- [Download the latest TangiExtract IPA](https://github.com/TangiDev69/TangiExtract/releases/latest)
- [View GitHub Actions builds](https://github.com/TangiDev69/TangiExtract/actions)

The IPA has passed automated Rust tests, an NSIS extraction regression test, iOS ARM64 compilation, Xcode build, and IPA packaging checks. Physical-device installation and runtime behavior still require testing.

## Architecture

- **SwiftUI:** iOS application and user interface.
- **Swift services:** document importing, storage coordination, and native-engine integration.
- **Rust:** format-specific extraction engines and parsers.
- **GitHub Actions:** reproducible unsigned iOS ARM64 IPA builds.

## Build

GitHub Actions builds the iOS app on macOS. The workflow tests the Rust crate, compiles the Rust static library for `aarch64-apple-ios`, generates the Xcode project with XcodeGen, builds the app without code signing, and packages an IPA.

Unsigned IPA output is intended for compatible sideloading workflows. It is not an App Store-signed application. Import the IPA into a compatible signing/sideloading tool before installation if your chosen tool requires a signed package.

## Security and current limitations

The initial NSIS implementation retains its upstream parser's existing memory use and file filtering behavior. It includes basic input/output, entry-count, path, and duplicate checks, but it is **not yet the final general-purpose security model**. Do not treat this early development build as a hardened arbitrary-file extraction utility.

## License

See [NOTICE](NOTICE) and [LICENSE](LICENSE) for attribution and licensing information. Third-party dependencies retain their respective licenses.
