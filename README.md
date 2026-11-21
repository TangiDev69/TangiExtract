# TangiExtract

**Everything inside. Nothing left behind.**

TangiExtract is a standalone iOS file inspection and extraction application, designed for game files, archives, and Windows installers.

The project is being built incrementally. Its first native extraction backend is based on the working NSIS extractor from [TangiDev69/Assaultcube-iOS-port](https://github.com/TangiDev69/Assaultcube-iOS-port), specifically the implementation introduced and refined around commits `dc9779c`, `00367a3`, and `6e3c1fb`.

## Current development status

- [x] Independent repository and application scaffold
- [x] Rust NSIS extraction code migrated as the initial compatibility baseline
- [x] SwiftUI application shell and document-picker integration
- [x] iOS ARM64 GitHub Actions build pipeline
- [x] Add a CI regression step for the historical AssaultCube 1.3.0.2 installer (execution pending)
- [ ] Harden the NSIS engine for general-purpose extraction (streaming, configurable limits, cancellation, and collision policy)
- [ ] Add ZIP/TAR and broader archive support
- [ ] Add format identification by file signatures
- [ ] Add archive inspection, history, batch jobs, and storage management
- [ ] Add share-sheet import extension

**Important:** A recognized file type is not necessarily an extractable file type. TangiExtract will report unsupported formats rather than claim universal executable or proprietary-format support.

## Architecture

- **SwiftUI:** iOS application and user interface.
- **Swift services:** document importing, storage coordination, and native-engine integration.
- **Rust:** format-specific extraction engines and parsers.
- **GitHub Actions:** reproducible unsigned iOS ARM64 IPA builds.

The Rust crate is independent of the AssaultCube game engine. No AssaultCube engine code or game assets are included.

## Build

The iOS app is built by GitHub Actions on macOS. The workflow compiles the Rust static library for `aarch64-apple-ios`, generates the Xcode project with XcodeGen, builds the app without code signing, and packages an IPA.

Unsigned IPA output is intended for compatible sideloading workflows. It is not an App Store-signed application.

## Security

The initial NSIS implementation retains the source extractor's original limits and filtering behavior as a compatibility baseline. It is **not yet the final general-purpose security model**. Do not treat this initial development build as a hardened arbitrary-file extraction utility.

## License

The migrated NSIS implementation retains its upstream licensing and attribution. See [NOTICE](NOTICE) and [LICENSE](LICENSE) before redistribution. Other dependencies retain their respective licenses.
