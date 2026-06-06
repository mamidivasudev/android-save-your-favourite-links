import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/link_provider.dart';
import 'package:any_link_preview/any_link_preview.dart';
import '../models/link_item.dart';
import '../models/category_item.dart';
import '../services/google_drive_service.dart';
import '../screens/drawer_menu.dart';

enum SortOption { newest, oldest, aToZ, zToA }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSelectionMode = false;
  final Set<int> _selectedLinkIds = {};
  bool _isSyncing = false;
  final GoogleDriveService _driveService = GoogleDriveService();
  
  SortOption _currentSort = SortOption.newest;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Data loads automatically using app documents folder by default
  }

  Future<void> _showFolderPicker() async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Storage Folder', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Choose a custom folder to save your links data. If you skip, data is saved in the default app folder.',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop(); // Close dialog first
              
              if (Theme.of(context).platform == TargetPlatform.android) {
                var status = await Permission.manageExternalStorage.request();
                if (!status.isGranted) {
                  status = await Permission.storage.request();
                }
              }

              String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory != null && mounted) {
                await Provider.of<LinkProvider>(context, listen: false)
                    .setStoragePath(selectedDirectory);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Storage folder updated!', style: GoogleFonts.poppins(fontSize: 13)),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.folder_open),
            label: Text('Pick Folder', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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

  // ─── Google Drive Sync ─────────────────────────────────────────────────────

  Future<void> _syncToGoogleDrive() async {
    final provider = Provider.of<LinkProvider>(context, listen: false);

    var account = await _driveService.signInSilently();
    account ??= await _driveService.signIn();

    if (account == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Open the menu to sign in to Google Drive',
                  style: GoogleFonts.poppins(fontSize: 13))),
            ]),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.cloud_upload_outlined, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Text('Sync to Drive?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'This will overwrite any existing backup on Google Drive with your current local data.\n\nContinue?',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Sync', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text('Syncing with Google Drive...', style: GoogleFonts.poppins(fontSize: 13))),
        ]),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(days: 1), // Stay until dismissed
      ),
    );

    final jsonContent = await provider.getBackupJson();
    final result = await _driveService.backupToDrive(jsonContent);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _isSyncing = false);

    String syncMsg;
    Color syncColor;
    IconData syncIcon;
    switch (result) {
      case BackupResult.success:
        syncMsg = 'Synced to Google Drive!';
        syncColor = const Color(0xFF16A34A);
        syncIcon = Icons.cloud_done;
        break;
      case BackupResult.notSignedIn:
        syncMsg = 'Sign in from the menu to sync';
        syncColor = Colors.orange.shade700;
        syncIcon = Icons.warning_amber_rounded;
        break;
      case BackupResult.error:
        syncMsg = 'Sync failed. Check internet and try again.';
        syncColor = Colors.red.shade700;
        syncIcon = Icons.error_outline;
        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(syncIcon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(syncMsg, style: GoogleFonts.poppins(fontSize: 13))),
        ]),
        backgroundColor: syncColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
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
                  : _isSearching
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search links...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        )
                      : Text(
                          'My Saved Links 📌',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                        ),
              centerTitle: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              actionsIconTheme: const IconThemeData(color: Colors.white),
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
                    onPressed: () => _selectAll(provider.links),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: _deleteSelected,
                  ),
                ] else ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        if (_isSearching) {
                          _isSearching = false;
                          _searchController.clear();
                          _searchQuery = '';
                        } else {
                          _isSearching = true;
                        }
                      });
                    },
                  ),
                  PopupMenuButton<SortOption>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.sort, color: Colors.white),
                    onSelected: (SortOption result) {
                      setState(() {
                        _currentSort = result;
                      });
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
                      const PopupMenuItem<SortOption>(
                        value: SortOption.newest,
                        child: Text('Newest First'),
                      ),
                      const PopupMenuItem<SortOption>(
                        value: SortOption.oldest,
                        child: Text('Oldest First'),
                      ),
                      const PopupMenuItem<SortOption>(
                        value: SortOption.aToZ,
                        child: Text('Alphabetical (A-Z)'),
                      ),
                      const PopupMenuItem<SortOption>(
                        value: SortOption.zToA,
                        child: Text('Alphabetical (Z-A)'),
                      ),
                    ],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.cloud_sync, color: Colors.white),
                    tooltip: 'Sync to Google Drive',
                    onPressed: _isSyncing ? null : _syncToGoogleDrive,
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
            drawer: AppDrawer(
              onCategoriesTap: () => _showManageCategoriesDialog(context),
              onStorageFolderTap: _showFolderPicker,
            ),
            body: provider.links.isEmpty
                ? _buildEmptyState()
                : TabBarView(
                    children: categories.map((category) {
                      var filteredLinks = provider.links.where((link) {
                        // Category filter
                        bool matchesCategory = category.id == -1 || link.categoryId == category.id;
                        if (!matchesCategory) return false;
                        
                        // Search filter
                        if (_searchQuery.isNotEmpty) {
                          return link.title.toLowerCase().contains(_searchQuery) ||
                                 link.url.toLowerCase().contains(_searchQuery);
                        }
                        return true;
                      }).toList();

                      // Apply sorting
                      filteredLinks.sort((a, b) {
                        switch (_currentSort) {
                          case SortOption.newest:
                            return b.createdAt.compareTo(a.createdAt);
                          case SortOption.oldest:
                            return a.createdAt.compareTo(b.createdAt);
                          case SortOption.aToZ:
                            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
                          case SortOption.zToA:
                            return b.title.toLowerCase().compareTo(a.title.toLowerCase());
                        }
                      });

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
                                  mode: LaunchMode.inAppWebView
                                )) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not launch ${link.url}')),
                                    );
                                  }
                                }
                              }
                            },
                            onLongPress: () => _toggleSelection(link.id!),
                          );
                        },
                      );
                    }).toList(),
                  ),
            floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
              onPressed: () => _onFabPressed(context),
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );

  }

  void _onFabPressed(BuildContext context) async {
    final provider = Provider.of<LinkProvider>(context, listen: false);
    bool setupCompleted = await provider.hasCompletedSetup();
    bool hasCustomFolder = await provider.hasCustomStoragePath();
    bool isDriveSignedIn = await provider.isDriveSignedIn();

    if (!setupCompleted && !hasCustomFolder && !isDriveSignedIn && mounted) {
      _showSetupPrompt(context);
    } else {
      // If any is configured, or they already clicked "Skip", just show add dialog
      _showAddDialog(context);
    }
  }

  void _showSetupPrompt(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Setup Storage', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Where would you like to save your links?\n\n'
          '• Local Folder: Pick a visible folder on your phone.\n'
          '• Google Drive: Sync across devices.\n'
          '• Use Default: Save to internal hidden app storage.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Provider.of<LinkProvider>(context, listen: false).setSetupCompleted(true);
              if (mounted) _showAddDialog(context);
            },
            child: Text('Use Default', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final account = await _driveService.signIn();
              if (account != null && mounted) {
                await Provider.of<LinkProvider>(context, listen: false).setSetupCompleted(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed into Google Drive!'), backgroundColor: Color(0xFF16A34A)),
                );
              }
              if (mounted) _showAddDialog(context);
            },
            child: Text('Google Drive', style: GoogleFonts.poppins(color: Colors.blue.shade800)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              if (Theme.of(context).platform == TargetPlatform.android) {
                var status = await Permission.manageExternalStorage.request();
                if (!status.isGranted) {
                  status = await Permission.storage.request();
                }
              }

              String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory != null && mounted) {
                await Provider.of<LinkProvider>(context, listen: false).setStoragePath(selectedDirectory);
                await Provider.of<LinkProvider>(context, listen: false).setSetupCompleted(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Folder selected!'), backgroundColor: Color(0xFF16A34A)),
                );
              }
              if (mounted) _showAddDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Pick Folder', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
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
                try {
                  provider.addLink(titleController.text, urlController.text, categoryId: selectedCategoryId);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link saved successfully!')),
                  );
                } on DuplicateLinkException catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(e.message, style: GoogleFonts.poppins(fontSize: 13)),
                        ],
                      ),
                      backgroundColor: Colors.orange.shade800,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
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
                  Expanded(
                    child: Text(
                      'Manage Categories',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
        color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Theme.of(context).cardColor,
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
                  Expanded(
                    child: IgnorePointer( // Ignore pointer so LinkCard onTap triggers instead of AnyLinkPreview
                      child: AnyLinkPreview(
                        link: link.url,
                        displayDirection: UIDirection.uiDirectionHorizontal,
                        showMultimedia: true,
                        bodyMaxLines: 3,
                        bodyTextOverflow: TextOverflow.ellipsis,
                        titleStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        bodyStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        errorBody: link.url,
                        errorTitle: link.title,
                        errorWidget: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
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
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    link.url,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        cache: const Duration(days: 7),
                        backgroundColor: Colors.transparent,
                        borderRadius: 0,
                        removeElevation: true,
                      ),
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
