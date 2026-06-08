import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/link_item.dart';
import '../models/category_item.dart';
import '../services/database_helper.dart';

class DataService {
  static Future<void> exportData(List<CategoryItem> categories, List<LinkItem> links) async {
    final data = {
      'categories': categories.map((c) => c.toMap()).toList(),
      'links': links.map((l) => l.toMap()).toList(),
    };

    final jsonString = jsonEncode(data);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/links_backup.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles([XFile(file.path)], text: 'Links Saver Backup');
  }

  static Future<bool> importData(dynamic provider) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return false;

    try {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(content);

      if (!data.containsKey('categories') || !data.containsKey('links')) {
        return false;
      }

      // We pass the raw JSON content to the provider's restore function
      // But we want to *merge* it instead of overwriting like Google Drive does.
      
      final importedCategories = (data['categories'] as List)
          .map((c) => CategoryItem.fromMap(Map<String, dynamic>.from(c)))
          .toList();
          
      final importedLinks = (data['links'] as List)
          .map((l) => LinkItem.fromMap(Map<String, dynamic>.from(l)))
          .toList();

      // Step 1: Import Categories
      for (var cat in importedCategories) {
        if (!provider.categories.any((existing) => existing.name.toLowerCase().trim() == cat.name.toLowerCase().trim())) {
          await provider.addCategory(cat.name);
        }
      }

      // Map imported category ID to new category ID
      final categoryNameToNewId = <String, int>{};
      for (final cat in provider.categories) {
        categoryNameToNewId[cat.name.toLowerCase().trim()] = cat.id!;
      }

      // Step 2: Import Links
      final existingUrls = provider.links.map((l) => l.url.toLowerCase().trim()).toSet();
      
      for (var link in importedLinks) {
        final urlKey = link.url.toLowerCase().trim();
        
        // Skip if already exists
        if (existingUrls.contains(urlKey)) continue;

        // Find new category ID
        int? newCategoryId;
        if (link.categoryId != null) {
          final oldCat = importedCategories.firstWhere(
            (c) => c.id == link.categoryId,
            orElse: () => CategoryItem(id: 0, name: ''),
          );
          if (oldCat.name.isNotEmpty) {
            newCategoryId = categoryNameToNewId[oldCat.name.toLowerCase().trim()];
          }
        }

        // We bypass the provider's `addLink` temporarily to avoid throwing exceptions 
        // and we pass the category ID.
        try {
          await provider.addLink(link.title, link.url, categoryId: newCategoryId);
          existingUrls.add(urlKey);
        } catch (e) {
          continue;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
