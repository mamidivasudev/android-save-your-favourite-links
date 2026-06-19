
class LinkItem {
  final int? id;
  final String title;
  final String url;
  final DateTime createdAt;
  final int? categoryId;
  final bool isPinned;
  final bool isFavorite;
  final bool isLocked;

  LinkItem({
    this.id,
    required this.title,
    required this.url,
    required this.createdAt,
    this.categoryId,
    this.isPinned = false,
    this.isFavorite = false,
    this.isLocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'createdAt': createdAt.toIso8601String(),
      'categoryId': categoryId,
      'isPinned': isPinned ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'isLocked': isLocked ? 1 : 0,
    };
  }

  factory LinkItem.fromMap(Map<String, dynamic> map) {
    return LinkItem(
      id: map['id'],
      title: map['title'],
      url: map['url'],
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt']) ?? DateTime.now())
          : DateTime.now(),
      categoryId: map['categoryId'],
      isPinned: map['isPinned'] == 1 || map['isPinned'] == true,
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
      isLocked: map['isLocked'] == 1 || map['isLocked'] == true,
    );
  }

  LinkItem copyWith({
    int? id,
    String? title,
    String? url,
    DateTime? createdAt,
    int? categoryId,
    bool? isPinned,
    bool? isFavorite,
    bool? isLocked,
  }) {
    return LinkItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
