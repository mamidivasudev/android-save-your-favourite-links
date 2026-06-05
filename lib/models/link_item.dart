
class LinkItem {
  final int? id;
  final String title;
  final String url;
  final DateTime createdAt;
  final int? categoryId;

  LinkItem({
    this.id,
    required this.title,
    required this.url,
    required this.createdAt,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'createdAt': createdAt.toIso8601String(),
      'categoryId': categoryId,
    };
  }

  factory LinkItem.fromMap(Map<String, dynamic> map) {
    return LinkItem(
      id: map['id'],
      title: map['title'],
      url: map['url'],
      createdAt: DateTime.parse(map['createdAt']),
      categoryId: map['categoryId'],
    );
  }

  LinkItem copyWith({
    int? id,
    String? title,
    String? url,
    DateTime? createdAt,
    int? categoryId,
  }) {
    return LinkItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
