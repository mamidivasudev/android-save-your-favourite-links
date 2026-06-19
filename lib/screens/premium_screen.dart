import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/link_provider.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.amber.shade600, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium, size: 64, color: Colors.amber),
            const SizedBox(height: 8),
            Text(
              'Upgrade to Pro',
              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock the full power of your Link Saver. One-time payment, lifetime access.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildFeatureRow(
              Icons.all_inclusive,
              'Unlimited Links',
              'Break the 20 link limit and save as many links as you want forever.',
            ),
            _buildFeatureRow(
              Icons.block,
              'Ad-Free Experience',
              'Enjoy a completely clean interface with absolutely no banner ads.',
            ),
            _buildFeatureRow(
              Icons.image_outlined,
              'Link Previews',
              'See beautiful website thumbnail previews for every saved link at a glance.',
            ),
            _buildFeatureRow(
              Icons.cloud_sync,
              'Auto Sync to Drive',
              'Automatically backup your links to Google Drive in the background.',
            ),
            _buildFeatureRow(
              Icons.fingerprint,
              'Biometric App Lock',
              'Secure your private links with FaceID or Fingerprint authentication.',
            ),
            _buildFeatureRow(
              Icons.push_pin,
              'Pin to Top',
              'Pin your most important links to the absolute top of the list.',
            ),
            _buildFeatureRow(
              Icons.lock,
              'Lock Individual Links',
              'Lock specific private links so they cannot be opened, edited, or shared without your fingerprint.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  await Provider.of<LinkProvider>(context, listen: false).unlockPro();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(duration: const Duration(seconds: 2), 
                        content: Text('🎉 Pro Unlocked Successfully!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: Text(
                  'Unlock Lifetime Access for ₹299',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No recurring subscriptions. Pay once, use forever.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
