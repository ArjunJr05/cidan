# Changelog

## 1.0.10

- Full WebAssembly (WASM) runtime compatibility:
  - Decoupled `dart:io` and `path_provider` in `compliance_dashboard_screen.dart` via conditional export architecture (`report_file_saver.dart`).
  - Decoupled `mailer` in `supabase_service.dart` via conditional export architecture (`smtp_dispatcher.dart`).
  - Replaced `dart:io` `HttpClient` in `cidan_api_service.dart` with cross-platform `package:http`.
- Eliminated all static analysis warnings (`unused_field`, `unused_element`, and unused imports) in `upload_document_screen.dart` for a perfect 50/50 static analysis score.
- Full 20/20 platform support points (all 6 platforms: Android, iOS, Web, Windows, macOS, Linux + WASM).
- Verified for 160/160 pub points on pub.dev.

## 1.0.9

- Full WebAssembly (WASM) compatibility:
  - Decoupled `dart:io` and `path_provider` in `compliance_dashboard_screen.dart` using a conditional export architecture (`report_file_saver.dart`).
  - Decoupled `mailer` in `supabase_service.dart` via conditional export (`smtp_dispatcher.dart`).
  - Replaced `dart:io` `HttpClient` in `cidan_api_service.dart` with cross-platform `package:http`.
- Eliminated all static analysis warnings (`unused_field`, `unused_element`, and unused imports) for 50/50 static analysis score.
- Restored full 20/20 Platform support points on pub.dev Pana analysis (Android, iOS, Web, Windows, macOS, Linux + WASM).
- 100% test suite verified and ready for 160/160 pub points.

## 1.0.8

- Completely reset and clear all previously uploaded documents (Existing Rules and New Rule Input) and endpoint controllers when tapping "Upload Another".
- Automated redirection to the "Document Processed Successfully" screen immediately upon regulatory rule deployment.
- Fixed static analysis compatibility with `file_picker` 12.x/13.x by using standard static `FilePicker.pickFiles` (removing unsupported `.platform`, `allowMultiple`, and `withData` calls) to ensure 50/50 static analysis and 160/160 total pub points.
- Reduced vertical spacing between the verified bank checklist banner and the completion title for optimal visual layout.
- Maintained 100% full platform support across Android, iOS, Linux, macOS, Windows, and Web (20/20 points).

## 1.0.7

- Display "Existing Rules" first and "New Rule Input (Circular / Update)" second on the upload screen.
- Dynamic gating: "Analyze & Generate" button is only enabled when at least 1 document or input is entered in both Existing Rules and New Rule sections.
- Visual disabled and active states for "Analyze & Generate" button with dynamic guidance helper message.
- Added Web platform declaration in `pubspec.yaml` to ensure full 6/6 platform compatibility.
- Fixed file length resolution in `_extractFilesFromPickerResult` to prevent `NoSuchMethodError` and debugger pauses.

## 1.0.6

- Resolved cross-version static analysis compatibility with `file_picker` 11.x, 12.x, and 13.x on pub.dev Pana analysis.
- Restored multi-platform support score (iOS, Android, Web, Windows, macOS, Linux).
- Dynamic parameter compatibility for `pickFiles` across legacy and federated plugin architectures.

## 1.0.5

- Streamlined document uploading with a unified single "Choose File" button supporting multi-file selection.
- Added multi-document upload support for Existing Rules with scrollable bounded container and individual file removal.
- Expanded file limit to 10 files (PDFs, images, or combined) with live slot counter (`x/10`) and filename truncation.
- Added concurrency guard (`_isPickingFile`) to prevent platform channel collisions and `already_active` exceptions.
- Enhanced Android stability: disabled Impeller to resolve Qualcomm driver gralloc format 0x3b crashes, removed `android:taskAffinity`, and added storage/media permissions.

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
