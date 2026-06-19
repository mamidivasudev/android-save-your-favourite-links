import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/link_item.dart';
import '../models/category_item.dart';
import '../services/json_storage_service.dart';
import '../services/database_helper.dart';
import '../services/google_drive_service.dart';
import '../utils/globals.dart';

class DuplicateLinkException implements Exception {
  final String message;
  DuplicateLinkException(this.message);
}

class LinkProvider with ChangeNotifier {
  List<LinkItem> _links = [];
  List<CategoryItem> _categories = [];
  final JsonStorageService _storageService = JsonStorageService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final GoogleDriveService _driveService = GoogleDriveService();
  
  bool _hasPendingSync = false;
  bool get hasPendingSync => _hasPendingSync;
  StreamSubscription? _connectivitySubscription;

  bool _isProUser = false;

  bool get isProUser => _isProUser;
  bool get hasBoughtPro => _isProUser;

  List<LinkItem> get links => _links;
  List<CategoryItem> get categories => _categories;

  String? _storageError;
  String? get storageError => _storageError;

  bool _isSetupCompleted = false;
  bool get isSetupCompleted => _isSetupCompleted;

  void clearStorageError() {
    if (_storageError != null) {
      _storageError = null;
      notifyListeners();
    }
  }

  Future<void> _safeSave(Future<void> Function() saveOperation) async {
    try {
      await saveOperation();
      clearStorageError();
    } on FileSystemException catch (e) {
      _storageError = 'Could not save data: ${e.message}';
      notifyListeners();
    }
  }

  bool _showLinkPreviews = false;
  bool get showLinkPreviews => _showLinkPreviews;

  bool _isAppLockEnabled = false;
  bool get isAppLockEnabled => _isAppLockEnabled;

  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

  void setAuthenticating(bool value) {
    if (!value) {
      // Delay turning off the authenticating flag by 2000ms.
      // This is necessary because the Android native biometric prompt
      // triggers an AppLifecycleState.resumed event *after* the dialog 
      // finishes animating out. On some devices, this can take up to 1.5 seconds.
      // If we don't delay enough, the app sees the resume event, thinks we 
      // aren't authenticating, and instantly locks the app again.
      Future.delayed(const Duration(milliseconds: 2000), () {
        _isAuthenticating = false;
        notifyListeners();
      });
    } else {
      _isAuthenticating = true;
      notifyListeners();
    }
  }

  Future<void> toggleLinkPreviews() async {
    _showLinkPreviews = !_showLinkPreviews;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showLinkPreviews', _showLinkPreviews);
    notifyListeners();
  }

  Future<void> toggleAppLock(bool value) async {
    _isAppLockEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAppLockEnabled', _isAppLockEnabled);
    notifyListeners();
  }

  Future<void> unlockPro() async {
    _isProUser = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isProUser', true);
    notifyListeners();
  }



  bool _hasCustomStoragePathSync = false;
  bool get hasCustomStoragePathSync => _hasCustomStoragePathSync;

  bool _isAutoSyncing = false;
  bool get isAutoSyncing => _isAutoSyncing;

  Future<void> _autoSyncToDrive({bool showSuccessMessage = true}) async {
    if (!isProUser) return; // Auto-sync is a Pro feature

    _isAutoSyncing = true;
    notifyListeners();

    // Check if user is already signed in silently
    final account = await _driveService.signInSilently();
    if (account != null) {
      final jsonContent = await getBackupJson();
      _driveService.backupToDrive(jsonContent).then((result) async {
        debugPrint("Auto-sync to Drive result: $result");
        
        _isAutoSyncing = false;
        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        if (result == BackupResult.error) {
          if (!_hasPendingSync) {
            if (scaffoldMessengerKey.currentState != null) {
              scaffoldMessengerKey.currentState!.showSnackBar(
                const SnackBar(duration: const Duration(seconds: 2), content: Text('Offline: Changes saved locally. Sync is pending...')),
              );
            }
            _hasPendingSync = true;
            await prefs.setBool('hasPendingSync', true);
          }
        } else if (result == BackupResult.success) {
          _hasPendingSync = false;
          await prefs.setBool('hasPendingSync', false);
          
          if (showSuccessMessage && scaffoldMessengerKey.currentState != null) {
            scaffoldMessengerKey.currentState!.showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.cloud_done, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Auto-synced to Drive!', style: TextStyle(fontSize: 13, fontFamily: 'Poppins'))),
                ]),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      });
    } else {
      _isAutoSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  LinkProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _showLinkPreviews = prefs.getBool('showLinkPreviews') ?? false;
    _isAppLockEnabled = prefs.getBool('isAppLockEnabled') ?? false;
    _hasPendingSync = prefs.getBool('hasPendingSync') ?? false;
    _isProUser = prefs.getBool('isProUser') ?? false;
    _isSetupCompleted = prefs.getBool('setup_completed') ?? false;

    final customPath = await _storageService.getCustomPath();
    _hasCustomStoragePathSync = customPath != null && customPath.isNotEmpty;

    // Listen to network changes to automatically sync pending changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      bool isOnline = false;
      if (result is List) {
        isOnline = (result as List).any((r) => r != ConnectivityResult.none);
      } else {
        isOnline = result != ConnectivityResult.none;
      }
      
      if (isOnline && _hasPendingSync) {
        debugPrint("Internet restored. Triggering pending sync...");
        _autoSyncToDrive(showSuccessMessage: true);
      }
    });

    // Always initialize — uses app documents dir by default if no custom path set
    await _migrateIfNeeded();
    await fetchCategories();
    await fetchLinks();
  }

  Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('setup_completed') ?? false;
  }

  Future<void> setSetupCompleted(bool value) async {
    _isSetupCompleted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_completed', value);
    notifyListeners();
  }

  Future<bool> hasCustomStoragePath() async {
    final path = await _storageService.getCustomPath();
    return path != null && path.isNotEmpty;
  }

  Future<bool> isDriveSignedIn() async {
    final account = await _driveService.signInSilently();
    return account != null;
  }

  Future<void> setStoragePath(String path) async {
    await _storageService.setCustomPath(path);
    _hasCustomStoragePathSync = path.isNotEmpty;
    await _init();
    notifyListeners();
  }

  Future<bool> isGoogleDriveSignedIn() => _driveService.isSignedIn();
  Future<String?> getGoogleDriveEmail() => _driveService.getSignedInEmail();
  Future<bool> getGoogleDriveAutoSyncEnabled() => _driveService.getAutoSyncEnabled();
  Future<DateTime?> getGoogleDriveLastSync() => _driveService.getLastSync();
  Future<void> setGoogleDriveAutoSyncEnabled(bool enabled) => _driveService.setAutoSyncEnabled(enabled);


  Future<DriveSyncResult> signInToGoogleDrive() async {
    try {
      final account = await _driveService.signIn();
      if (account == null) return const DriveSyncResult(success: false, message: 'Sign in failed');
      return DriveSyncResult(success: true, message: 'Signed in successfully', accountEmail: account.email);
    } catch (e) {
      return DriveSyncResult(success: false, message: 'Sign in error: $e');
    }
  }

  Future<DriveSyncResult> signOutFromGoogleDrive() async {
    await _driveService.signOut();
    return const DriveSyncResult(success: true, message: 'Signed out successfully');
  }

  Future<DriveSyncResult> backupToGoogleDrive() async {
    final jsonContent = await getBackupJson();
    final data = jsonDecode(jsonContent) as Map<String, dynamic>;
    final success = await _driveService.uploadBackup(data);
    return DriveSyncResult(success: success, message: success ? 'Backup successful' : 'Backup failed');
  }

  Future<DriveSyncResult> restoreFromGoogleDrive() async {
    final data = await _driveService.downloadBackup();
    if (data == null) return const DriveSyncResult(success: false, message: 'Restore failed');
    await restoreFromJson(jsonEncode(data));
    return const DriveSyncResult(success: true, message: 'Restore successful');
  }

  Future<DriveSyncResult> syncWithGoogleDrive() async {
    final remoteTime = await _driveService.getRemoteModifiedTime();
    final lastSync = await _driveService.getLastSync();
    if (remoteTime != null && (lastSync == null || remoteTime.isAfter(lastSync))) {
       return restoreFromGoogleDrive();
    } else {
       return backupToGoogleDrive();
    }
  }

  Future<void> _migrateIfNeeded() async {
    String dbPath = p.join(await getDatabasesPath(), 'links_database.db');
    final existingCategories = await _storageService.getCategories();
    bool migratedCategories = false;

    if (await File(dbPath).exists()) {
      final existingLinks = await _storageService.getLinks();
      
      if (existingLinks.isEmpty && existingCategories.isEmpty) {
        final dbLinks = await _dbHelper.getLinks();
        final dbCategories = await _dbHelper.getCategories();
        
        if (dbLinks.isNotEmpty || dbCategories.isNotEmpty) {
          await _safeSave(() => _storageService.saveData(links: dbLinks, categories: dbCategories));
          migratedCategories = dbCategories.isNotEmpty;
        }
      }
    }
    
    // Seed default categories if none exist (neither local JSON nor migrated DB had any)
    if (existingCategories.isEmpty && !migratedCategories) {
      final defaultCategories = [
        CategoryItem(id: 1, name: 'YouTube'),
        CategoryItem(id: 2, name: 'Instagram'),
        CategoryItem(id: 3, name: 'Locations'),
        CategoryItem(id: 4, name: 'Google'),
        CategoryItem(id: 5, name: 'Others'),
      ];
      await _safeSave(() => _storageService.saveCategories(defaultCategories));
    }
  }

  Future<void> fetchLinks() async {
    _links = await _storageService.getLinks();
    notifyListeners();
  }

  Future<void> fetchCategories() async {
    _categories = await _storageService.getCategories();
    notifyListeners();
  }

  Future<void> addLink(String title, String url, {int? categoryId}) async {
    // Check for duplicates
    final cleanUrl = url.trim();
    if (_links.any((l) => l.url.trim() == cleanUrl)) {
      throw DuplicateLinkException('Link already saved!');
    }

    final nextId = _links.isEmpty ? 1 : (_links.map((l) => l.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    final newLink = LinkItem(
      id: nextId,
      title: title,
      url: url,
      createdAt: DateTime.now(),
      categoryId: categoryId ?? getAutoCategoryId(url),
    );
    _links.insert(0, newLink);
    await _safeSave(() => _storageService.saveLinks(_links));
    notifyListeners();
    _autoSyncToDrive();
  }

  Future<void> removeLink(int id) async {
    _links.removeWhere((l) => l.id == id);
    await _safeSave(() => _storageService.saveLinks(_links));
    notifyListeners();
    _autoSyncToDrive();
  }

  Future<void> removeMultipleLinks(List<int> ids) async {
    _links.removeWhere((l) => ids.contains(l.id));
    await _safeSave(() => _storageService.saveLinks(_links));
    notifyListeners();
    _autoSyncToDrive();
  }

  Future<void> updateLink(LinkItem link) async {
    final index = _links.indexWhere((l) => l.id == link.id);
    if (index != -1) {
      _links[index] = link;
      await _safeSave(() => _storageService.saveData(links: _links, categories: _categories));
      notifyListeners();
      _autoSyncToDrive();
    }
  }

  Future<void> togglePin(int id) async {
    final link = _links.firstWhere((l) => l.id == id);
    await updateLink(link.copyWith(isPinned: !link.isPinned));
  }

  Future<void> toggleFavorite(int id) async {
    final link = _links.firstWhere((l) => l.id == id);
    await updateLink(link.copyWith(isFavorite: !link.isFavorite));
  }

  Future<void> toggleLock(int id) async {
    final link = _links.firstWhere((l) => l.id == id);
    await updateLink(link.copyWith(isLocked: !link.isLocked));
  }

  // Categories
  Future<void> addCategory(String name) async {
    final nextId = _categories.isEmpty ? 1 : (_categories.map((c) => c.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    final newCategory = CategoryItem(id: nextId, name: name);
    _categories.add(newCategory);
    await _safeSave(() => _storageService.saveCategories(_categories));
    notifyListeners();
    _autoSyncToDrive();
  }

  Future<void> updateCategory(CategoryItem category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      await _safeSave(() => _storageService.saveCategories(_categories));
      notifyListeners();
      _autoSyncToDrive();
    }
  }


  /// Returns the number of links that belong to any of the given category [ids].
  int getLinkCountForCategories(Iterable<int> ids) {
    return _links.where((l) => l.categoryId != null && ids.contains(l.categoryId)).length;
  }

  /// Returns the id of the "Others" category, or null if it doesn't exist.
  int? _getOthersCategoryId() {
    try {
      return _categories
          .firstWhere((c) => c.name.toLowerCase() == 'others')
          .id;
    } catch (_) {
      return _categories.isNotEmpty ? _categories.last.id : null;
    }
  }

  Future<void> removeCategory(int id) async {
    _categories.removeWhere((c) => c.id == id);

    // Reassign links that belonged to the deleted category to "Others"
    // instead of deleting them — prevents silent data loss.
    final fallbackId = _getOthersCategoryId();
    _links = _links.map((link) {
      if (link.categoryId == id) {
        return link.copyWith(categoryId: fallbackId);
      }
      return link;
    }).toList();

    await _safeSave(() => _storageService.saveData(links: _links, categories: _categories));
    notifyListeners();
    _autoSyncToDrive();
  }

  Future<void> removeMultipleCategories(List<int> ids) async {
    _categories.removeWhere((c) => ids.contains(c.id));

    // Reassign links in deleted categories to "Others" instead of deleting them.
    final fallbackId = _getOthersCategoryId();
    _links = _links.map((link) {
      if (link.categoryId != null && ids.contains(link.categoryId)) {
        return link.copyWith(categoryId: fallbackId);
      }
      return link;
    }).toList();

    await _safeSave(() => _storageService.saveData(links: _links, categories: _categories));
    notifyListeners();
    _autoSyncToDrive();
  }

  int? getAutoCategoryId(String url) {
    final lowerUrl = url.toLowerCase();
    String categoryName = 'Others';
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) categoryName = 'YouTube';
    else if (lowerUrl.contains('instagram.com')) categoryName = 'Instagram';
    else if (lowerUrl.contains('maps.google') || lowerUrl.contains('goo.gl/maps') || lowerUrl.contains('maps.app.goo.gl')) categoryName = 'Locations';
    else if (lowerUrl.contains('google.com')) categoryName = 'Google';

    final category = _categories.firstWhere(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => _categories.firstWhere((c) => c.name == 'Others', orElse: () => _categories.isNotEmpty ? _categories.first : CategoryItem(id: 0, name: 'Others')),
    );
    return category.id;
  }

  // ─── Google Drive Backup / Restore ──────────────────────────────────────────

  /// Returns current data as a JSON string for Drive backup
  Future<String> getBackupJson() async {
    final data = {
      'categories': _categories.map((c) => c.toMap()).toList(),
      'links': _links.map((l) => l.toMap()).toList(),
    };
    return jsonEncode(data);
  }

  /// Restores data from a JSON string (from Drive) and saves locally
  Future<void> restoreFromJson(String json) async {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      if (data.containsKey('categories') && data.containsKey('links')) {
        final categoriesData = data['categories'] as List;
        final linksData = data['links'] as List;

        _categories = categoriesData
            .map((c) => CategoryItem.fromMap(c as Map<String, dynamic>))
            .toList();
        _links = linksData
            .map((l) => LinkItem.fromMap(l as Map<String, dynamic>))
            .toList();

        await _safeSave(() => _storageService.saveData(links: _links, categories: _categories));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Restore from JSON error: $e');
    }
  }
}
