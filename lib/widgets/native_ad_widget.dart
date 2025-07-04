import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import '../services/admob_service.dart';
import '../services/credits_service.dart';
import '../services/analytics_service.dart';

// 🚀 PERFORMANCE: Static template style cache
class _NativeAdStyleCache {
  static NativeTemplateStyle? _cachedLightStyle;
  static NativeTemplateStyle? _cachedDarkStyle;
  
  static NativeTemplateStyle getLightStyle() {
    _cachedLightStyle ??= NativeTemplateStyle(
      templateType: TemplateType.medium,
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
  
  static NativeTemplateStyle getDarkStyle() {
    _cachedDarkStyle ??= NativeTemplateStyle(
      templateType: TemplateType.medium,
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

// 🚀 PERFORMANCE: Visibility detector widget
class _VisibilityDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onVisible;
  final String tag;
  
  const _VisibilityDetector({
    required this.child,
    required this.onVisible,
    required this.tag,
  });

  @override
  State<_VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<_VisibilityDetector> {
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    // Widget build edildikten sonra visibility kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!_hasTriggered && mounted) {
      final renderObject = context.findRenderObject() as RenderBox?;
      if (renderObject != null && renderObject.hasSize) {
        final position = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // Widget ekranda görünüyorsa
        if (position.dy < screenHeight && position.dy + size.height > 0) {
          _hasTriggered = true;
          debugPrint('🔍 [VISIBILITY] Native ad görünür oldu, yükleme tetikleniyor...');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onVisible();
          });
        } else {
          debugPrint('🔍 [VISIBILITY] Native ad henüz görünür değil, bekliyor...');
          // 500ms sonra tekrar kontrol et
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_hasTriggered) {
              _checkVisibility();
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (!_hasTriggered) {
          _checkVisibility();
        }
        return false;
      },
      child: widget.child,
    );
  }
}

class NativeAdWidget extends StatefulWidget {
  final String? adUnitId;
  final bool enablePerformanceMode; // Performans modu
  
  const NativeAdWidget({
    super.key,
    this.adUnitId,
    this.enablePerformanceMode = false, // Varsayılan olarak kapalı - direkt yükleme
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> with AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  bool _isLoading = false;
  bool _isVisible = false;
  bool _hasLoadStarted = false;
  int _retryCount = 0;
  static const int _maxRetries = 1; // Retry sayısını azalttım
  static const Duration _retryDelay = Duration(seconds: 3);
  final CreditsService _creditsService = CreditsService();
  Widget? _cachedAdWidget; // 🚀 PERFORMANCE: AdWidget cache

  @override
  bool get wantKeepAlive => false; // 🚀 PERFORMANCE: KeepAlive'ı kapattım, gereksiz memory kullanımı

  @override
  void initState() {
    super.initState();
    
    debugPrint('🔄 [NATIVE AD] InitState - Performance mode: ${widget.enablePerformanceMode}');
    
    // 🚀 PERFORMANCE: Sadece premium değilse ve platform uygunsa devam et
    if (_shouldShowAd()) {
      if (!widget.enablePerformanceMode) {
        // Performance mode kapalıysa direkt yükle
        debugPrint('📱 [NATIVE AD] Direkt yükleme modu - hemen yükleniyor...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadNativeAd();
          }
        });
      } else {
        debugPrint('⏱️ [NATIVE AD] Performans modu - visibility detection bekleniyor...');
        // Performance mode açıksa visibility detection bekler
      }
    } else {
      debugPrint('🚫 [NATIVE AD] Reklam gösterilmeyecek - Premium/Web/UnsupportedPlatform');
    }
  }

  bool _shouldShowAd() {
    if (kIsWeb) {
      debugPrint('🚫 [NATIVE AD] Web platformunda reklam gösterilmez');
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.android && 
        defaultTargetPlatform != TargetPlatform.iOS) {
      debugPrint('🚫 [NATIVE AD] Desteklenmeyen platform: $defaultTargetPlatform');
      return false;
    }
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) {
      debugPrint('🚫 [NATIVE AD] Premium/Reklamsız kullanıcı - reklam gösterilmez');
      return false;
    }
    debugPrint('✅ [NATIVE AD] Reklam gösterilebilir');
    return true;
  }

  void _onVisible() {
    if (!_isVisible && !_hasLoadStarted && _shouldShowAd()) {
      _isVisible = true;
      _hasLoadStarted = true;
      
      // 🚀 PERFORMANCE: Kısa delay ile yükle (UI thread'i bloklamayalım)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _loadNativeAd();
        }
      });
    }
  }

  void _loadNativeAd() {
    if (!_shouldShowAd() || _isLoading || _nativeAdIsLoaded) return;
    
    setState(() {
      _isLoading = true;
    });

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId ?? AdMobService.nativeAdUnitId,
      request: const AdRequest(
        nonPersonalizedAds: false,
      ),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            // 🚀 PERFORMANCE: AdWidget'ı cache'le
            _cachedAdWidget = AdWidget(ad: _nativeAd!);
            
            setState(() {
              _nativeAdIsLoaded = true;
              _isLoading = false;
              _retryCount = 0;
            });
            
            AnalyticsService.logAdImpression('native', adUnitId: widget.adUnitId ?? AdMobService.nativeAdUnitId);
          }
          debugPrint('✅ Native reklam yüklendi (performans modu: ${widget.enablePerformanceMode})');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('❌ Native reklam yüklenemedi: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _nativeAdIsLoaded = false;
              _isLoading = false;
              _cachedAdWidget = null;
            });
            _handleLoadError();
          }
        },
        onAdClicked: (Ad ad) {
          debugPrint('📱 Native reklama tıklandı');
          AnalyticsService.logAdClick('native', adUnitId: widget.adUnitId ?? AdMobService.nativeAdUnitId);
        },
        onAdImpression: (Ad ad) {
          debugPrint('👁️ Native reklam görüntülendi');
        },
      ),
      nativeTemplateStyle: isDarkMode 
          ? _NativeAdStyleCache.getDarkStyle()
          : _NativeAdStyleCache.getLightStyle(),
    )..load();
  }

  void _handleLoadError() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint('🔄 Native reklam tekrar denenecek ($_retryCount/$_maxRetries)');
      Future.delayed(_retryDelay * _retryCount, () {
        if (mounted) {
          _loadNativeAd();
        }
      });
    } else {
      debugPrint('❌ Native reklam maksimum deneme sayısına ulaştı');
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _cachedAdWidget = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (!_shouldShowAd()) {
      return const SizedBox.shrink();
    }
    
    // Reklam yüklü değilse ve maksimum retry'a ulaşıldıysa hiçbir şey gösterme
    if (!_nativeAdIsLoaded && _retryCount >= _maxRetries) {
      return const SizedBox.shrink();
    }
    
    // 🚀 PERFORMANCE: Performans modu açıksa visibility detection kullan
    if (widget.enablePerformanceMode && !_isVisible) {
      return _VisibilityDetector(
        tag: 'native_ad_${widget.adUnitId ?? 'default'}',
        onVisible: _onVisible,
        child: Container(
          height: 126, // Placeholder height
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1C1C1E).withOpacity(0.5)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'Reklam yükleniyor...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }
    
    return RepaintBoundary(
      child: _buildAdContent(),
    );
  }
  
  Widget _buildAdContent() {
    if (!_nativeAdIsLoaded || _nativeAd == null || _cachedAdWidget == null) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 🚀 PERFORMANCE: Minimalist widget tree
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode 
              ? const Color(0xFF48484A).withOpacity(0.3)
              : const Color(0xFFE5E5EA).withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 🚀 PERFORMANCE: Cached AdWidget
            Positioned.fill(
              child: _cachedAdWidget!,
            ),
            // Reklam etiketi - optimized
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Reklam',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 