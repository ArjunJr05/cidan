# Changelog

## 1.0.4

- Added `package: 'cidan'` and fallback `errorBuilder` to all `Image.asset` calls to ensure self-contained asset resolution in consumer projects.
- Added `package: 'cidan'` to `VideoPlayerController.asset` video loading.
- Updated font family references to `packages/cidan/Poppins` for seamless Poppins font loading without host app asset configuration.

## 1.0.3

- Resolved `PlatformFile.size` static analysis error for full compatibility with `file_picker` 12.x/13.x and 11.x.
- Enabled cross-platform file metadata inspection using safe length retrieval (`lengthSync()`, `length()`, and `size`).
- Re-confirmed multi-platform static analysis and score criteria.

## 1.0.2

- Resolved static analysis error in `upload_document_screen.dart` with dual-mode `List<PlatformFile>` (v12/v13) and `FilePickerResult` (v11) extraction.
- Restored multi-platform compatibility across iOS, Android, Web, Windows, macOS, and Linux.

## 1.0.1

- Expanded dependency constraints to support `cupertino_icons` 2.x and `file_picker` 12.x/13.x.
- Documented 100% of public library symbols and model classes.
- Fixed static analysis lints and eliminated all unused/unnecessary imports.
- Switched to forward-compatible `FilePicker.platform.pickFiles`.

## 1.0.0

- Initial release of **CIDAN** (Compliance Ingestion, Delta Analysis & Notification) Regulatory AI package.
- Added `cidan.application()` and `Cidan.application()` single-line application initialization methods.
- Automated regulatory circular ingestion, OCR parsing, and extraction of compliance obligations.
- Executive summary metrics, compliance gaps, rule delta proposals, and backtesting testcases.
- Regulatory audit report viewer with device local storage export (.txt download).
- Integrated Supabase user history tracking and live OTP email verification.
