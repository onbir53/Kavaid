import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import '../services/admob_service.dart';
import '../services/credits_service.dart';

class NativeAdWidget extends StatefulWidget {
  final String? adUnitId; // Özel ad unit ID kullanmak için
  
  const NativeAdWidget({
    super.key,
    this.adUnitId,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> with AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 2);
  final CreditsService _creditsService = CreditsService();

  @override
  bool get wantKeepAlive => _nativeAdIsLoaded; // Yüklü reklamı canlı tut

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
        defaultTargetPlatform == TargetPlatform.iOS) && !_creditsService.isPremium) {
      // Widget görünür olduğunda reklamı yükle (lazy loading)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadNativeAd();
        }
      });
    }
  }

  void _loadNativeAd() {
    // Premium kullanıcılar için reklam yükleme
    if (_creditsService.isPremium) {
      debugPrint('👑 Premium kullanıcı - Native reklam yüklenmeyecek');
      return;
    }
    
    if (_isLoading || _nativeAdIsLoaded) return;
    
    setState(() {
      _isLoading = true;
    });

    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId ?? AdMobService.nativeAdUnitId,
      request: const AdRequest(
        nonPersonalizedAds: false,
      ),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
              _isLoading = false;
              _retryCount = 0;
            });
          }
          debugPrint('✅ Native reklam yüklendi');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('❌ Native reklam yüklenemedi: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _nativeAdIsLoaded = false;
              _isLoading = false;
            });
            _handleLoadError();
          }
        },
        onAdClicked: (Ad ad) {
          debugPrint('📱 Native reklama tıklandı');
        },
        onAdImpression: (Ad ad) {
          debugPrint('👁️ Native reklam görüntülendi');
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
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
      ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Premium kullanıcılar için boş alan döndür
    if (_creditsService.isPremium) {
      return const SizedBox.shrink();
    }
    
    // Web'de veya desteklenmeyen platformlarda hiçbir şey gösterme
    if (kIsWeb || (!kReleaseMode && defaultTargetPlatform != TargetPlatform.android && 
        defaultTargetPlatform != TargetPlatform.iOS)) {
      return const SizedBox.shrink();
    }
    
    // Reklam yüklü değilse ve maksimum retry'a ulaşıldıysa hiçbir şey gösterme
    if (!_nativeAdIsLoaded && _retryCount >= _maxRetries) {
      return const SizedBox.shrink();
    }
    
    // RepaintBoundary ile performans optimizasyonu
    return RepaintBoundary(
      child: _buildAdContent(isDarkMode),
    );
  }
  
  Widget _buildAdContent(bool isDarkMode) {
    // Reklam yükleniyorsa veya retry devam ediyorsa hiçbir şey gösterme
    if (!_nativeAdIsLoaded || _nativeAd == null) {
      // 🚀 PERFORMANCE: Yüklenirken hiçbir şey gösterme
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
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
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 120,
                child: AdWidget(ad: _nativeAd!),
              ),
            ),
            // Reklam etiketi - sağ üst köşe
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? const Color(0xFF007AFF).withOpacity(0.2)
                      : const Color(0xFF007AFF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDarkMode 
                        ? const Color(0xFF007AFF).withOpacity(0.3)
                        : const Color(0xFF007AFF).withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Reklam',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode 
                        ? const Color(0xFF007AFF)
                        : const Color(0xFF007AFF).withOpacity(0.9),
                    letterSpacing: 0.2,
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