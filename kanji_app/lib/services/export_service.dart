import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'database_service.dart';
import 'settings_service.dart';

Future<Directory> _exportDirectory() async {
  if (Platform.isAndroid) {
    final ext = await getExternalStorageDirectory();
    if (ext != null) return ext;
  }
  if (Platform.isIOS || Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    final dl = await getDownloadsDirectory();
    if (dl != null) return dl;
  }
  return getApplicationDocumentsDirectory();
}

class ExportService {
  /// Exports all user data to Documents.
  /// [filename] defaults to 'kanji_userdata.json'; pass a custom name for backups.
  Future<String?> exportProgress(AppSettings settings, {String? filename}) async {
    final kanjiProgress = await dbService.query('SELECT * FROM user_progress');
    final vocabTargets = await dbService.query('SELECT * FROM vocabulary_targets');
    final vocabProgress = await dbService.query('SELECT * FROM vocabulary_progress');

    final payload = jsonEncode({
      'version': 2,
      'exported_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'settings': settings.toJson(),
      'kanji_progress': kanjiProgress,
      'vocab_targets': vocabTargets,
      'vocab_progress': vocabProgress,
    });

    final dir = await _exportDirectory();
    final name = filename ?? 'kanji_userdata.json';
    final file = File(join(dir.path, name));
    await file.writeAsString(payload);
    return file.path;
  }

  /// Opens a file picker, shows a confirmation dialog, then overwrites all
  /// user data with the imported file. Returns true on success.
  Future<bool> importProgress(
    BuildContext context,
    AppSettings currentSettings,
    Function(AppSettings) onSettingsUpdate,
  ) async {
    // 1. Pick file
    const typeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return false; // user cancelled

    // 2. Confirm overwrite
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Import user data?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will overwrite all current progress and cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    // 3. Parse
    final content = await file.readAsString();
    final Map<String, dynamic> payload = jsonDecode(content);
    final version = payload['version'] as int? ?? 1;
    if (version > 2) throw Exception('Unsupported file version: $version');

    // 4. Extract data (v1 compat: 'progress' key for kanji, no vocab keys)
    final List<Map<String, dynamic>> kanjiProgress = version == 1
        ? ((payload['progress'] as List?)?.cast<Map<String, dynamic>>() ?? [])
        : ((payload['kanji_progress'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    final List<Map<String, dynamic>> vocabTargets =
        (payload['vocab_targets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final List<Map<String, dynamic>> vocabProgress =
        (payload['vocab_progress'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // 5. Overwrite DB
    await dbService.execute('DELETE FROM user_progress');
    await dbService.execute('DELETE FROM vocabulary_targets');
    await dbService.execute('DELETE FROM vocabulary_progress');

    for (final row in kanjiProgress) {
      await dbService.execute('''
        INSERT INTO user_progress (kanji_id, status, consecutive_correct, total_seen, total_correct)
        VALUES (?, ?, ?, ?, ?)
      ''', [
        row['kanji_id'],
        row['status'] ?? 'unlearned',
        row['consecutive_correct'] ?? 0,
        row['total_seen'] ?? 0,
        row['total_correct'] ?? 0,
      ]);
    }

    for (final row in vocabTargets) {
      await dbService.execute(
        'INSERT INTO vocabulary_targets (vocab_id, added_at) VALUES (?, ?)',
        [row['vocab_id'], row['added_at'] ?? 0],
      );
    }

    for (final row in vocabProgress) {
      await dbService.execute('''
        INSERT INTO vocabulary_progress (vocab_id, word_to_meaning, meaning_to_word, learned_at)
        VALUES (?, ?, ?, ?)
      ''', [
        row['vocab_id'],
        row['word_to_meaning'] ?? 0,
        row['meaning_to_word'] ?? 0,
        row['learned_at'],
      ]);
    }

    // 6. Update settings
    if (payload['settings'] != null) {
      final newSettings = AppSettings.fromJson(
          payload['settings'] as Map<String, dynamic>);
      onSettingsUpdate(newSettings);
    }

    return true;
  }
}

final exportService = ExportService();
