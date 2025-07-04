import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'dart:math';
import '../services/admob_service.dart';
import '../services/credits_service.dart';
import '../services/turkce_analytics_service.dart';

// PERFORMANCE: Static template style cache for reusing styles.
class _NativeAdStyleCache {
  static NativeTemplateStyle? _cachedLightStyle;
  static NativeTemplateStyle? _cachedDarkStyle;

  static NativeTemplateStyle getLightStyle(BuildContext context) {
    _cachedLightStyle ??= NativeTemplateStyle(
      templateType: TemplateType.medium,
      mainBackgroundColor: Colors.white,
      cornerRadius: 8,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        backgroundColor: const Color(0xFF007AFF),
        style: NativeTemplateFontStyle.normal,
        size: 14,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.black87,
        style: NativeTemplateFontStyle.bold,
        size: 16,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.black54,
        style: NativeTemplateFontStyle.normal,
        size: 14,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.black54,
        style: NativeTemplateFontStyle.normal,
        size: 12,
      ),
    );
    return _cachedLightStyle!;
  }

  static NativeTemplateStyle getDarkStyle(BuildContext context) {
    _cachedDarkStyle ??= NativeTemplateStyle(
      templateType: TemplateType.medium,
      mainBackgroundColor: const Color(0xFF1C1C1E),
      cornerRadius: 8,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        backgroundColor: const Color(0xFF007AFF),
        style: NativeTemplateFontStyle.normal,
        size: 14,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        style: NativeTemplateFontStyle.bold,
        size: 16,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white70,
        style: NativeTemplateFontStyle.normal,
        size: 14,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white60,
        style: NativeTemplateFontStyle.normal,
        size: 12,
      ),
    );
    return _cachedDarkStyle!;
  }
}

// MAIN: Optimized Native Ad Widget
class NativeAdWidget extends StatefulWidget {
  final String? adUnitId;

  const NativeAdWidget({
    super.key,
    this.adUnitId,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 5);
  final CreditsService _creditsService = CreditsService();
  Widget? _cachedAdWidget;

  @override
  bool get wantKeepAlive => _nativeAdIsLoaded;

  @override
  void initState() {
    super.initState();
    _loadAdWithDelay();
  }

  void _loadAdWithDelay() {
    // A small delay before loading the ad can prevent jank during screen transitions.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadNativeAd();
      }
    });
  }

  bool _shouldShowAd() {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) return false;
    return !_creditsService.isPremium && !_creditsService.isLifetimeAdsFree;
  }

  void _loadNativeAd() {
    if (!_shouldShowAd() || _isLoading || _nativeAdIsLoaded) return;

    setState(() {
      _isLoading = true;
    });

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId ?? AdMobService.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('✅ Native ad loaded successfully.');
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
              _isLoading = false;
              _retryCount = 0;
              _cachedAdWidget = AdWidget(ad: _nativeAd!);
            });
            updateKeepAlive();
            TurkceAnalyticsService.reklamGoruntulendi('native');
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('❌ Native ad failed to load: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _handleLoadError();
          }
        },
        onAdClicked: (Ad ad) => TurkceAnalyticsService.reklamTiklandi('native'),
      ),
      nativeTemplateStyle: isDarkMode
          ? _NativeAdStyleCache.getDarkStyle(context)
          : _NativeAdStyleCache.getLightStyle(context),
    )..load();
  }

  void _handleLoadError() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint('🔄 Retrying native ad load ($_retryCount/$_maxRetries)...');
      final backoffDelay =
          Duration(milliseconds: (_retryDelay.inMilliseconds * pow(2, _retryCount - 1)).toInt());
      
      Future.delayed(backoffDelay, () {
        if (mounted) {
          _loadNativeAd();
        }
      });
    } else {
      debugPrint('❌ Reached max retries for native ad.');
      if (mounted) {
        setState(() {}); // Update UI to show empty space
      }
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_shouldShowAd() || (_retryCount >= _maxRetries && !_nativeAdIsLoaded)) {
      return const SizedBox.shrink();
    }

    if (_nativeAdIsLoaded && _cachedAdWidget != null) {
      return RepaintBoundary(
        child: Container(
          height: 120,
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1C1C1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF48484A).withOpacity(0.3)
                  : const Color(0xFFE5E5EA).withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _cachedAdWidget!,
          ),
        ),
      );
    }

    // FPS-friendly loading placeholder
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1C1E).withOpacity(0.3)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
          ),
        ),
      ),
    );
  }
}
