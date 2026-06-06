import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/google_drive_config.dart';

enum DriveSyncAction { uploaded, downloaded, merged, noChanges }

enum BackupResult { success, notSignedIn, error }
enum RestoreStatus { success, notSignedIn, noBackupFound, error }

class RestoreResult {
  final RestoreStatus status;
  final String? content;
  RestoreResult(this.status, [this.content]);
}

class DriveSyncResult {
  final bool success;
  final DriveSyncAction? action;
  final String? message;
  final String? accountEmail;

  const DriveSyncResult({
    required this.success,
    this.action,
    this.message,
    this.accountEmail,
  });
}

class GoogleDriveService {
  static const String backupFileName = 'links_data.json';
  static const String _lastSyncKey = 'google_drive_last_sync';
  static const String _autoSyncKey = 'google_drive_auto_sync';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
    serverClientId: googleDriveWebClientId,
  );

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.signOut();

  Future<bool> isSignedIn() => _googleSignIn.isSignedIn();

  Future<GoogleSignInAccount?> get currentUser async {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    return await _googleSignIn.signInSilently();
  }

  Future<BackupResult> backupToDrive(String jsonContent) async {
    try {
      final account = await currentUser;
      if (account == null) return BackupResult.notSignedIn;

      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final success = await uploadBackup(data);
      return success ? BackupResult.success : BackupResult.error;
    } catch (e) {
      return BackupResult.error;
    }
  }

  Future<RestoreResult> restoreFromDrive() async {
    try {
      final account = await currentUser;
      if (account == null) return RestoreResult(RestoreStatus.notSignedIn);

      final api = await _getDriveApi();
      if (api == null) return RestoreResult(RestoreStatus.error);

      final file = await _findBackupFile(api);
      if (file == null) return RestoreResult(RestoreStatus.noBackupFound);

      final data = await downloadBackup();
      if (data == null) return RestoreResult(RestoreStatus.error);

      return RestoreResult(RestoreStatus.success, jsonEncode(data));
    } catch (e) {
      return RestoreResult(RestoreStatus.error);
    }
  }

  Future<String?> getSignedInEmail() async {
    final account = await currentUser;
    return account?.email;
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = await currentUser;
    if (account == null) return null;

    final client = await _googleSignIn.authenticatedClient();
    return client == null ? null : drive.DriveApi(client);
  }

  Future<drive.File?> _findBackupFile(drive.DriveApi api) async {
    final response = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$backupFileName'",
      $fields: 'files(id,name,modifiedTime,size)',
    );

    final files = response.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }

  Future<DateTime?> getRemoteModifiedTime() async {
    final api = await _getDriveApi();
    if (api == null) return null;

    final file = await _findBackupFile(api);
    return file?.modifiedTime;
  }

  Future<Map<String, dynamic>?> downloadBackup() async {
    final api = await _getDriveApi();
    if (api == null) return null;

    final file = await _findBackupFile(api);
    if (file?.id == null) return null;

    final media = await api.files.get(
      file!.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await media.stream.toList();
    final flatBytes = bytes.expand((chunk) => chunk).toList();
    return jsonDecode(utf8.decode(flatBytes)) as Map<String, dynamic>;
  }

  Future<bool> uploadBackup(Map<String, dynamic> data) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    final jsonContent = jsonEncode(data);
    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    final existing = await _findBackupFile(api);
    if (existing?.id != null) {
      await api.files.update(
        drive.File(),
        existing!.id!,
        uploadMedia: media,
      );
    } else {
      await api.files.create(
        drive.File()
          ..name = backupFileName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }

    await setLastSync(DateTime.now());
    return true;
  }

  Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastSyncKey);
    return value == null ? null : DateTime.parse(value);
  }

  Future<void> setLastSync(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
  }

  Future<bool> getAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? false;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }
}
