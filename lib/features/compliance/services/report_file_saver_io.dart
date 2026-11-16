import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// IO implementation for saving report file to disk on Android/iOS/Desktop.
Future<String?> saveReportFileLocally({
  required String fileName,
  required String workflowId,
  required String content,
}) async {
  Directory? baseDir;
  try {
    baseDir = await getDownloadsDirectory();
  } catch (_) {}
  baseDir ??= await getApplicationDocumentsDirectory();

  final safeName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
  final filePrefix =
      workflowId.length >= 8 ? workflowId.substring(0, 8) : workflowId;
  final file = File(
    '${baseDir.path}/CIDAN_Report_${filePrefix}_$safeName.txt',
  );

  await file.writeAsString(content);

  final prefs = await SharedPreferences.getInstance();
  final downloadedList = prefs.getStringList('cidan_local_downloads') ?? [];
  if (!downloadedList.contains(file.path)) {
    downloadedList.insert(0, file.path);
    await prefs.setStringList('cidan_local_downloads', downloadedList);
  }

  return file.path;
}
