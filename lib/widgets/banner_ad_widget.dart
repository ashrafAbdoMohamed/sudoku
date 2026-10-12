import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// Anchored adaptive banner sized to the screen width.
/// Takes no space when ads aren't initialized or the ad fails to load.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _failed = false;
  AdSize? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs MediaQuery, so it can't run in initState
    if (_bannerAd == null && !_failed) _loadAd();
  }

  Future<void> _loadAd() async {
    final adService = AdService();
    if (!adService.isInitialized) return;

    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ?? AdSize.banner;
    if (!mounted || _bannerAd != null) return;

    _size = size;
    _bannerAd = adService.createBannerAd(
      size: size,
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() => _isAdLoaded = true);
        }
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('BannerAdWidget: Failed to load - $error');
        ad.dispose();
        if (mounted) setState(() => _failed = true);
      },
    );

    setState(() {}); // Reserve the slot while loading
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _size == null) return const SizedBox.shrink();

    // Reserve the banner's height while loading to prevent a layout jump
    return SizedBox(
      width: _size!.width.toDouble(),
      height: _size!.height.toDouble(),
      child: _isAdLoaded ? AdWidget(ad: _bannerAd!) : null,
    );
  }
}
