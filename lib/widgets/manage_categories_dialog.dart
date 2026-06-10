import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/link_provider.dart';
import '../models/category_item.dart';

enum ManageCategoryMode { view, edit, delete }

class ManageCategoriesDialog extends StatefulWidget {
  const ManageCategoriesDialog({super.key});

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  ManageCategoryMode _mode = ManageCategoryMode.view;
  Set<int> _selectedIds = {};
  Map<int, TextEditingController> _editControllers = {};

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    _editControllers.clear();
  }

  void _initEditMode(List<CategoryItem> categories) {
    _disposeControllers();
    for (var cat in categories) {
      _editControllers[cat.id!] = TextEditingController(text: cat.name);
    }
    setState(() {
      _mode = ManageCategoryMode.edit;
    });
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Category', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Category Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<LinkProvider>(context, listen: false).addCategory(controller.text);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Add', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(LinkProvider provider) async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Categories', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} categories? All links saved in these categories will also be permanently deleted.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.removeMultipleCategories(_selectedIds.toList());
      setState(() {
        _mode = ManageCategoryMode.view;
        _selectedIds.clear();
      });
    }
  }

  Future<void> _handleUpdate(LinkProvider provider, List<CategoryItem> categories) async {
    bool hasChanges = false;
    for (var cat in categories) {
      final newName = _editControllers[cat.id!]?.text.trim() ?? '';
      if (newName.isNotEmpty && newName != cat.name) {
        hasChanges = true;
        break;
      }
    }

    if (!hasChanges) {
      setState(() {
        _mode = ManageCategoryMode.view;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Update Categories', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to update the category names?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Update', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (var cat in categories) {
        final newName = _editControllers[cat.id!]?.text.trim() ?? '';
        if (newName.isNotEmpty && newName != cat.name) {
          await provider.updateCategory(cat.copyWith(name: newName));
        }
      }
      setState(() {
        _mode = ManageCategoryMode.view;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkProvider>(
      builder: (context, provider, child) {
        final categories = provider.categories;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
          title: _buildHeader(categories, provider),
          content: SizedBox(
            width: double.maxFinite,
            child: categories.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('No categories available.', style: GoogleFonts.poppins(), textAlign: TextAlign.center),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12, indent: 20, endIndent: 20),
                      itemBuilder: (context, index) {
                        return _buildListItem(categories[index]);
                      },
                    ),
                  ),
          ),
          actions: _buildActions(provider, categories),
        );
      },
    );
  }

  Widget _buildHeader(List<CategoryItem> categories, LinkProvider provider) {
    String titleText = 'Manage Link\nCategories';
    if (_mode == ManageCategoryMode.delete) titleText = 'Delete\nCategories';
    if (_mode == ManageCategoryMode.edit) titleText = 'Edit Categories';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            titleText,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildHeaderActions(categories, provider),
        ),
      ],
    );
  }

  List<Widget> _buildHeaderActions(List<CategoryItem> categories, LinkProvider provider) {
    switch (_mode) {
      case ManageCategoryMode.view:
        return [
          IconButton(
            icon: Icon(Icons.add, color: Colors.blue.shade700, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _showAddCategoryDialog(context),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.grey.shade800, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: categories.isEmpty ? null : () => _initEditMode(categories),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: categories.isEmpty
                ? null
                : () {
                    setState(() {
                      _mode = ManageCategoryMode.delete;
                      _selectedIds.clear();
                    });
                  },
          ),
        ];

      case ManageCategoryMode.delete:
        final allSelected = _selectedIds.length == categories.length && categories.isNotEmpty;
        return [
          IconButton(
            icon: Icon(Icons.select_all, color: Colors.grey.shade800, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedIds.clear();
                } else {
                  _selectedIds = categories.map((c) => c.id!).toSet();
                }
              });
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _selectedIds.isEmpty ? null : () => _handleDelete(provider),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _mode = ManageCategoryMode.view;
                _selectedIds.clear();
              });
            },
          ),
        ];

      case ManageCategoryMode.edit:
        return [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _mode = ManageCategoryMode.view;
              });
            },
          ),
        ];
    }
  }

  Widget _buildListItem(CategoryItem category) {
    switch (_mode) {
      case ManageCategoryMode.view:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            category.name,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
          ),
        );

      case ManageCategoryMode.delete:
        final isSelected = _selectedIds.contains(category.id);
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(category.id);
              } else {
                _selectedIds.add(category.id!);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(category.id!);
                      } else {
                        _selectedIds.remove(category.id);
                      }
                    });
                  },
                  activeColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        );

      case ManageCategoryMode.edit:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _editControllers[category.id],
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.blue.shade700),
              ),
            ),
          ),
        );
    }
  }

  List<Widget> _buildActions(LinkProvider provider, List<CategoryItem> categories) {
    if (_mode == ManageCategoryMode.edit) {
      return [
        TextButton(
          onPressed: () {
            setState(() {
              _mode = ManageCategoryMode.view;
            });
          },
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
        ),
        TextButton(
          onPressed: () => _handleUpdate(provider, categories),
          child: Text('Update', style: GoogleFonts.poppins(color: const Color(0xFF16A34A), fontWeight: FontWeight.bold)),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Close', style: GoogleFonts.poppins(color: Colors.blue.shade700)),
      ),
    ];
  }
}
