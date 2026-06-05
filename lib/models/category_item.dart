
class CategoryItem {
  final int? id;
  final String name;

  CategoryItem({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    return CategoryItem(
      id: map['id'],
      name: map['name'],
    );
  }

  CategoryItem copyWith({
    int? id,
    String? name,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
