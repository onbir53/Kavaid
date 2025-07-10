import 'dart:io';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'credits_service.dart';
import 'gemini_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal() {
    _appStartTime = DateTime.now();
    _initializeCreditsListener();
  }

  final CreditsService _creditsService = CreditsService();
  final GeminiService _geminiService = GeminiService();

  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitialAd = false;
  bool _isShowingAd = false;
  
  DateTime? _lastAdShowTime;
  DateTime? _appStartTime;
  int _searchCountInGracePeriod = 0;
  bool _didEnterBackground = false;
  
  AppLifecycleState? _previousState;
  bool _creditsServiceInitialized = false;
  bool _isInAppAction = false;
  
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // --- Gerekli Üyeler ---
  bool get mounted => _interstitialAd != null;
  bool get isInterstitialAdAvailable => _interstitialAd != null;

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/4451476746'
        : 'ca-app-pub-3375249639458473/4569259764';
  }

  static String get nativeAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110'
          : 'ca-app-pub-3940256099942544/3986624511';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/8521867085'
        : 'ca-app-pub-3375249639458473/8521867085';
  }
  // --- Bitiş ---

  Duration get _cooldownDuration => Duration(seconds: _geminiService.adCooldownSeconds);

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    return 'ca-app-pub-3375249639458473/4972153248';
  }

  void _initializeCreditsListener() {
    _creditsService.addListener(_handleCreditsChange);
    _creditsServiceInitialized = true;
    _handleCreditsChange();
  }

  void dispose() {
    _creditsService.removeListener(_handleCreditsChange);
    _interstitialAd?.dispose();
  }

  void _handleCreditsChange() {
    if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree) {
      loadInterstitialAd();
    } else {
      _interstitialAd?.dispose();
      _interstitialAd = null;
    }
  }

  void loadInterstitialAd() {
    if (_isLoadingInterstitialAd || _interstitialAd != null) return;
    _isLoadingInterstitialAd = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitialAd = false;
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitialAd = false;
        },
      ),
    );
  }

  Future<void> _tryShowAd({required VoidCallback onAdDismissed}) async {
    if (_interstitialAd == null || _isShowingAd) {
      onAdDismissed();
      return;
    }
    
    _isShowingAd = true;
    _lastAdShowTime = DateTime.now();
    _searchCountInGracePeriod = 0;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed();
      },
    );
    await _interstitialAd!.show();
  }
  
  void forceShowInterstitialAd() {
    debugPrint('🎬 [AdLogic] Reklam gösterimi zorlanıyor (zaman kontrolü atlandı).');
    _tryShowAd(onAdDismissed: () {});
  }

  Future<void> onSearchAdRequest({required VoidCallback onAdDismissed}) async {
    final now = DateTime.now();
    
    if (_lastAdShowTime == null) {
      if (now.difference(_appStartTime!) > _cooldownDuration) {
        debugPrint('🎬 [AdLogic] Başlangıç sayacı bitti, ilk arama yapıldı. Reklam denemesi yapılıyor...');
        await _tryShowAd(onAdDismissed: onAdDismissed);
        return;
      }

      _searchCountInGracePeriod++;
      debugPrint('ℹ️ [AdLogic] Başlangıç periyodunda arama yapıldı. Arama sayısı: $_searchCountInGracePeriod');
      if (_searchCountInGracePeriod >= 3) {
        debugPrint('🎬 [AdLogic] Başlangıç periyodunda 3. arama yapıldı, reklam denemesi yapılıyor...');
        await _tryShowAd(onAdDismissed: onAdDismissed);
      } else {
        onAdDismissed();
      }
      return;
    }

    if (now.difference(_lastAdShowTime!) > _cooldownDuration) {
      debugPrint('🎬 [AdLogic] Sayaç bitti ve arama yapıldı, reklam denemesi yapılıyor...');
      await _tryShowAd(onAdDismissed: onAdDismissed);
    } else {
      final timeSince = now.difference(_lastAdShowTime!);
      debugPrint('⏳ [AdLogic] Arama reklamı atlandı. Kalan süre: ${(_cooldownDuration - timeSince).inSeconds}s');
      onAdDismissed();
    }
  }

  // KELİME KARTI AÇILDIĞINDA ÇAĞRILACAK METOT
  Future<void> onWordCardOpenedAdRequest() async {
    final now = DateTime.now();
    
    // Faz 1: Başlangıç periyodu
    if (_lastAdShowTime == null) {
      // Sayaç bittiyse, bu eylem ilk reklamı tetikleyebilir.
      if (now.difference(_appStartTime!) > _cooldownDuration) {
        debugPrint('🎬 [AdLogic] Başlangıç sayacı bitti ve bir kelime kartı açıldı, reklam denemesi yapılıyor...');
        await _tryShowAd(onAdDismissed: () {});
      } else {
        // Sayaç devam ederken kelime kartı açmak reklam tetiklemez.
        debugPrint('🤫 [AdLogic] Kelime kartı reklamı atlandı: "Hoş Geldin" sayacı henüz bitmedi.');
      }
      return;
    }

    // Faz 2: Normal döngü
    if (now.difference(_lastAdShowTime!) > _cooldownDuration) {
      debugPrint('🎬 [AdLogic] Sayaç bitti ve bir kelime kartı açıldı, reklam denemesi yapılıyor...');
      await _tryShowAd(onAdDismissed: () {});
    } else {
      final remaining = _cooldownDuration - now.difference(_lastAdShowTime!);
      debugPrint('⏳ [AdLogic] Kelime kartı reklamı atlandı. Kalan süre: ${remaining.inSeconds}s');
    }
  }

  void onAppStateChanged(AppLifecycleState state) {
    debugPrint('📱 [Lifecycle] App state changed to: $state.');

    if (state == AppLifecycleState.paused) {
      debugPrint('🛑 [Lifecycle] App has been paused. Ad will be eligible on next resume.');
      _didEnterBackground = true;
    }

    if (state == AppLifecycleState.resumed) {
      debugPrint('▶️ [Lifecycle] App Resumed. Checking if it was truly in background...');
      
      if (_didEnterBackground) {
        debugPrint('✅ [AdLogic] App resumed from background. Proceeding with ad checks...');
        _didEnterBackground = false;

        if (_isShowingAd) {
          debugPrint('🤫 [AdLogic] Ad skipped: Another ad is already showing.');
          _previousState = state;
          return;
        }
        
        if (_isInAppAction) {
          debugPrint('🤫 [AdLogic] Ad skipped: An in-app action is in progress.');
          _previousState = state;
          return;
        }

        final now = DateTime.now();
        if (_lastAdShowTime == null) {
           debugPrint('🎬 [AdLogic] Başlangıç periyodunda uygulamaya dönüldü, reklam denemesi yapılıyor...');
           _tryShowAd(onAdDismissed: () {});
           _previousState = state;
           return;
        }

        if (now.difference(_lastAdShowTime!) > _cooldownDuration) {
          debugPrint('🎬 [AdLogic] Sayaç bitti ve uygulamaya dönüldü, reklam denemesi yapılıyor...');
          _tryShowAd(onAdDismissed: () {});
        } else {
           final remaining = _cooldownDuration - now.difference(_lastAdShowTime!);
           debugPrint('⏳ [AdLogic] Ad skipped: Cooldown not finished. Time remaining: ${remaining.inSeconds}s');
        }
      } else {
        debugPrint('🤫 [AdLogic] Ad skipped: App resumed from a minor interruption, not from background.');
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
    debugPrint('Interstitial Ad Loaded: $isInterstitialAdAvailable');
    debugPrint('Is In-App Action: $_isInAppAction');
    debugPrint('Last Interstitial Show Time: $_lastAdShowTime');
    debugPrint('Cooldown Duration: ${_cooldownDuration.inSeconds}s');
    debugPrint('--------------------------');
  }
}