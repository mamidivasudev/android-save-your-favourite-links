import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/link_provider.dart';
import '../services/google_drive_service.dart';
import 'premium_screen.dart';

class GoogleDriveDialog extends StatefulWidget {
  const GoogleDriveDialog({super.key});

  @override
  State<GoogleDriveDialog> createState() => _GoogleDriveDialogState();
}

class _GoogleDriveDialogState extends State<GoogleDriveDialog> {
  bool _isLoading = true;
  bool _isBusy = false;
  bool _isSignedIn = false;
  bool _autoSyncEnabled = false;
  String? _accountEmail;
  DateTime? _lastSync;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              '$featureName $emoji',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Upgrade to Pro', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Maybe later', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadState() async {
    final provider = context.read<LinkProvider>();
    final signedIn = await provider.isGoogleDriveSignedIn();
    final email = signedIn ? await provider.getGoogleDriveEmail() : null;
    final autoSync = await provider.getGoogleDriveAutoSyncEnabled();
    final lastSync = await provider.getGoogleDriveLastSync();

    if (!mounted) return;
    setState(() {
      _isSignedIn = signedIn;
      _accountEmail = email;
      _autoSyncEnabled = autoSync;
      _lastSync = lastSync;
      _isLoading = false;
    });
  }

  Future<void> _runAction(
    String busyLabel,
    Future<DriveSyncResult> Function() action,
  ) async {
    setState(() {
      _isBusy = true;
      _statusMessage = busyLabel;
    });

    final result = await action();

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _statusMessage = result.message;
      if (result.success && result.accountEmail != null) {
        _accountEmail = result.accountEmail;
      }
    });

    await _loadState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 2), content: Text(result.message ?? 'Done')),
    );
  }

  Future<void> _handleSignIn() async {
    await _runAction('Signing in...', () => context.read<LinkProvider>().signInToGoogleDrive());
  }

  Future<void> _handleSignOut() async {
    await _runAction('Signing out...', () => context.read<LinkProvider>().signOutFromGoogleDrive());
  }

  Future<void> _handleBackup() async {
    await _runAction('Backing up...', () => context.read<LinkProvider>().backupToGoogleDrive());
  }

  Future<void> _handleRestore() async {
    final provider = context.read<LinkProvider>();
    final localLinkCount = provider.links.length;
    final localCategoryCount = provider.categories.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Overwrite Local Data?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently replace your current local data with the Google Drive backup.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            if (localLinkCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '⚠️ You have $localLinkCount local ${localLinkCount == 1 ? 'link' : 'links'} and $localCategoryCount ${localCategoryCount == 1 ? 'category' : 'categories'} that will be overwritten.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Make sure you have backed up locally before restoring.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Yes, Restore', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _runAction('Restoring...', () => context.read<LinkProvider>().restoreFromGoogleDrive());
    }
  }


  Future<void> _handleSync() async {
    await _runAction('Syncing...', () => context.read<LinkProvider>().syncWithGoogleDrive());
  }

  String _formatLastSync(DateTime? time) {
    if (time == null) return 'Never';
    return '${time.day}/${time.month}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.cloud, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Google Drive', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignedIn ? 'Signed in' : 'Not signed in',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                        if (_accountEmail != null) ...[
                          const SizedBox(height: 4),
                          Text(_accountEmail!, style: GoogleFonts.poppins(fontSize: 13)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Last sync: ${_formatLastSync(_lastSync)}',
                          style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSignedIn) ...[
                    Consumer<LinkProvider>(
                      builder: (context, provider, child) {
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Text('Auto-sync', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              if (!provider.isProUser) ...[
                                const SizedBox(width: 6),
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
                          subtitle: Text(
                            provider.isProUser ? 'Sync on app start and after changes' : 'Upgrade to unlock',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          value: provider.isProUser ? _autoSyncEnabled : false,
                          onChanged: _isBusy
                              ? null
                              : (value) async {
                                  if (!provider.isProUser) {
                                    _showProFeatureDialog(
                                      context,
                                      icon: Icons.cloud_sync,
                                      color: Colors.blue.shade600,
                                      featureName: 'Auto Sync to Drive',
                                      description: 'Never worry about losing your data!\n\nAuto Sync instantly backs up every link directly to your Google Drive in the background.',
                                      emoji: '☁️',
                                    );
                                    return;
                                  }
                                  await context.read<LinkProvider>().setGoogleDriveAutoSyncEnabled(value);
                                  setState(() => _autoSyncEnabled = value);
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _ActionButton(
                      icon: Icons.cloud_upload,
                      label: 'Backup to Drive',
                      onPressed: _isBusy ? null : _handleBackup,
                    ),
                    _ActionButton(
                      icon: Icons.cloud_download,
                      label: 'Restore from Drive',
                      onPressed: _isBusy ? null : _handleRestore,
                    ),
                    _ActionButton(
                      icon: Icons.sync,
                      label: 'Sync now',
                      onPressed: _isBusy ? null : _handleSync,
                    ),
                    _ActionButton(
                      icon: Icons.logout,
                      label: 'Sign out',
                      onPressed: _isBusy ? null : _handleSignOut,
                      isDestructive: true,
                    ),
                  ] else
                    _ActionButton(
                      icon: Icons.login,
                      label: 'Sign in with Google',
                      onPressed: _isBusy ? null : _handleSignIn,
                    ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage!,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                  if (_isBusy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: isDestructive ? Colors.red : Colors.blue.shade800),
          label: Text(
            label,
            style: GoogleFonts.poppins(
              color: isDestructive ? Colors.red : Colors.blue.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
