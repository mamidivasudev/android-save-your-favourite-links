import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/link_provider.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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

  void _handlePurchase(BuildContext context, String planName) async {
    await Provider.of<LinkProvider>(context, listen: false).unlockPro();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2), 
          content: Text('🎉 $planName Unlocked Successfully!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String title,
    required String price,
    required String duration,
    required String description,
    required bool isPopular,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _handlePurchase(context, title),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? Colors.amber.shade600 : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            width: isPopular ? 2 : 1,
          ),
          boxShadow: [
            if (isPopular)
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(duration, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
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
              'Choose the plan that works best for you and unlock the full power of your Link Vault.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              Icons.all_inclusive,
              'Unlimited Links',
              'Break the 50 link limit and save as many links as you want forever.',
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
            const SizedBox(height: 16),
            _buildPlanCard(
              context: context,
              title: 'Monthly',
              price: '₹29',
              duration: '/ month',
              description: 'Flexible, pay as you go.',
              isPopular: false,
            ),
            _buildPlanCard(
              context: context,
              title: 'Yearly',
              price: '₹149',
              duration: '/ year',
              description: 'Save 57% annually.',
              isPopular: false,
            ),
            _buildPlanCard(
              context: context,
              title: 'Lifetime',
              price: '₹299',
              duration: 'one-time',
              description: 'Pay once, yours forever.',
              isPopular: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Secure payment via Google Play',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
