import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import '../services/credits_service.dart';

class BannerAdWidget extends StatefulWidget {
  final Function(double) onAdHeightChanged;
  final String? stableKey;

  const BannerAdWidget({
    Key? key,
    required this.onAdHeightChanged,
    this.stableKey,
  }) : super(key: key);

  @override
  State<BannerAdWidget> createState() => BannerAdWidgetState();
}

class BannerAdWidgetState extends State<BannerAdWidget>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  AdSize? _adSize;
  int _retryCount = 0;
  static const int _maxRetries = 5; // Arttırılmış deneme
  static const Duration _retryDelay = Duration(seconds: 5);
  final CreditsService _creditsService = CreditsService();
  bool _isVisible = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Credits service'i dinle
    _creditsService.addListener(_onCreditsChanged);
    
    // Başlangıçta yüksekliği 0 olarak bildir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onAdHeightChanged(0.0);
      }
    });
    
    // Credits service başlatıldıktan sonra reklam yükle
    _initializeAndLoadAd();
  }
  
  Future<void> _initializeAndLoadAd() async {
    // Credits service'in başlatılmasını bekle
    await _creditsService.initialize();
    
    // Şimdi reklam yükle
    if (mounted) {
      _loadBannerAd();
    }
  }
  
  void _onCreditsChanged() {
    // Premium durumu değiştiğinde reklamı güncelle
    if (_creditsService.isPremium && _bannerAd != null) {
      // Premium olduysa reklamı kaldır
      _disposeAd();
    } else if (!_creditsService.isPremium && _bannerAd == null && !_isAdLoaded) {
      // Premium değilse ve reklam yoksa yükle
      _loadBannerAd();
    }
  }
  
  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _adSize = null;
    widget.onAdHeightChanged(0.0);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isAdLoaded && !_creditsService.isPremium) {
      if (_bannerAd == null && _retryCount < _maxRetries) {
        _loadBannerAd();
      }
    }
  }

  @override
  void deactivate() {
    _isVisible = false;
    super.deactivate();
  }

  @override
  void activate() {
    _isVisible = true;
    if (_bannerAd == null && _retryCount < _maxRetries && !_isAdLoaded && !_creditsService.isPremium) {
      _loadBannerAd();
    }
    super.activate();
  }

  Future<void> _loadBannerAd() async {
    // Premium kontrolü - her zaman güncel değeri kontrol et
    if (_creditsService.isPremium) {
      debugPrint('👑 [BannerAd] Premium kullanıcı - Reklam yüklenmeyecek');
      if (mounted) widget.onAdHeightChanged(0.0);
      return;
    }

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      if (mounted) widget.onAdHeightChanged(0.0);
      return;
    }

    await _bannerAd?.dispose();
    if (mounted) {
      setState(() {
        _bannerAd = null;
        _isAdLoaded = false;
        _adSize = null;
      });
    }

    // Ekran genişliğini al
    if (!context.mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final adaptiveSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      screenWidth.truncate(),
    );

    if (adaptiveSize == null) {
      _handleLoadError();
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          if (!mounted) return;
          
          // Reklam yüklendikten sonra da premium kontrolü yap
          if (_creditsService.isPremium) {
            debugPrint('👑 [BannerAd] Reklam yüklendi ama kullanıcı premium - Reklam gösterilmeyecek');
            ad.dispose();
            return;
          }
          
          final bannerAd = ad as BannerAd;
          final platformSize = await bannerAd.getPlatformAdSize();
          if (platformSize == null) return;
          
          setState(() {
            _bannerAd = bannerAd;
            _isAdLoaded = true;
            _adSize = platformSize;
            _retryCount = 0;
          });
          widget.onAdHeightChanged(platformSize.height.toDouble());
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner reklam yüklenemedi: ${error.message}');
          ad.dispose();
          _handleLoadError();
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
      });
      widget.onAdHeightChanged(0.0);
    }

    if (_retryCount < _maxRetries && !_creditsService.isPremium) {
      _retryCount++;
      Future.delayed(_retryDelay, () {
        if (mounted && _isVisible && !_creditsService.isPremium) {
          _loadBannerAd();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _creditsService.removeListener(_onCreditsChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Build sırasında da premium kontrolü
    if (_creditsService.isPremium) {
      return const SizedBox.shrink();
    }

    if (_isAdLoaded && _bannerAd != null && _adSize != null) {
      return Container(
        width: _adSize!.width.toDouble(),
        height: _adSize!.height.toDouble(),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    
    return const SizedBox.shrink();
  }
} 