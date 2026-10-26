# Changelog

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
