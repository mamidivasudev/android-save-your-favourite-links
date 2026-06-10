import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/link_provider.dart';
import '../services/google_drive_service.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Google Drive'),
        content: const Text(
          'This will replace your local links and categories with the Google Drive backup. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
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
                      color: Colors.blue.shade50,
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
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSignedIn) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Auto-sync', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Sync on app start and after changes',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      value: _autoSyncEnabled,
                      onChanged: _isBusy
                          ? null
                          : (value) async {
                              await context.read<LinkProvider>().setGoogleDriveAutoSyncEnabled(value);
                              setState(() => _autoSyncEnabled = value);
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
