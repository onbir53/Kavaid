import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import '../services/credits_service.dart';

class BannerAdWidget extends StatefulWidget {
  final Function(double)? onHeightChanged;
  final String? stableKey; // Widget'i stabil tutmak için key
  
  const BannerAdWidget({Key? key, this.onHeightChanged, this.stableKey}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => BannerAdWidgetState();
}

class BannerAdWidgetState extends State<BannerAdWidget> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  AdSize? _adSize;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 3);
  final CreditsService _creditsService = CreditsService();
  bool _isVisible = true;

  @override
  bool get wantKeepAlive => true; // Banner'ı canlı tut - performans için

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerAd();
    
    // İlk placeholder yüksekliğini bildir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onHeightChanged != null) {
        widget.onHeightChanged!(50.0); // Placeholder yüksekliği
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Uygulama lifecycle değişimlerinde banner'ı yeniden yükleme
    // Sadece uzun süre arka plandaysa yenile
    if (state == AppLifecycleState.resumed && !_isAdLoaded) {
      debugPrint('📱 Uygulama foreground dondugu zaman banner kontrol ediliyor');
      // Sadece reklam yüklü değilse yeniden yükle
      if (_bannerAd == null && _retryCount < _maxRetries) {
        _loadBannerAd();
      }
    }
  }

  @override
  void deactivate() {
    // Widget deactivate olduğunda banner'ı dispose etme
    // Sadece visibility'yi false yap
    _isVisible = false;
    super.deactivate();
  }

  @override
  void activate() {
    // Widget yeniden activate olduğunda visibility'yi true yap
    _isVisible = true;
    // Banner zaten yüklüyse tekrar yükleme
    if (_bannerAd == null && _retryCount < _maxRetries && !_isAdLoaded) {
      _loadBannerAd();
    }
    super.activate();
  }

  Future<void> _loadBannerAd() async {
    // Premium kullanıcılar için reklam yükleme
    if (_creditsService.isPremium) {
      debugPrint('👑 Premium kullanıcı - Banner reklam yüklenmeyecek');
      if (widget.onHeightChanged != null) {
        widget.onHeightChanged!(0.0);
      }
      return;
    }
    
    // Web'de veya desteklenmeyen platformlarda reklam yükleme
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      if (widget.onHeightChanged != null) {
        widget.onHeightChanged!(0.0);
      }
      return;
    }

    // Önceki banneri dispose et
    await _bannerAd?.dispose();
    if (mounted) {
      setState(() {
        _bannerAd = null;
        _isAdLoaded = false;
        _adSize = null;
      });
    }

    // Ekran genişliğini al - tam genişlik
    final screenWidth = MediaQuery.of(context).size.width;
    debugPrint('🖥️ Ekran genişliği: $screenWidth');
    
    // Adaptive Banner boyutunu al - tam ekran genişliği
    final AdSize? adaptiveSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      screenWidth.truncate(),
    );

    if (adaptiveSize == null) {
      debugPrint('❌ Adaptive banner boyutu alınamadı');
      _handleLoadError();
      return;
    }

    debugPrint('📏 Adaptive banner boyutu: ${adaptiveSize.width}x${adaptiveSize.height}');

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: adaptiveSize,
      request: const AdRequest(
        nonPersonalizedAds: false, // Kişiselleştirilmiş reklamlar
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          debugPrint('📱 Adaptive Banner reklam yüklendi');
          
          // Banner yüklendikten sonra gerçek boyutunu al
          final BannerAd bannerAd = ad as BannerAd;
          final AdSize? platformSize = await bannerAd.getPlatformAdSize();
          
          if (platformSize == null) {
            debugPrint('❌ Platform ad boyutu alınamadı');
            return;
          }

          debugPrint('📏 Platform banner boyutu: ${platformSize.width}x${platformSize.height}');

          if (mounted) {
            setState(() {
              _bannerAd = bannerAd;
              _isAdLoaded = true;
              _adSize = platformSize;
              _retryCount = 0; // Başarılı yüklemede retry sayacını sıfırla
            });
          }
          
          // Ana ekrana yükseklik değişikliğini bildir
          if (widget.onHeightChanged != null) {
            widget.onHeightChanged!(platformSize.height.toDouble());
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Adaptive Banner reklam yüklenemedi: ${error.message}');
          ad.dispose();
          _handleLoadError();
        },
        onAdOpened: (ad) {
          debugPrint('📱 Banner reklama tıklandı');
        },
        onAdClosed: (ad) {
          debugPrint('📱 Banner reklam kapandı');
        },
        onAdImpression: (ad) {
          debugPrint('👁️ Banner reklam görüntülendi');
        },
      ),
    );

    await _bannerAd?.load();
  }

  void _handleLoadError() {
    if (mounted) {
      setState(() {
        _bannerAd = null;
        _isAdLoaded = false;
        _adSize = null;
      });
    }
    
    // Retry mantığı
    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint('🔄 Banner reklam tekrar denenecek ($_retryCount/$_maxRetries)');
      Future.delayed(_retryDelay * _retryCount, () {
        if (mounted) {
          _loadBannerAd();
        }
      });
    } else {
      debugPrint('❌ Banner reklam maksimum deneme sayısına ulaştı');
      // Hata durumunda 0 yükseklik bildir
      if (widget.onHeightChanged != null) {
        widget.onHeightChanged!(0.0);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için
    
    // Premium kullanıcılar için boş alan döndür
    if (_creditsService.isPremium) {
      return const SizedBox.shrink();
    }
    
    // Web'de veya desteklenmeyen platformlarda boş alan döndür
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const SizedBox.shrink();
    }

    // Reklam yüklü ve boyut bilgisi varsa göster
    if (_bannerAd != null && _isAdLoaded && _adSize != null) {
      return Container(
        width: double.infinity, // Tam ekran genişliği
        height: _adSize!.height.toDouble(),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Center( // AdWidget'ı ortala
          child: SizedBox(
            width: _adSize!.width.toDouble(),
            height: _adSize!.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      );
    } else if (_retryCount < _maxRetries) {
      // Reklam yüklenene kadar ve retry devam ederken minimal placeholder
      return Container(
        width: double.infinity, // Tam ekran genişliği
        height: 50,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E8E93)),
            ),
          ),
        ),
      );
    } else {
      // Maksimum retry sonrası hiçbir şey gösterme
      return const SizedBox.shrink();
    }
  }
} 