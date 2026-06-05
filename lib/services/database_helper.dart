import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/link_item.dart';
import '../models/category_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'links_database.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE links(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        url TEXT,
        createdAt TEXT,
        categoryId INTEGER,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Insert default categories
    final defaultCategories = ['YouTube', 'Instagram', 'Maps', 'Google', 'Other'];
    for (var category in defaultCategories) {
      await db.insert('categories', {'name': category});
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE
        )
      ''');

      await db.execute('ALTER TABLE links ADD COLUMN categoryId INTEGER');

      // Insert default categories
      final defaultCategories = ['YouTube', 'Instagram', 'Maps', 'Google', 'Other'];
      for (var category in defaultCategories) {
        await db.insert('categories', {'name': category});
      }
    }
  }

  // Links Methods
  Future<int> insertLink(LinkItem link) async {
    Database db = await database;
    return await db.insert('links', link.toMap());
  }

  Future<List<LinkItem>> getLinks() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('links', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) {
      return LinkItem.fromMap(maps[i]);
    });
  }

  Future<int> deleteLink(int id) async {
    Database db = await database;
    return await db.delete('links', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMultipleLinks(List<int> ids) async {
    Database db = await database;
    await db.transaction((txn) async {
      for (var id in ids) {
        await txn.delete('links', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<int> updateLink(LinkItem link) async {
    Database db = await database;
    return await db.update(
      'links',
      link.toMap(),
      where: 'id = ?',
      whereArgs: [link.id],
    );
  }

  // Categories Methods
  Future<int> insertCategory(CategoryItem category) async {
    Database db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<CategoryItem>> getCategories() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) {
      return CategoryItem.fromMap(maps[i]);
    });
  }

  Future<int> deleteCategory(int id) async {
    Database db = await database;
    // Set categoryId to null for links in this category
    await db.update('links', {'categoryId': null}, where: 'categoryId = ?', whereArgs: [id]);
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCategory(CategoryItem category) async {
    Database db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }
}
