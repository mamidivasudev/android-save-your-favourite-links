import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/link_item.dart';
import '../models/category_item.dart';
import '../services/database_helper.dart';

class DataService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();

  static Future<void> exportData() async {
    final links = await _dbHelper.getLinks();
    final categories = await _dbHelper.getCategories();

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

  static Future<bool> importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(content);

      if (data.containsKey('categories') && data.containsKey('links')) {
        // Import Categories
        final categoriesData = data['categories'] as List;
        for (var catMap in categoriesData) {
          final category = CategoryItem.fromMap(catMap);
          // Try to insert, ignore if exists (unique name)
          try {
            await _dbHelper.insertCategory(category);
          } catch (e) {
            // Already exists or other error
          }
        }

        // Re-fetch categories to get correct IDs
        final updatedCategories = await _dbHelper.getCategories();

        // Import Links
        final linksData = data['links'] as List;
        for (var linkMap in linksData) {
          final link = LinkItem.fromMap(linkMap);
          // Check if link already exists (simple URL check or just insert new)
          await _dbHelper.insertLink(link);
        }
        return true;
      }
    }
    return false;
  }
}
