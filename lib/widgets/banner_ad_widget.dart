import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/link_provider.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // ─── AdMob Ad Unit IDs ────────────────────────────────────────────────────
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-4244050676400093/6782106745'   // Real Android Banner ID
      : 'ca-app-pub-3940256099942544/2934735716';  // iOS Test ID (if needed later)

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Only load the ad if the user is NOT a pro user.
    // However, since we access Provider in build, we just load it here 
    // to be safe, but we won't show it in the build method.
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if the user is a Pro User
    final isProUser = context.watch<LinkProvider>().isProUser;

    // If they are a Pro user, hide the ad completely.
    if (isProUser) {
      return const SizedBox.shrink();
    }

    // If they are a free user, show the ad (or a placeholder while loading)
    return SafeArea(
      child: SizedBox(
        width: _bannerAd?.size.width.toDouble() ?? MediaQuery.of(context).size.width,
        height: _bannerAd?.size.height.toDouble() ?? 50.0,
        child: _isLoaded && _bannerAd != null
            ? AdWidget(ad: _bannerAd!)
            : const SizedBox.shrink(), // Empty space while loading
      ),
    );
  }
}
