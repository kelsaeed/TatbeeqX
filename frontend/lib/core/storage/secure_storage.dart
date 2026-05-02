import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class TokenStorage {
  TokenStorage._(this._file, this._access, this._refresh, this._extras);

  final File? _file;
  String? _access;
  String? _refresh;
  final Map<String, dynamic> _extras;

  static Future<TokenStorage> open() async {
    File? file;
    String? a;
    String? r;
    final extras = <String, dynamic>{};
    try {
      final dir = await _resolveDir();
      file = File('${dir.path}${Platform.pathSeparator}auth.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.isNotEmpty) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          a = data['accessToken'] as String?;
          r = data['refreshToken'] as String?;
          for (final entry in data.entries) {
            if (entry.key == 'accessToken' || entry.key == 'refreshToken') continue;
            extras[entry.key] = entry.value;
          }
        }
      }
    } catch (_) {
      file = null;
    }
    return TokenStorage._(file, a, r, extras);
  }

  static Future<Directory> _resolveDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final root = await getApplicationSupportDirectory();
      final dir = Directory('${root.path}${Platform.pathSeparator}TatbeeqX');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    String base;
    if (Platform.isWindows) {
      base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    } else if (Platform.isMacOS || Platform.isLinux) {
      base = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    } else {
      base = Directory.systemTemp.path;
    }
    final dir = Directory('$base${Platform.pathSeparator}TatbeeqX');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String? get accessToken => _access;
  String? get refreshToken => _refresh;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _access = accessToken;
    _refresh = refreshToken;
    await _persist();
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    final f = _file;
    if (f != null && await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// Read a free-form preference value. Returns null if absent.
  Future<dynamic> readKey(String key) async {
    return _extras[key];
  }

  /// Write a free-form preference value. Persists to disk on the same file
  /// as the auth tokens (a single JSON blob keeps the file count low).
  Future<void> writeKey(String key, dynamic value) async {
    if (value == null) {
      _extras.remove(key);
    } else {
      _extras[key] = value;
    }
    await _persist();
  }

  Future<void> _persist() async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString(
        jsonEncode({
          'accessToken': _access,
          'refreshToken': _refresh,
          ..._extras,
        }),
        flush: true,
      );
    } catch (_) {}
  }
}
