import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // App Open reklamı için değişkenler
  AppOpenAd? _appOpenAd;
  bool _isLoadingAppOpenAd = false;
  bool _isShowingAppOpenAd = false;
  DateTime? _appOpenLoadTime;

  // Adaptive Banner için test reklamları ID'leri
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2435281174';
  
  // App Open reklamı için test ID'leri
  static const String _testAppOpenAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testAppOpenAdUnitIdIOS = 'ca-app-pub-3940256099942544/5575463023';
  
  // Banner reklam ID'si - Adaptive Banner destekli
  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Test ID'leri - Adaptive Banner destekli
      if (Platform.isAndroid) {
        return _testBannerAdUnitIdAndroid;
      } else if (Platform.isIOS) {
        return _testBannerAdUnitIdIOS;
      }
    }
    
    // Production ID'leri
    if (Platform.isAndroid) {
      return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Gerçek Android adaptive banner ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Gerçek iOS adaptive banner ID
    }
    
    // Fallback
    return _testBannerAdUnitIdAndroid;
  }

  // App Open reklam ID'si
  static String get appOpenAdUnitId {
    if (kDebugMode) {
      // Test ID'leri
      if (Platform.isAndroid) {
        return _testAppOpenAdUnitIdAndroid;
      } else if (Platform.isIOS) {
        return _testAppOpenAdUnitIdIOS;
      }
    }
    
    // Production ID'leri
    if (Platform.isAndroid) {
      return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Gerçek Android app open ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Gerçek iOS app open ID
    }
    
    // Fallback
    return _testAppOpenAdUnitIdAndroid;
  }

  // AdMob'u başlat - sadece mobil platformlarda
  static Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('⚠️ AdMob web platformunda desteklenmiyor');
      return;
    }
    
    try {
      await MobileAds.instance.initialize();
      debugPrint('✅ AdMob başlatıldı');
      
      // App Open reklamını yükle
      _instance.loadAppOpenAd();
    } catch (e) {
      debugPrint('❌ AdMob başlatılamadı: $e');
    }
  }

  // App Open reklamını yükle
  void loadAppOpenAd() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    if (_isLoadingAppOpenAd || isAppOpenAdAvailable) {
      return;
    }

    _isLoadingAppOpenAd = true;
    debugPrint('🔄 App Open reklamı yükleniyor...');

    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          debugPrint('✅ App Open reklamı yüklendi');
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _isLoadingAppOpenAd = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ App Open reklamı yüklenemedi: ${error.message}');
          _isLoadingAppOpenAd = false;
        },
      ),
    );
  }

  // App Open reklamını göster
  void showAppOpenAd() {
    if (!isAppOpenAdAvailable || _isShowingAppOpenAd) {
      debugPrint('⚠️ App Open reklamı gösterilemiyor');
      loadAppOpenAd(); // Yeni reklam yükle
      return;
    }

    _isShowingAppOpenAd = true;
    debugPrint('📱 App Open reklamı gösteriliyor');

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd ad) {
        debugPrint('📱 App Open reklamı tam ekran gösterildi');
      },
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        debugPrint('📱 App Open reklamı kapatıldı');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd(); // Yeni reklam yükle
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        debugPrint('❌ App Open reklamı gösterilemedi: ${error.message}');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd(); // Yeni reklam yükle
      },
    );

    _appOpenAd!.show();
  }

  // App Open reklamının kullanılabilir olup olmadığını kontrol et
  bool get isAppOpenAdAvailable {
    if (_appOpenAd == null) return false;
    
    // Reklam 4 saatten eskiyse geçersiz
    if (_appOpenLoadTime != null && 
        DateTime.now().difference(_appOpenLoadTime!).inHours >= 4) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      return false;
    }
    
    return true;
  }

  // App lifecycle için - uygulama arka plana geçtiğinde/öne çıktığında
  void onAppStateChanged(bool isAppInForeground) {
    if (isAppInForeground) {
      // Uygulama öne çıktığında reklam göster
      showAppOpenAd();
    }
  }
} 