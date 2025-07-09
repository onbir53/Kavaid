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
  
  AppLifecycleState? _previousState;
  bool _creditsServiceInitialized = false;
  bool _isInAppAction = false;
  
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // ----- GERİ EKLENEN ÜYELER -----
  bool get mounted => _interstitialAd != null;
  bool get isInterstitialAdAvailable => _interstitialAd != null;

  static String get bannerAdUnitId {
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/4451476746'
        : 'ca-app-pub-3375249639458473/4569259764';
  }

  static String get nativeAdUnitId {
    return Platform.isAndroid
        ? 'ca-app-pub-3375249639458473/8521867085'
        : 'ca-app-pub-3375249639458473/8521867085';
  }
  // ----- BİTİŞ -----

  Duration get _cooldownDuration => Duration(seconds: _geminiService.adCooldownSeconds);

  static String get interstitialAdUnitId {
    return 'ca-app-pub-3375249639458473/4972153248'; // Güncellendi
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

  // Reklam göstermeyi deneyen merkezi metot
  Future<void> _tryShowAd({required VoidCallback onAdDismissed, bool force = false}) async {
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

  // `forceShowInterstitialAd` için bir sarmalayıcı. Zaman kontrolü yapmaz.
  void forceShowInterstitialAd() {
    debugPrint('🎬 [AdLogic] Reklam gösterimi zorlanıyor (zaman kontrolü atlandı).');
    _tryShowAd(onAdDismissed: () {}, force: true);
  }

  // ARAMA YAPILDIĞINDA ÇAĞRILACAK METOT
  Future<void> onSearchAdRequest({required VoidCallback onAdDismissed}) async {
    final now = DateTime.now();
    
    // Faz 1: Başlangıç periyodu
    if (_lastAdShowTime == null) {
      // Sayaç süresi dolduysa ve bu ilk arama ise reklam göster.
      if (now.difference(_appStartTime!) > _cooldownDuration) {
        debugPrint('🎬 [AdLogic] Başlangıç sayacı bitti, ilk arama yapıldı. Reklam denemesi yapılıyor...');
        await _tryShowAd(onAdDismissed: onAdDismissed);
        return;
      }

      // Sayaç süresi dolmadıysa, 3 arama kuralını uygula.
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

    // Faz 2: Normal döngü
    if (now.difference(_lastAdShowTime!) > _cooldownDuration) {
      debugPrint('🎬 [AdLogic] Sayaç bitti ve arama yapıldı, reklam denemesi yapılıyor...');
      await _tryShowAd(onAdDismissed: onAdDismissed);
    } else {
      final timeSince = now.difference(_lastAdShowTime!);
      debugPrint('⏳ [AdLogic] Arama reklamı atlandı. Kalan süre: ${(_cooldownDuration - timeSince).inSeconds}s');
      onAdDismissed();
    }
  }

  void onAppStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _previousState != AppLifecycleState.resumed) {
      final now = DateTime.now();

      // Faz 1: Başlangıç periyodu. Geri dönüş her zaman reklamı dener.
      if (_lastAdShowTime == null) {
         debugPrint('🎬 [AdLogic] Başlangıç periyodunda uygulamaya dönüldü, reklam denemesi yapılıyor...');
         _tryShowAd(onAdDismissed: () {});
         _previousState = state; 
         return;
      }

      // Faz 2: Normal döngü
      if (now.difference(_lastAdShowTime!) > _cooldownDuration) {
        debugPrint('🎬 [AdLogic] Sayaç bitti ve uygulamaya dönüldü, reklam denemesi yapılıyor...');
        _tryShowAd(onAdDismissed: () {});
      }
    }
    _previousState = state;
  }

  // ----- GERİ EKLENEN YARDIMCI METOTLAR -----
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
  // ----- BİTİŞ -----
}