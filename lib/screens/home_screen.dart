import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/link_provider.dart';
import '../models/link_item.dart';
import '../models/category_item.dart';
import '../services/data_service.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSelectionMode = false;
  final Set<int> _selectedLinkIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStoragePath();
    });
  }

  Future<void> _checkStoragePath() async {
    final provider = Provider.of<LinkProvider>(context, listen: false);
    bool hasPath = await provider.hasStoragePath();
    if (!hasPath) {
      if (mounted) {
        _showFolderPicker();
      }
    }
  }

  Future<void> _showFolderPicker() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Select Storage Folder', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Please select a folder where you want to save your links data as a JSON file.', style: GoogleFonts.poppins()),
        actions: [
          ElevatedButton(
            onPressed: () async {
              String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory != null) {
                if (context.mounted) {
                  await Provider.of<LinkProvider>(context, listen: false).setStoragePath(selectedDirectory);
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Pick Folder'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedLinkIds.contains(id)) {
        _selectedLinkIds.remove(id);
        if (_selectedLinkIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedLinkIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll(List<LinkItem> links) {
    setState(() {
      if (_selectedLinkIds.length == links.length) {
        _selectedLinkIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedLinkIds.clear();
        for (var link in links) {
          _selectedLinkIds.add(link.id!);
        }
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text('Are you sure you want to delete ${_selectedLinkIds.length} links?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<LinkProvider>(context, listen: false).removeMultipleLinks(_selectedLinkIds.toList());
      setState(() {
        _selectedLinkIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No links found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share links from YouTube, Insta, or Chrome!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkProvider>(
      builder: (context, provider, child) {
        final categories = [CategoryItem(id: -1, name: 'All'), ...provider.categories];
        
        return DefaultTabController(
          length: categories.length,
          child: Scaffold(
            appBar: AppBar(
              title: _isSelectionMode
                  ? Text('${_selectedLinkIds.length} selected')
                  : Text(
                      'Link Saver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
              centerTitle: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSelectionMode 
                      ? [Colors.red.shade800, Colors.red.shade600]
                      : [Colors.blue.shade800, Colors.purple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedLinkIds.clear();
                        });
                      },
                    )
                  : null,
              actions: [
                if (_isSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.select_all, color: Colors.white),
                    onPressed: () {
                      _selectAll(provider.links);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: _deleteSelected,
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.file_upload, color: Colors.white),
                    tooltip: 'Export JSON',
                    onPressed: () => DataService.exportData(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download, color: Colors.white),
                    tooltip: 'Import JSON',
                    onPressed: () async {
                      bool success = await DataService.importData();
                      if (success) {
                        provider.fetchCategories();
                        provider.fetchLinks();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Data imported successfully!')),
                        );
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'categories') {
                        _showManageCategoriesDialog(context);
                      } else if (value == 'storage') {
                        _showFolderPicker();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'categories',
                        child: Text('Manage Categories'),
                      ),
                      const PopupMenuItem(
                        value: 'storage',
                        child: Text('Change Storage Folder'),
                      ),
                    ],
                  ),
                ]
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.only(left: 8),
                tabs: categories.map((category) => Tab(text: category.name)).toList(),
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 13),
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorWeight: 3,
              ),
            ),
            body: provider.links.isEmpty
                ? _buildEmptyState()
                : TabBarView(
                    children: categories.map((category) {
                      final filteredLinks = provider.links.where((link) {
                        if (category.id == -1) return true;
                        return link.categoryId == category.id;
                      }).toList();

                      if (filteredLinks.isEmpty) {
                        return Center(
                          child: Text(
                            'No ${category.name} links',
                            style: GoogleFonts.poppins(color: Colors.grey.shade500),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: filteredLinks.length,
                        itemBuilder: (context, index) {
                          final link = filteredLinks[index];
                          final isSelected = _selectedLinkIds.contains(link.id);
                          return LinkCard(
                            link: link,
                            isSelected: isSelected,
                            isSelectionMode: _isSelectionMode,
                            onTap: () async {
                              if (_isSelectionMode) {
                                _toggleSelection(link.id!);
                              } else {
                                final Uri url = Uri.parse(link.url);
                                if (!await launchUrl(
                                  url, 
                                  mode: LaunchMode.platformDefault
                                )) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not launch ${link.url}')),
                                    );
                                  }
                                }
                              }
                            },
                            onLongPress: () {
                              _toggleSelection(link.id!);
                            },
                          );
                        },
                      );
                    }).toList(),
                  ),
            floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
              onPressed: () => _showAddDialog(context),
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController urlController = TextEditingController();
    final FocusNode urlFocusNode = FocusNode();
    int? selectedCategoryId;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer<LinkProvider>(
          builder: (context, provider, child) {
            // Initial auto-categorization
            selectedCategoryId ??= provider.getAutoCategoryId(urlController.text);

            void save() {
              if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                provider.addLink(titleController.text, urlController.text, categoryId: selectedCategoryId);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link saved successfully!')),
                );
              }
            }

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Text('Add New Link', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        onPressed: save,
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleController,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(urlFocusNode),
                          decoration: InputDecoration(
                            labelText: 'Title',
                            hintText: 'e.g. My Favorite Song',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: urlController,
                          focusNode: urlFocusNode,
                          textInputAction: TextInputAction.done,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedCategoryId = provider.getAutoCategoryId(val);
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'URL',
                            hintText: 'e.g. https://example.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Select Category:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 0,
                          children: provider.categories.map((cat) {
                            final isSelected = selectedCategoryId == cat.id;
                            return ChoiceChip(
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  selectedCategoryId = selected ? cat.id : null;
                                });
                              },
                              selectedColor: Colors.blue.shade800,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                );
              }
            );
          }
        );
      },
    );
  }

  void _showManageCategoriesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<LinkProvider>(
          builder: (context, provider, child) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Text('Manage Categories', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: () => _showAddCategoryDialog(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.categories.length,
                  itemBuilder: (context, index) {
                    final category = provider.categories[index];
                    return ListTile(
                      title: Text(category.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditCategoryDialog(context, category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text('Delete Category', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                  content: Text('Are you sure you want to delete "${category.name}"? This will not delete the links in this category.', style: GoogleFonts.poppins()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                provider.removeCategory(category.id!);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<LinkProvider>(context, listen: false).addCategory(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, CategoryItem category) {
    final TextEditingController controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<LinkProvider>(context, listen: false).updateCategory(category.copyWith(name: controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class LinkCard extends StatelessWidget {
  final LinkItem link;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const LinkCard({
    super.key,
    required this.link,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        border: isSelected ? Border.all(color: Colors.blue.shade300, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.blue.shade800 : Colors.grey,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(8), // Reduced padding for images
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _getIconWidgetForUrl(link.url),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link.title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          link.url,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isSelectionMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) {
                        switch (value) {
                          case 'copy':
                            Clipboard.setData(ClipboardData(text: link.url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied to clipboard!')),
                            );
                            break;
                          case 'share':
                            Share.share('${link.title}\n${link.url}');
                            break;
                          case 'edit':
                            _showEditDialog(context);
                            break;
                          case 'delete':
                            _showDeleteConfirmationDialog(context);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 20),
                              SizedBox(width: 8),
                              Text('Copy'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, size: 20),
                              SizedBox(width: 8),
                              Text('Share'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Link', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete this link?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<LinkProvider>(context, listen: false).removeLink(link.id!);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController(text: link.title);
    final TextEditingController urlController = TextEditingController(text: link.url);
    final FocusNode urlFocusNode = FocusNode();
    int? selectedCategoryId = link.categoryId;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer<LinkProvider>(
          builder: (context, provider, child) {
            void save() {
              if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                final updatedLink = link.copyWith(
                  title: titleController.text,
                  url: urlController.text,
                  categoryId: selectedCategoryId,
                );
                Provider.of<LinkProvider>(context, listen: false).updateLink(updatedLink);
                Navigator.of(context).pop();
              }
            }

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Text('Edit Link', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        onPressed: save,
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleController,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(urlFocusNode),
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: urlController,
                          focusNode: urlFocusNode,
                          textInputAction: TextInputAction.done,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedCategoryId = provider.getAutoCategoryId(val);
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'URL',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Select Category:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 0,
                          children: provider.categories.map((cat) {
                            final isSelected = selectedCategoryId == cat.id;
                            return ChoiceChip(
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  selectedCategoryId = selected ? cat.id : null;
                                });
                              },
                              selectedColor: Colors.blue.shade800,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                );
              }
            );
          }
        );
      },
    );
  }

  Widget _getIconWidgetForUrl(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return Image.asset('assets/icons/youtube.png', width: 32, height: 32);
    } else if (url.contains('instagram.com')) {
      return Image.asset('assets/icons/instagram.png', width: 32, height: 32);
    } else if (url.contains('maps.google') || url.contains('goo.gl/maps') || url.contains('google.com/maps') || url.contains('maps.app.goo.gl')) {
      return Image.asset('assets/icons/maps.png', width: 32, height: 32);
    } else {
      return Icon(Icons.link, color: Colors.blue.shade800, size: 28);
    }
  }
}
