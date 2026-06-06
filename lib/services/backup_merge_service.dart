import '../models/category_item.dart';
import '../models/link_item.dart';

class BackupMergeService {
  static Map<String, dynamic> mergeData(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localLinks = _parseLinks(local['links']);
    final remoteLinks = _parseLinks(remote['links']);
    final localCategories = _parseCategories(local['categories']);
    final remoteCategories = _parseCategories(remote['categories']);

    final mergedCategories = <CategoryItem>[];
    final categoryIdByName = <String, int>{};
    var nextCategoryId = 1;

    void addCategory(CategoryItem category) {
      final key = category.name.toLowerCase().trim();
      if (categoryIdByName.containsKey(key)) return;
      final merged = CategoryItem(id: nextCategoryId++, name: category.name);
      mergedCategories.add(merged);
      categoryIdByName[key] = merged.id!;
    }

    for (final category in [...localCategories, ...remoteCategories]) {
      addCategory(category);
    }

    final oldCategoryIdToName = <int, String>{};
    for (final category in [...localCategories, ...remoteCategories]) {
      if (category.id != null) {
        oldCategoryIdToName[category.id!] = category.name;
      }
    }

    int? remapCategoryId(int? categoryId) {
      if (categoryId == null) return null;
      final name = oldCategoryIdToName[categoryId];
      if (name == null) return null;
      return categoryIdByName[name.toLowerCase().trim()];
    }

    final mergedLinksByUrl = <String, LinkItem>{};
    for (final link in [...localLinks, ...remoteLinks]) {
      final key = link.url.toLowerCase().trim();
      final existing = mergedLinksByUrl[key];
      if (existing == null || link.createdAt.isAfter(existing.createdAt)) {
        mergedLinksByUrl[key] = link.copyWith(categoryId: remapCategoryId(link.categoryId));
      }
    }

    final mergedLinks = mergedLinksByUrl.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    var nextLinkId = 1;
    final normalizedLinks = mergedLinks
        .map((link) => link.copyWith(id: nextLinkId++))
        .map((link) => link.toMap())
        .toList();

    return {
      'categories': mergedCategories.map((category) => category.toMap()).toList(),
      'links': normalizedLinks,
    };
  }

  static List<LinkItem> _parseLinks(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => LinkItem.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  static List<CategoryItem> _parseCategories(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => CategoryItem.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }
}
