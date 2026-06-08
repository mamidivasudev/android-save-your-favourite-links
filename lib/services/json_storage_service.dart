import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/link_item.dart';
import '../models/category_item.dart';

class JsonStorageService {
  static const String _fileName = 'links_data.json';
  static const String _storageKey = 'custom_storage_path';

  Future<String?> getCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey);
  }

  Future<void> setCustomPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, path);
  }

  Future<File> get _localFile async {
    final prefs = await SharedPreferences.getInstance();
    String? path = prefs.getString(_storageKey);
    
    if (path == null || path.isEmpty) {
      final directory = await getApplicationDocumentsDirectory();
      path = directory.path;
    }
    
    return File('$path/$_fileName');
  }

  Future<Map<String, dynamic>> _readData() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return {'version': 1, 'categories': [], 'links': []};
      }
      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;

      // Handle old backups without version field
      if (!data.containsKey('version')) {
        data['version'] = 1; // treat as version 1
      }

      return data;
    } catch (e) {
      return {'version': 1, 'categories': [], 'links': []};
    }
  }

  Future<void> _writeData(Map<String, dynamic> data) async {
    try {
      final file = await _localFile;
      final tempFile = File('${file.path}.tmp');
      
      final dataWithVersion = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'categories': data['categories'] ?? [],
        'links': data['links'] ?? [],
      };

      // Atomic write: write to temp file first, then rename to original file
      await tempFile.writeAsString(jsonEncode(dataWithVersion));
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint('Storage write error: $e');
      // If we fail to write, it could be a revoked permission.
      // Do NOT silently delete the custom path and fallback, as that causes data fragmentation.
      // Instead, we just throw the error so the UI can show a warning, 
      // but if they've never set up a path, we use the fallback.
      
      final prefs = await SharedPreferences.getInstance();
      final hasCustomPath = prefs.getString(_storageKey) != null;
      
      if (!hasCustomPath) {
        // Safe to fallback since they never chose a custom path anyway
        final directory = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${directory.path}/$_fileName');
        final tempFallbackFile = File('${fallbackFile.path}.tmp');
        await tempFallbackFile.writeAsString(jsonEncode(data));
        await tempFallbackFile.rename(fallbackFile.path);
      } else {
        // They chose a path but we lost access. We shouldn't overwrite their setting.
        debugPrint('CRITICAL: Lost write access to custom folder!');
        throw FileSystemException(
          'Lost write access to custom storage folder. Please check folder permissions in Settings.'
        );
      }
    }
  }

  // Links CRUD
  Future<List<LinkItem>> getLinks() async {
    final data = await _readData();
    final List linksData = data['links'] ?? [];
    return linksData.map((l) => LinkItem.fromMap(l)).toList();
  }

  Future<void> saveLinks(List<LinkItem> links) async {
    final data = await _readData();
    data['links'] = links.map((l) => l.toMap()).toList();
    await _writeData(data);
  }

  // Categories CRUD
  Future<List<CategoryItem>> getCategories() async {
    final data = await _readData();
    final List categoriesData = data['categories'] ?? [];
    return categoriesData.map((c) => CategoryItem.fromMap(c)).toList();
  }

  Future<void> saveCategories(List<CategoryItem> categories) async {
    final data = await _readData();
    data['categories'] = categories.map((c) => c.toMap()).toList();
    await _writeData(data);
  }

  // Unified Save
  Future<void> saveData({List<LinkItem>? links, List<CategoryItem>? categories}) async {
    final data = await _readData();
    if (links != null) {
      data['links'] = links.map((l) => l.toMap()).toList();
    }
    if (categories != null) {
      data['categories'] = categories.map((c) => c.toMap()).toList();
    }
    await _writeData(data);
  }
}
