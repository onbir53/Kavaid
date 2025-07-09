import 'dart:io';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'credits_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal() {
    _initializeCreditsListener();
  }

  final CreditsService _creditsService = CreditsService();

  InterstitialAd? _interstitialAd;
  InterstitialAd? _aiSearchInterstitialAd;
  AppOpenAd? _appOpenAd;
  bool _isLoadingInterstitialAd = false;
  bool _isShowingAd = false;
  DateTime? _lastInterstitialShowTime;
  DateTime? _lastAiSearchAdShowTime;
  AppLifecycleState? _previousState;
  bool _creditsServiceInitialized = false;
  bool _isInAppAction = false;
  
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static Duration get _minTimeBetweenInterstitialAds => kDebugMode
      ? const Duration(seconds: 5)
      : const Duration(seconds: 60);

  bool get mounted => _interstitialAd != null || _aiSearchInterstitialAd != null;
  bool get isInterstitialAdAvailable => _interstitialAd != null;

  static String get bannerAdUnitId {
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/4451476746'
        : 'ca-app-pub-3375249639458473/4569259764'; // iOS ID'si için varsayılan
  }

  static String get interstitialAdUnitId {
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/4972153248'
        : 'ca-app-pub-3375249639458473/4972153248'; // iOS ID'si için varsayılan
  }

  static String get nativeAdUnitId {
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/8521867085'
        : 'ca-app-pub-3375249639458473/8521867085'; // iOS ID'si için varsayılan
  }

  static String get appOpenAdUnitId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/9257395921';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/5938393525'
        : 'ca-app-pub-3375249639458473/5938393525'; // iOS için de aynı ID'yi varsayalım
  }

  static String get aiSearchInterstitialAdUnitId {
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/9302952942'
        : 'ca-app-pub-3375249639458473/9302952942'; // iOS ID'si için varsayılan
  }

  void _initializeCreditsListener() {
    _creditsService.addListener(_handleCreditsChange);
    // İlk durumu hemen kontrol et
    _handleCreditsChange();
    _creditsServiceInitialized = true;
  }

  void dispose() {
    _creditsService.removeListener(_handleCreditsChange);
    _interstitialAd?.dispose();
    _aiSearchInterstitialAd?.dispose();
    _appOpenAd?.dispose();
  }

  void _handleCreditsChange() {
    if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree) {
      debugPrint('🔄 [AdMob] Premium/Reklamsız değil - Reklamlar yükleniyor...');
      loadInterstitialAd();
      loadAiSearchInterstitialAd();
      loadAppOpenAd(); // App Open Ad'i de yükle
    } else {
      debugPrint('✨ [AdMob] Premium/Reklamsız aktif - Reklamlar temizleniyor.');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _aiSearchInterstitialAd?.dispose();
      _aiSearchInterstitialAd = null;
      _appOpenAd?.dispose();
      _appOpenAd = null;
    }
  }

  void loadAppOpenAd() {
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) return;
    
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          debugPrint('✅ [AdMob] App Open Ad yüklendi.');
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ [AdMob] App Open Ad yüklenemedi: $error');
        },
      ),
    );
  }

  void showAppOpenAdIfAvailable() {
    if (_appOpenAd == null || _isShowingAd) {
      debugPrint('⚠️ [AdMob] App Open Ad gösterilemedi, hazır değil veya başka bir reklam gösterimde.');
      loadAppOpenAd();
      return;
    }

    if (_isInAppAction) {
      debugPrint('🤫 [AdMob] Uygulama içi işlem aktif, App Open Ad gösterilmiyor.');
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        debugPrint('🎬 [AdMob] App Open Ad gösterildi.');
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
        debugPrint('✅ [AdMob] App Open Ad kapatıldı.');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
        debugPrint('❌ [AdMob] App Open Ad gösterilemedi: $error');
      },
    );
    _appOpenAd!.show();
  }

  void loadInterstitialAd() {
    if (_isLoadingInterstitialAd || _interstitialAd != null) return;

    _isLoadingInterstitialAd = true;
    debugPrint('🚀 [AdMob] Normal Geçiş reklamı yükleniyor...');
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('✅ [AdMob] Normal Geçiş reklamı yüklendi.');
          _interstitialAd = ad;
          _isLoadingInterstitialAd = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ [AdMob] Normal Geçiş reklamı yüklenemedi: ${error.message}');
          _isLoadingInterstitialAd = false;
        },
      ),
    );
  }

  void forceShowInterstitialAd() {
    debugPrint('🎬 [AdMob] forceShowInterstitialAd metodu çağrıldı.');
    if (_interstitialAd == null || _isShowingAd) {
      debugPrint('⚠️ [AdMob] Zorunlu reklam gösterilemedi, hazır değil (null: ${_interstitialAd == null}) veya başka bir reklam gösterimde (showing: $_isShowingAd).');
      loadInterstitialAd();
      return;
    }
    
    _lastInterstitialShowTime = DateTime.now(); // Sadece normal reklamın zamanını kaydet
    _isShowingAd = true;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isShowingAd = false;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isShowingAd = false;
        loadInterstitialAd();
      }
    );
    _interstitialAd!.show();
  }

  void loadAiSearchInterstitialAd() {
    if (_aiSearchInterstitialAd != null) return;
    debugPrint('🚀 [AdMob] AI Arama Geçiş reklamı yükleniyor...');
    InterstitialAd.load(
      adUnitId: aiSearchInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('✅ [AdMob] AI Arama Geçiş reklamı yüklendi.');
          _aiSearchInterstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ [AdMob] AI Arama Geçiş reklamı yüklenemedi: ${error.message}');
          _aiSearchInterstitialAd = null;
        },
      ),
    );
  }

  Future<void> showAiSearchInterstitialAd({required VoidCallback onAdDismissed}) async {
    if (_aiSearchInterstitialAd == null) {
      debugPrint('⚠️ [AdMob] AI Arama Geçiş reklamı henüz hazır değil.');
      onAdDismissed();
      loadAiSearchInterstitialAd();
      return;
    }

    if (_isShowingAd) {
      debugPrint('⚠️ [AdMob] Başka bir reklam gösterimde, AI reklamı gösterilmiyor.');
      onAdDismissed();
      return;
    }

    _lastAiSearchAdShowTime = DateTime.now(); // Sadece AI reklamının zamanını kaydet
    _isShowingAd = true;
    _aiSearchInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('✅ [AdMob] AI Arama Geçiş reklamı kapatıldı.');
        ad.dispose();
        _aiSearchInterstitialAd = null;
        _isShowingAd = false;
        loadAiSearchInterstitialAd();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('❌ [AdMob] AI Arama Geçiş reklamı gösterilemedi: ${error.message}');
        ad.dispose();
        _aiSearchInterstitialAd = null;
        _isShowingAd = false;
        loadAiSearchInterstitialAd();
        onAdDismissed();
      },
    );

    debugPrint('🎬 [AdMob] AI Arama Geçiş reklamı gösteriliyor...');
    _aiSearchInterstitialAd!.show();
  }

  void onAppStateChanged(AppLifecycleState state) {
    debugPrint('📱 [Lifecycle] Uygulama durumu değişti: $state. Önceki durum: $_previousState');

    // Uygulama daha önce arka plandayken (paused veya inactive) şimdi öne geldiyse (resumed)
    if (state == AppLifecycleState.resumed && (_previousState == AppLifecycleState.paused || _previousState == AppLifecycleState.inactive)) {
      debugPrint('✅ [Lifecycle] Uygulama arka plandan geldi.');

      // 1. Adım: Başka bir reklam gösteriliyor mu?
      if (_isShowingAd) {
        debugPrint('🤫 [AdMob] Reklam atlandı: Başka bir reklam zaten gösterimde.');
        _previousState = state;
        return;
      }

      // 2. Adım: Kullanıcı premium mu?
      if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree) {
        debugPrint('💰 [AdMob] Kullanıcı premium değil. Zamanlama kontrol ediliyor...');
        
        // 3. Adım: Zamanlama uygun mu?
        if (_lastInterstitialShowTime == null || DateTime.now().difference(_lastInterstitialShowTime!) > _minTimeBetweenInterstitialAds) {
          debugPrint('⏰ [AdMob] Zamanlama koşulu uygun. Reklam gösterme deneniyor...');
          forceShowInterstitialAd();
        } else {
          final timeSinceLastAd = DateTime.now().difference(_lastInterstitialShowTime!);
          debugPrint('⏳ [AdMob] Reklam atlandı: Son reklamdan bu yana yeterli süre geçmedi. Geçen süre: ${timeSinceLastAd.inSeconds}s. Gerekli süre: ${_minTimeBetweenInterstitialAds.inSeconds}s.');
        }
      } else {
        debugPrint('✨ [AdMob] Reklam atlandı: Kullanıcı premium veya ömür boyu reklamsız kullanım hakkı var.');
      }
    }
    _previousState = state;
  }

  void setInAppActionFlag(String actionType) {
    debugPrint('🔒 [AdMob] In-app action flag SET: $actionType');
    _isInAppAction = true;
  }

  void clearInAppActionFlag() {
    debugPrint('🔓 [AdMob] In-app action flag CLEARED');
    _isInAppAction = false;
  }

  void debugAdStatus() {
    debugPrint('--- AdMob Debug Status ---');
    debugPrint('Premium: ${_creditsService.isPremium}');
    debugPrint('Lifetime Ads Free: ${_creditsService.isLifetimeAdsFree}');
    debugPrint('Interstitial Ad Loaded: ${isInterstitialAdAvailable}');
    debugPrint('AI Search Ad Loaded: ${_aiSearchInterstitialAd != null}');
    debugPrint('Is In-App Action: $_isInAppAction');
    debugPrint('Last Interstitial Show Time: $_lastInterstitialShowTime');
    debugPrint('Last AI Search Ad Show Time: $_lastAiSearchAdShowTime');
    debugPrint('--------------------------');
  }
}