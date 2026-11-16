import 'package:shared_preferences/shared_preferences.dart';

/// Web/WASM implementation for locally saving report data.
Future<String?> saveReportFileLocally({
  required String fileName,
  required String workflowId,
  required String content,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
  final filePrefix =
      workflowId.length >= 8 ? workflowId.substring(0, 8) : workflowId;
  final displayPath = 'downloads/CIDAN_Report_${filePrefix}_$safeName.txt';

  final prefs = await SharedPreferences.getInstance();
  final downloadedList = prefs.getStringList('cidan_local_downloads') ?? [];
  if (!downloadedList.contains(displayPath)) {
    downloadedList.insert(0, displayPath);
    await prefs.setStringList('cidan_local_downloads', downloadedList);
  }

  return displayPath;
}
