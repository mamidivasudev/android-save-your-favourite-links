import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/link_item.dart';
import '../models/category_item.dart';
import '../services/json_storage_service.dart';
import '../services/database_helper.dart';

class LinkProvider with ChangeNotifier {
  List<LinkItem> _links = [];
  List<CategoryItem> _categories = [];
  final JsonStorageService _storageService = JsonStorageService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<LinkItem> get links => _links;
  List<CategoryItem> get categories => _categories;

  LinkProvider() {
    _init();
  }

  Future<void> _init() async {
    final path = await _storageService.getCustomPath();
    if (path != null) {
      await _migrateIfNeeded();
      await fetchCategories();
      await fetchLinks();
    }
  }

  Future<bool> hasStoragePath() async {
    final path = await _storageService.getCustomPath();
    return path != null;
  }

  Future<void> setStoragePath(String path) async {
    await _storageService.setCustomPath(path);
    await _init();
    notifyListeners();
  }

  Future<void> _migrateIfNeeded() async {
    String dbPath = p.join(await getDatabasesPath(), 'links_database.db');
    if (await File(dbPath).exists()) {
      final existingLinks = await _storageService.getLinks();
      final existingCategories = await _storageService.getCategories();
      
      if (existingLinks.isEmpty && existingCategories.isEmpty) {
        final dbLinks = await _dbHelper.getLinks();
        final dbCategories = await _dbHelper.getCategories();
        
        if (dbLinks.isNotEmpty || dbCategories.isNotEmpty) {
          await _storageService.saveData(links: dbLinks, categories: dbCategories);
        }
      }
    } else {
      final existingCategories = await _storageService.getCategories();
      if (existingCategories.isEmpty) {
        final defaultCategories = [
          CategoryItem(id: 1, name: 'YouTube'),
          CategoryItem(id: 2, name: 'Instagram'),
          CategoryItem(id: 3, name: 'Locations'),
          CategoryItem(id: 4, name: 'Google'),
          CategoryItem(id: 5, name: 'Others'),
        ];
        await _storageService.saveCategories(defaultCategories);
      }
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
    final nextId = _links.isEmpty ? 1 : (_links.map((l) => l.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    final newLink = LinkItem(
      id: nextId,
      title: title,
      url: url,
      createdAt: DateTime.now(),
      categoryId: categoryId ?? getAutoCategoryId(url),
    );
    _links.insert(0, newLink);
    await _storageService.saveLinks(_links);
    notifyListeners();
  }

  Future<void> removeLink(int id) async {
    _links.removeWhere((l) => l.id == id);
    await _storageService.saveLinks(_links);
    notifyListeners();
  }

  Future<void> removeMultipleLinks(List<int> ids) async {
    _links.removeWhere((l) => ids.contains(l.id));
    await _storageService.saveLinks(_links);
    notifyListeners();
  }

  Future<void> updateLink(LinkItem link) async {
    final index = _links.indexWhere((l) => l.id == link.id);
    if (index != -1) {
      _links[index] = link;
      await _storageService.saveLinks(_links);
      notifyListeners();
    }
  }

  // Categories
  Future<void> addCategory(String name) async {
    final nextId = _categories.isEmpty ? 1 : (_categories.map((c) => c.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    final newCategory = CategoryItem(id: nextId, name: name);
    _categories.add(newCategory);
    await _storageService.saveCategories(_categories);
    notifyListeners();
  }

  Future<void> updateCategory(CategoryItem category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      await _storageService.saveCategories(_categories);
      notifyListeners();
    }
  }

  Future<void> removeCategory(int id) async {
    _categories.removeWhere((c) => c.id == id);
    _links = _links.map((link) {
      if (link.categoryId == id) {
        return link.copyWith(categoryId: null);
      }
      return link;
    }).toList();
    
    await _storageService.saveData(links: _links, categories: _categories);
    notifyListeners();
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
}
