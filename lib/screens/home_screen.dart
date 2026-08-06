import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/link_provider.dart';
import 'package:any_link_preview/any_link_preview.dart';
import '../models/link_item.dart';
import '../models/category_item.dart';
import '../services/google_drive_service.dart';
import '../screens/drawer_menu.dart';
import '../screens/google_drive_dialog.dart';
import '../services/auth_service.dart';
import '../utils/url_validator.dart';
import '../screens/premium_screen.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/manage_categories_dialog.dart';

enum SortOption { newest, oldest, aToZ, zToA }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isSelectionMode = false;
  final Set<int> _selectedLinkIds = {};
  bool _isSyncing = false;
  final GoogleDriveService _driveService = GoogleDriveService();
  // Key used to open the drawer from dialogs without relying on BuildContext
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  SortOption _currentSort = SortOption.newest;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();

  late AnimationController _syncAnimationController;

  @override
  void dispose() {
    _searchController.dispose();
    _syncAnimationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<LinkProvider>(context, listen: false);
      if (!await provider.hasCompletedSetup()) {
        if (mounted) _showSetupDialog();
      } else {
        await _checkAndStartShowcase();
      }
    });
  }

  Future<void> _checkAndStartShowcase() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('showcase_done') ?? false)) {
      if (mounted) {
        ShowCaseWidget.of(context).startShowCase([_menuKey, _searchKey, _addKey]);
        await prefs.setBool('showcase_done', true);
      }
    }
  }

  void _showSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Setup Storage', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where would you like to save your links?', style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 16),
            Text('• Google Drive: Sync across devices.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () async {
              final provider = Provider.of<LinkProvider>(context, listen: false);
              Navigator.pop(ctx);
              await provider.setSetupCompleted(true);
              _checkAndStartShowcase();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Skip', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              ]
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<LinkProvider>(context, listen: false);
              Navigator.pop(ctx);
              await showDialog(context: context, builder: (_) => const GoogleDriveDialog());
              
              if (mounted) {
                if (await provider.isDriveSignedIn()) {
                  await provider.setSetupCompleted(true);
                  _checkAndStartShowcase();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Set Up Drive', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
            'Share links from YouTube, Insta, Chrome, Maps, etc!',
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
          SnackBar(duration: const Duration(seconds: 2), 
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
    return ShowCaseWidget(
      builder: (context) => Selector<LinkProvider, int>(
        // Only rebuilds DefaultTabController when the NUMBER of categories changes,
        // NOT on every link add/remove. This prevents the active tab from resetting.
        selector: (_, p) => p.categories.length + 1,
        builder: (context, tabCount, _) => DefaultTabController(
          length: tabCount,
          child: Consumer<LinkProvider>(
      builder: (context, provider, child) {
        final categories = [CategoryItem(id: -1, name: 'All'), ...provider.categories];
        
        final isAnySyncing = _isSyncing || provider.isAutoSyncing;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (isAnySyncing && !_syncAnimationController.isAnimating) {
              _syncAnimationController.repeat();
            } else if (!isAnySyncing && _syncAnimationController.isAnimating) {
              _syncAnimationController.stop();
            }
          }
        });
        
        return Scaffold(
          key: _scaffoldKey,
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
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rakhna 🔗',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                            ),
                            Text(
                              '  Save It. Find It. Fast',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
              centerTitle: false,
              titleSpacing: 0,
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
                  : Showcase(
                      key: _menuKey,
                      description: 'Open the menu to create folders, change themes, and enable Cloud Backup.',
                      child: Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                    ),
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
                  // Premium icon removed from appbar
                  Showcase(
                    key: _searchKey,
                    description: 'Search for any saved link instantly right here.',
                    child: InkWell(
                      onTap: () {
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white, size: 20),
                            Text(_isSearching ? 'Close' : 'Search', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<SortOption>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Sort Options',
                    offset: const Offset(0, 45),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sort, color: Colors.white, size: 20),
                          Text('Sort', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (!Provider.of<LinkProvider>(context, listen: false).isProUser) {
                        _showProFeatureDialog(
                          context,
                          icon: Icons.cloud_sync,
                          color: Colors.blue.shade600,
                          featureName: 'Auto Sync to Drive',
                          description: 'Never worry about losing your data!\n\nAuto Sync instantly backs up every link you add, edit, or delete directly to your Google Drive in the background.',
                          emoji: '☁️',
                        );
                        return;
                      }
                      if (isAnySyncing) return;
                      _syncToGoogleDrive();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (Provider.of<LinkProvider>(context).isProUser)
                            RotationTransition(
                              turns: _syncAnimationController,
                              child: const Icon(Icons.sync, color: Colors.white, size: 20),
                            )
                          else
                            const Icon(Icons.sync_disabled, color: Colors.amber, size: 20),
                          Text(
                            Provider.of<LinkProvider>(context).isProUser ? 'Sync' : 'Auto-Sync', 
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                  ),
                ]
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.only(left: 8),
                tabs: categories.map((category) {
                  final count = category.id == -1 
                      ? provider.links.length 
                      : provider.links.where((l) => l.categoryId == category.id).length;
                  return Tab(text: '${category.name} ($count)');
                }).toList(),
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
                        if (a.isPinned && !b.isPinned) return -1;
                        if (!a.isPinned && b.isPinned) return 1;

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
                                if (link.isLocked) {
                                  final provider = Provider.of<LinkProvider>(context, listen: false);
                                  provider.setAuthenticating(true);
                                  final authenticated = await AuthService.authenticateForLink();
                                  provider.setAuthenticating(false);
                                  if (!authenticated) return;
                                }

                                final Uri url = Uri.parse(link.url);
                                if (!await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication
                                )) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(duration: const Duration(seconds: 2), content: Text('Could not launch ${link.url}')),
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
            floatingActionButton: _isSelectionMode ? null : Showcase(
              key: _addKey,
              description: 'Tap here to save your very first link!',
              child: FloatingActionButton(
                onPressed: () => _onFabPressed(context),
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
            ),
            bottomNavigationBar: const BannerAdWidget(),
          );
        },
          ),
        ),
      ),
    );
  }

  void _onFabPressed(BuildContext context) async {
    final provider = Provider.of<LinkProvider>(context, listen: false);
    if (!provider.isProUser && provider.links.length >= 50) {
      _showProFeatureDialog(
        context,
        icon: Icons.all_inclusive,
        color: Colors.blue.shade700,
        featureName: 'Unlimited Links',
        description: 'You\'ve reached the 50-link free limit.\n\nUpgrade to Pro to save unlimited links — no cap, forever!',
        emoji: '🔗',
      );
      return;
    }
    if (!provider.isSetupCompleted) {
      _showSetupDialog();
    } else {
      _showAddDialog(context);
    }
  }


  void _showAddDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController urlController = TextEditingController();
    final FocusNode urlFocusNode = FocusNode();
    int? selectedCategoryId;
    String? urlError;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer<LinkProvider>(
          builder: (context, provider, child) {
            // Initial auto-categorization
            selectedCategoryId ??= provider.getAutoCategoryId(urlController.text);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                Future<void> save() async {
                  if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                    final normalized = UrlValidator.normalize(urlController.text);
                    if (normalized == null) {
                      setDialogState(() {
                        urlError = UrlValidator.validationError();
                      });
                      return;
                    }

                    setDialogState(() {
                      urlError = null;
                    });

                    try {
                      if (!provider.isProUser && provider.links.length >= 50) {
                        Navigator.of(context).pop(); // Close dialog
                        _showProFeatureDialog(
                          context,
                          icon: Icons.all_inclusive,
                          color: Colors.blue.shade700,
                          featureName: 'Unlimited Links',
                          description: 'You\'ve reached the 50-link free limit.\n\nUpgrade to Pro to save unlimited links — no cap, forever!',
                          emoji: '🔗',
                        );
                        return;
                      }
                      await provider.addLink(titleController.text, normalized, categoryId: selectedCategoryId);

                      bool shouldShowMilestone = false;
                      if (provider.links.length == 1000) {
                        final prefs = await SharedPreferences.getInstance();
                        final hasShown = prefs.getBool('has_shown_1k_warning') ?? false;
                        if (!hasShown) {
                          final isDriveEnabled = await provider.isGoogleDriveSignedIn();
                          if (!isDriveEnabled) {
                            await prefs.setBool('has_shown_1k_warning', true);
                            shouldShowMilestone = true;
                          }
                        }
                      }

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(duration: const Duration(seconds: 2), content: Text('Link saved successfully!')),
                        );
                        if (shouldShowMilestone) {
                          _show1kMilestoneWarning(context);
                        }
                      }
                    } on DuplicateLinkException catch (e) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(duration: const Duration(seconds: 2), 
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
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
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
                              urlError = null; // clear error when typing
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'URL',
                            hintText: 'e.g. https://example.com',
                            errorText: urlError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Category:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                            InkWell(
                              onTap: () {
                                final catController = TextEditingController();
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text('New Category', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                                    content: TextField(
                                      controller: catController,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: 'Category Name',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () async {
                                          final name = catController.text.trim();
                                          if (name.isNotEmpty) {
                                            await provider.addCategory(name);
                                            try {
                                              final newCat = provider.categories.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
                                              setDialogState(() {
                                                selectedCategoryId = newCat.id;
                                              });
                                            } catch (_) {}
                                          }
                                          if (ctx.mounted) Navigator.pop(ctx);
                                        },
                                        child: const Text('Add'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text('+ New', style: GoogleFonts.poppins(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.maxFinite,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...provider.categories.map((cat) {
                                final isSelected = selectedCategoryId == cat.id;
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedCategoryId = isSelected ? null : cat.id;
                                    });
                                  },
                                  child: Container(
                                    width: 76,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue.shade800 : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.blue.shade800.withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            cat.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
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
      builder: (_) => const ManageCategoriesDialog(),
    );
  }


  void _show1kMilestoneWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(child: Text('Wow, 1,000 Links!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          "You've built a massive collection! To ensure you never lose your data if something happens to your device, we highly recommend enabling Google Drive Backup in the side menu.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Maybe Later', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _scaffoldKey.currentState?.openDrawer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Enable Backup', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Shows an animated "Try It" demo dialog explaining a Pro feature.
void _showProFeatureDialog(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String featureName,
  required String description,
  required String emoji,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(icon, color: color, size: 38),
            ),
            const SizedBox(height: 16),

            // PRO badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade500],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('PRO FEATURE', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Feature name
            Text(
              '$emoji $featureName',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              description,
              style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
                },
                icon: const Icon(Icons.workspace_premium, size: 18),
                label: Text('Upgrade to Pro', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Maybe later
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Maybe Later', style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13)),
            ),
          ],
        ),
      ),
    ),
  );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showPreview = Provider.of<LinkProvider>(context).showLinkPreviews;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Theme.of(context).cardColor,
        border: isSelected ? Border.all(color: Colors.blue.shade300, width: 2) : Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: showPreview ? _buildPreviewLayout(context, isDark) : _buildCompactLayout(context, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context, bool isDark) {
    return Row(
      children: [
        if (isSelectionMode)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue.shade800 : Colors.grey,
            ),
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _getIconWidgetForUrl(link.url),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      link.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (link.isPinned) const Icon(Icons.push_pin, size: 14, color: Colors.blue),
                  if (link.isPinned && link.isFavorite) const SizedBox(width: 4),
                  if (link.isLocked) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock, size: 14, color: Colors.red)),
                  if (link.isFavorite) const Icon(Icons.favorite, size: 16, color: Colors.pink),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                link.url,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (!isSelectionMode)
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: () => _showMenuBottomSheet(context),
          ),
      ],
    );
  }

  Widget _buildPreviewLayout(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactLayout(context, isDark),
        const SizedBox(height: 12),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IgnorePointer(
              child: AnyLinkPreview(
                link: link.url,
                displayDirection: UIDirection.uiDirectionVertical,
                showMultimedia: true,
                bodyMaxLines: 3,
                bodyTextOverflow: TextOverflow.ellipsis,
                titleStyle: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                bodyStyle: GoogleFonts.poppins(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 12,
                ),
                errorWidget: Container(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link, size: 40, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Preview not available',
                          style: GoogleFonts.poppins(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                cache: const Duration(days: 7),
                backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _checkLocked(BuildContext context) {
    if (link.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.lock, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Unlock the link first to perform this action!', style: GoogleFonts.poppins(fontSize: 13))),
          ]),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return true;
    }
    return false;
  }

  void _showMenuBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                _buildMenuItem(
                  context,
                  icon: Icons.edit,
                  label: 'Edit',
                  iconColor: Colors.blue.shade700,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_checkLocked(context)) return;
                    _showEditDialog(context);
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.push_pin,
                  label: link.isPinned ? 'Unpin' : 'Pin',
                  iconColor: Colors.blue.shade700,
                  isProFeature: true,
                  isProUser: Provider.of<LinkProvider>(context, listen: false).isProUser,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (!Provider.of<LinkProvider>(context, listen: false).isProUser) {
                      _showProFeatureDialog(
                        context,
                        icon: Icons.push_pin,
                        color: Colors.blue.shade700,
                        featureName: 'Pin to Top',
                        description: 'Pin your most important links so they always appear at the very top of your list.\n\nNever lose track of what matters most!',
                        emoji: '📌',
                      );
                    } else {
                      Provider.of<LinkProvider>(context, listen: false).togglePin(link.id!);
                    }
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: link.isLocked ? Icons.lock_open : Icons.lock,
                  label: link.isLocked ? 'Unlock' : 'Lock',
                  iconColor: link.isLocked ? Colors.green : Colors.red,
                  isProFeature: true,
                  isProUser: Provider.of<LinkProvider>(context, listen: false).isProUser,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!Provider.of<LinkProvider>(context, listen: false).isProUser) {
                      _showProFeatureDialog(
                        context,
                        icon: Icons.lock,
                        color: Colors.red.shade600,
                        featureName: 'Lock Individual Links',
                        description: 'Keep your private links hidden and secure!\n\nPro users can lock any link so it can only be opened with your fingerprint or Face ID. Locked links cannot be edited, shared, moved, or deleted by anyone else!',
                        emoji: '🔒',
                      );
                      return;
                    }
                    if (link.isLocked) {
                      final provider = Provider.of<LinkProvider>(context, listen: false);
                      provider.setAuthenticating(true);
                      final authenticated = await AuthService.authenticateForLink();
                      provider.setAuthenticating(false);
                      if (!authenticated) return;
                    }
                    Provider.of<LinkProvider>(context, listen: false).toggleLock(link.id!);
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: link.isFavorite ? Icons.favorite : Icons.favorite_border,
                  label: link.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  iconColor: Colors.pink,
                  onTap: () {
                    Navigator.pop(ctx);
                    Provider.of<LinkProvider>(context, listen: false).toggleFavorite(link.id!);
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.share,
                  label: 'Share Link',
                  iconColor: Colors.blue.shade700,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_checkLocked(context)) return;
                    Share.share('${link.title}\n${link.url}');
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.move_to_inbox,
                  label: 'Move',
                  iconColor: Colors.blue.shade700,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_checkLocked(context)) return;
                    _showEditDialog(context);
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.copy,
                  label: 'Copy Link',
                  iconColor: Colors.blue.shade700,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_checkLocked(context)) return;
                    Clipboard.setData(ClipboardData(text: link.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(duration: const Duration(seconds: 2), content: Text('Link copied to clipboard!')),
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.delete,
                  label: 'Delete',
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_checkLocked(context)) return;
                    _showDeleteConfirmationDialog(context);
                  },
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    bool isProFeature = false,
    bool isProUser = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (isProFeature && !isProUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade500],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('PRO', style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      trailing: (isProFeature && !isProUser) ? Icon(Icons.lock_outline, size: 16, color: Colors.amber.shade600) : null,
      onTap: onTap,
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
            String? urlError;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                void save() {
                  if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                    final normalized = UrlValidator.normalize(urlController.text);
                    if (normalized == null) {
                      setDialogState(() { urlError = UrlValidator.validationError(); });
                      return;
                    }
                    setDialogState(() { urlError = null; });
                    final updatedLink = link.copyWith(
                      title: titleController.text,
                      url: normalized,
                      categoryId: selectedCategoryId,
                    );
                    Provider.of<LinkProvider>(context, listen: false).updateLink(updatedLink);
                    Navigator.of(context).pop();
                  }
                }

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
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
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
                              urlError = null; // clear error on typing
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'URL',
                            errorText: urlError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Select Category:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.maxFinite,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: provider.categories.map((cat) {
                              final isSelected = selectedCategoryId == cat.id;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedCategoryId = isSelected ? null : cat.id;
                                  });
                                },
                                child: Container(
                                  width: 76,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue.shade800 : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.blue.shade800.withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(Icons.check, size: 12, color: Colors.white),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Text(
                                          cat.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
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
