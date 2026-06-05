import 'dart:convert';
import 'dart:io';
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
    
    if (path == null) {
      final directory = await getApplicationDocumentsDirectory();
      path = directory.path;
    }
    
    return File('$path/$_fileName');
  }

  Future<Map<String, dynamic>> _readData() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return {'categories': [], 'links': []};
      }
      final contents = await file.readAsString();
      return jsonDecode(contents);
    } catch (e) {
      return {'categories': [], 'links': []};
    }
  }

  Future<void> _writeData(Map<String, dynamic> data) async {
    final file = await _localFile;
    await file.writeAsString(jsonEncode(data));
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
