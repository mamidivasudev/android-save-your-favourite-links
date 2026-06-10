import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../providers/link_provider.dart';
import '../providers/theme_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../screens/premium_screen.dart';
import '../services/google_drive_service.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback? onCategoriesTap;
  final VoidCallback? onStorageFolderTap;

  const AppDrawer({
    super.key,
    this.onCategoriesTap,
    this.onStorageFolderTap,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final GoogleDriveService _driveService = GoogleDriveService();
  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Try to get cached account synchronously to prevent UI flash
    _currentUser = _driveService.currentUserSync;
    
    // Try silent sign-in on open to verify/refresh token
    _driveService.signInSilently().then((account) {
      if (mounted && account != _currentUser) {
        setState(() => _currentUser = account);
      }
    });
  }

  // ─── Auth Helpers ────────────────────────────────────────────────────────────

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final account = await _driveService.signIn();
      if (mounted) setState(() {
        _currentUser = account;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Sign in error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2), 
            content: Text(
              'Sign in failed: ${e.toString().split('\n').first}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out from Google Drive?', style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _driveService.signOut();
      if (mounted) setState(() => _currentUser = null);
    }
  }

  // ─── Backup ──────────────────────────────────────────────────────────────────

  Future<void> _handleBackup(BuildContext context) async {
    final provider = Provider.of<LinkProvider>(context, listen: false);

    if (_currentUser == null) {
      await _handleSignIn();
      if (_currentUser == null) return;
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
            Text('Backup to Drive?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
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
            child: Text('Backup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop();
    setState(() => _isLoading = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text('Backing up to Google Drive...', style: GoogleFonts.poppins(fontSize: 13))),
        ]),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(days: 1),
      ),
    );

    final jsonContent = await provider.getBackupJson();
    
    // Capture messenger before await because drawer context unmounts when closed
    final messenger = ScaffoldMessenger.of(context);
    
    final result = await _driveService.backupToDrive(jsonContent);

    if (mounted) setState(() => _isLoading = false);

    messenger.hideCurrentSnackBar();
    _showResultSnackBar(messenger, result);
  }

  void _showResultSnackBar(ScaffoldMessengerState messenger, BackupResult result) {
    String message;
    Color color;
    IconData icon;
    switch (result) {
      case BackupResult.success:
        message = 'Backup saved to Google Drive!';
        color = const Color(0xFF16A34A);
        icon = Icons.cloud_done;
        break;
      case BackupResult.notSignedIn:
        message = 'Please sign in to Google Drive first';
        color = Colors.orange.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case BackupResult.error:
        message = 'Backup failed. Check internet and try again.';
        color = Colors.red.shade700;
        icon = Icons.error_outline;
        break;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Restore ─────────────────────────────────────────────────────────────────

  Future<void> _handleRestore(BuildContext context) async {
    final provider = Provider.of<LinkProvider>(context, listen: false);

    if (_currentUser == null) {
      await _handleSignIn();
      if (_currentUser == null) return;
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
              child: Icon(Icons.cloud_download_outlined, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Text('Restore from Drive?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'This will replace your current local data with the backup from Google Drive.\n\nThis action cannot be undone.',
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
            child: Text('Restore', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop();

    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text('Restoring from Google Drive...', style: GoogleFonts.poppins(fontSize: 13))),
        ]),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(days: 1),
      ),
    );

    // Capture messenger before await
    final messenger = ScaffoldMessenger.of(context);

    final result = await _driveService.restoreFromDrive();
    if (mounted) setState(() => _isLoading = false);

    messenger.hideCurrentSnackBar();

    if (result.status == RestoreStatus.success && result.content != null) {
      await provider.restoreFromJson(result.content!);
      messenger.showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), 
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Data restored from Google Drive!', style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      String msg;
      switch (result.status) {
        case RestoreStatus.notSignedIn:  msg = 'Please sign in to Google Drive first'; break;
        case RestoreStatus.noBackupFound: msg = 'No backup found in Google Drive'; break;
        default: msg = 'Restore failed. Try again.';
      }
      messenger.showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), 
          content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          _buildHeader(),

          // ── Menu Items ──────────────────────────────────────────────────────
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                children: [
                  Consumer<LinkProvider>(
                    builder: (context, provider, child) {
                      if (provider.isProUser) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.amber.shade400, Colors.orange.shade500]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Get Lifetime Pro', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('Unlock all features', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Top Grid (2-columns)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.4,
                    children: [
                      // Theme
                      _buildDashboardCard(
                        context,
                        icon: Icons.nightlight_round,
                        iconColor: Colors.orange.shade400,
                        title: 'Theme',
                        subtitle: _getThemeSubtitle(context),
                        onTap: () => _showAppearanceDialog(context),
                      ),
                      // Manage Categories
                      _buildDashboardCard(
                        context,
                        icon: Icons.category_outlined,
                        iconColor: Colors.purple.shade400,
                        title: 'Categories',
                        subtitle: 'Add, edit, delete...',
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onCategoriesTap?.call();
                        },
                      ),
                      // Backup to Drive
                      _buildDashboardCard(
                        context,
                        icon: Icons.cloud_upload_outlined,
                        iconColor: Colors.blue.shade600,
                        title: 'Backup',
                        subtitle: 'Save to Drive',
                        onTap: () => _handleBackup(context),
                      ),
                      // Restore from Drive
                      _buildDashboardCard(
                        context,
                        icon: Icons.cloud_download_outlined,
                        iconColor: Colors.green.shade600,
                        title: 'Restore',
                        subtitle: 'Get from Drive',
                        onTap: () => _handleRestore(context),
                      ),
                      // Export JSON
                      _buildDashboardCard(
                        context,
                        icon: Icons.file_upload_outlined,
                        iconColor: const Color(0xFF7C3AED),
                        title: 'Export JSON',
                        subtitle: 'Save local file',
                        onTap: () {
                          Navigator.of(context).pop();
                          final provider = Provider.of<LinkProvider>(context, listen: false);
                          DataService.exportData(provider.categories, provider.links);
                        },
                      ),
                      // Import JSON
                      _buildDashboardCard(
                        context,
                        icon: Icons.file_download_outlined,
                        iconColor: const Color(0xFF0891B2),
                        title: 'Import JSON',
                        subtitle: 'Load local file',
                        onTap: () async {
                          Navigator.of(context).pop();
                          final provider = Provider.of<LinkProvider>(context, listen: false);
                          bool success = await DataService.importData(provider);
                          if (success && context.mounted) {
                            provider.fetchCategories();
                            provider.fetchLinks();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(duration: const Duration(seconds: 2), 
                                content: Text('Data imported successfully!', style: GoogleFonts.poppins()),
                                backgroundColor: const Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: Colors.black12),
                ),
                const SizedBox(height: 8),
                
                // Bottom List Tiles
                Consumer<LinkProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      children: [
                        SwitchListTile(
                          dense: true,
                          title: Text(
                            'Show Link Previews',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          value: provider.showLinkPreviews,
                          onChanged: (val) {
                            provider.toggleLinkPreviews();
                          },
                          activeColor: Colors.blue.shade600,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                          secondary: Icon(Icons.image_outlined, color: Colors.indigo.shade400),
                        ),
                        SwitchListTile(
                          dense: true,
                          title: Text(
                            'App Lock',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Require fingerprint on start',
                            style: GoogleFonts.poppins(fontSize: 11),
                          ),
                          value: provider.isAppLockEnabled,
                          onChanged: (val) async {
                            if (!provider.isProUser) {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
                              return;
                            }
                            try {
                              provider.setAuthenticating(true);
                              final authenticated = await AuthService.authenticateForLink();
                              provider.setAuthenticating(false);
                              
                              if (authenticated) {
                                provider.toggleAppLock(val);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(duration: const Duration(seconds: 2), content: Text('Authentication failed or canceled. Please fully restart the app if this persists.')),
                                  );
                                }
                              }
                            } catch (e) {
                              provider.setAuthenticating(false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(duration: const Duration(seconds: 2), content: Text('Error: $e - Try stopping the app and running flutter run again.')),
                                );
                              }
                            }
                          },
                          activeColor: Colors.blue.shade600,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                          secondary: Icon(Icons.security, color: Colors.indigo.shade400),
                        ),
                      ],
                    );
                  },
                ),
                _buildBottomTile(
                  icon: Icons.folder_open_outlined,
                  iconColor: Colors.orange.shade600,
                  title: Provider.of<LinkProvider>(context).hasCustomStoragePathSync ? 'Change Storage Folder' : 'Pick Storage Folder',
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onStorageFolderTap?.call();
                  },
                ),
                if (_currentUser != null)
                  _buildBottomTile(
                    icon: Icons.logout,
                    iconColor: Colors.red.shade400,
                    title: 'Sign Out Account',
                    titleColor: Colors.red.shade400,
                    onTap: _handleSignOut,
                  ),
                const Divider(),
                Consumer<LinkProvider>(
                  builder: (context, provider, child) {
                    if (!provider.isProUser) return const SizedBox.shrink();
                    return _buildBottomTile(
                      icon: Icons.bug_report,
                      iconColor: Colors.deepPurple,
                      title: 'DEBUG: Disable Pro',
                      titleColor: Colors.deepPurple,
                      onTap: () {
                        provider.removePro();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(duration: const Duration(seconds: 2), content: Text('Pro status removed for testing.')),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF7E22CE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: _currentUser != null
          ? _buildSignedInHeader()
          : _buildSignedOutHeader(),
    );
  }

  Widget _buildSignedInHeader() {
    final photoUrl = _currentUser?.photoUrl;
    final name = _currentUser?.displayName ?? 'Google User';
    final email = _currentUser?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white24,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(initial, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                email,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_done, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text('Drive Connected', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignedOutHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.link, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        Text('Link Saver', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        Text('Sign in to enable Google Drive backup', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 14),
        _isLoading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : ElevatedButton.icon(
                onPressed: _handleSignIn,
                icon: const Icon(Icons.login, size: 18),
                label: Text('Sign in with Google', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E40AF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  elevation: 0,
                ),
              ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _getThemeSubtitle(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;
    if (themeMode == ThemeMode.light) return 'Light Mode';
    if (themeMode == ThemeMode.dark) return 'Dark Mode';
    return 'System Default';
  }

  void _showAppearanceDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Appearance', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text('System Default', style: GoogleFonts.poppins()),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (val) {
                if (val != null) themeProvider.setThemeMode(val);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('Light Mode', style: GoogleFonts.poppins()),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (val) {
                if (val != null) themeProvider.setThemeMode(val);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('Dark Mode', style: GoogleFonts.poppins()),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (val) {
                if (val != null) themeProvider.setThemeMode(val);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 20),
                if (trailing != null) trailing,
              ],
            ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
