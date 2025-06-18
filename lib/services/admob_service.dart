import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'credits_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();
  
  final CreditsService _creditsService = CreditsService();

  // App Open reklamı için değişkenler
  AppOpenAd? _appOpenAd;
  bool _isLoadingAppOpenAd = false;
  bool _isShowingAppOpenAd = false;
  DateTime? _appOpenLoadTime;
  DateTime? _lastAppOpenShowTime;
  
  // Reklam frekans kontrolü için sabitler
  static const Duration _minTimeBetweenAppOpenAds = Duration(minutes: 5); // App Open reklamlar arası minimum süre
  static const Duration _appOpenAdExpiration = Duration(hours: 4); // App Open reklam geçerlilik süresi
  static const int _maxAdLoadRetries = 3; // Maksimum reklam yükleme deneme sayısı
  int _currentRetryCount = 0;

  // Adaptive Banner için test reklamları ID'leri
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2435281174';
  
  // App Open reklamı için test ID'leri
  static const String _testAppOpenAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testAppOpenAdUnitIdIOS = 'ca-app-pub-3940256099942544/5575463023';
  
  // Native reklam için test ID'leri
  static const String _testNativeAdUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeAdUnitIdIOS = 'ca-app-pub-3940256099942544/3986624511';
  
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

  // Native reklam ID'si
  static String get nativeAdUnitId {
    if (kDebugMode) {
      // Test ID'leri
      if (Platform.isAndroid) {
        return _testNativeAdUnitIdAndroid;
      } else if (Platform.isIOS) {
        return _testNativeAdUnitIdIOS;
      }
    }
    
    // Production ID'leri
    if (Platform.isAndroid) {
      return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Gerçek Android native ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Gerçek iOS native ID
    }
    
    // Fallback
    return _testNativeAdUnitIdAndroid;
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
      
      // Reklam optimizasyonu için ayarlar
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: kDebugMode ? ['YOUR_TEST_DEVICE_ID'] : [],
          maxAdContentRating: MaxAdContentRating.g, // Genel izleyici kitlesi
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        ),
      );
      
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
    
    // Premium kullanıcılar için reklam yükleme
    if (_creditsService.isPremium) {
      debugPrint('👑 Premium kullanıcı - Reklam yüklenmeyecek');
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
          _currentRetryCount = 0; // Başarılı yüklemede retry sayacını sıfırla
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ App Open reklamı yüklenemedi: ${error.message}');
          _isLoadingAppOpenAd = false;
          
          // Retry mantığı
          _currentRetryCount++;
          if (_currentRetryCount < _maxAdLoadRetries) {
            debugPrint('🔄 App Open reklamı tekrar denenecek (${_currentRetryCount}/$_maxAdLoadRetries)');
            Future.delayed(Duration(seconds: 2 * _currentRetryCount), () {
              loadAppOpenAd();
            });
          }
        },
      ),
    );
  }

  // App Open reklamını göster
  void showAppOpenAd() {
    // Premium kullanıcılar için reklam gösterme
    if (_creditsService.isPremium) {
      debugPrint('👑 Premium kullanıcı - Reklam gösterilmeyecek');
      return;
    }
    
    if (!isAppOpenAdAvailable || _isShowingAppOpenAd) {
      debugPrint('⚠️ App Open reklamı gösterilemiyor - Mevcut değil veya zaten gösteriliyor');
      loadAppOpenAd(); // Yeni reklam yükle
      return;
    }
    
    // Frekans kontrolü
    if (_lastAppOpenShowTime != null) {
      final timeSinceLastShow = DateTime.now().difference(_lastAppOpenShowTime!);
      if (timeSinceLastShow < _minTimeBetweenAppOpenAds) {
        debugPrint('⏱️ App Open reklamı çok yakın zamanda gösterildi. Bekleniyor...');
        return;
      }
    }

    _isShowingAppOpenAd = true;
    debugPrint('📱 App Open reklamı gösteriliyor');

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd ad) {
        debugPrint('📱 App Open reklamı tam ekran gösterildi');
        _lastAppOpenShowTime = DateTime.now();
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
    
    // Reklam süresi dolmuş mu kontrol et
    if (_appOpenLoadTime != null && 
        DateTime.now().difference(_appOpenLoadTime!) > _appOpenAdExpiration) {
      debugPrint('⏰ App Open reklamı süresi dolmuş, dispose ediliyor');
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
  
  // Tüm reklamları dispose et (uygulama kapanırken kullan)
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
} 