import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'credits_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal() {
    // Constructor'da credits service'i dinlemeye başla
    _initializeCreditsListener();
  }
  
  final CreditsService _creditsService = CreditsService();

  // App Open reklamı için değişkenler
  AppOpenAd? _appOpenAd;
  bool _isLoadingAppOpenAd = false;
  bool _isShowingAppOpenAd = false;
  DateTime? _appOpenLoadTime;
  DateTime? _lastAppOpenShowTime;
  
  // Uygulama lifecycle kontrolü için  
  bool _isFirstLaunch = true;
  DateTime? _lastPausedTime;
  bool _wasActuallyInBackground = false;
  AppLifecycleState? _previousState;
  bool _creditsServiceInitialized = false;
  int _backgroundToForegroundCount = 0; // Arka plandan öne geçiş sayacı
  
  // 3 saniye kuralı için sabit
  static const Duration _minBackgroundTime = Duration(seconds: 3);
  
  // Reklam frekans kontrolü için sabitler - 5 dakika minimum aralık
  static Duration get _minTimeBetweenAppOpenAds => kDebugMode 
      ? const Duration(minutes: 5) // Debug modda da 5 dakika minimum
      : const Duration(minutes: 5); // Production'da da 5 dakika minimum
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
      return 'ca-app-pub-3375249639458473/4451476746'; // Gerçek Android adaptive banner ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3375249639458473/4569259764'; // Gerçek iOS adaptive banner ID
    }
    
    // Fallback
    return _testBannerAdUnitIdAndroid;
  }

  // App Open reklamı için test ID'leri
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
      return 'ca-app-pub-3375249639458473/6180874278'; // Gerçek Android app open ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3375249639458473/1633741717'; // Gerçek iOS app open ID
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
      return 'ca-app-pub-3375249639458473/5517695141'; // Gerçek Android native ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3375249639458473/9320660047'; // Gerçek iOS native ID
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
      
      // App Open reklamı yükleme artık credits service listener'da yapılacak
      // _instance.loadAppOpenAd(); // KALDIRILDI
    } catch (e) {
      debugPrint('❌ AdMob başlatılamadı: $e');
    }
  }

  void _initializeCreditsListener() async {
    // Credits service başlatılmasını bekle
    await _creditsService.initialize();
    _creditsServiceInitialized = true;
    
    // Premium durumu değişikliklerini dinle
    _creditsService.addListener(_onPremiumStatusChanged);
    
    // İlk kontrol
    _onPremiumStatusChanged();
  }
  
  void _onPremiumStatusChanged() {
    debugPrint('🔄 Premium/Reklamsız durumu değişti: isPremium=${_creditsService.isPremium}, isLifetimeAdsFree=${_creditsService.isLifetimeAdsFree}');
    
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) {
      // Premium/Reklamsız olduysa mevcut reklamı temizle
      debugPrint('👑 [AdMob] Premium/Reklamsız aktif - App Open reklamı temizleniyor');
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _isShowingAppOpenAd = false;
      _isLoadingAppOpenAd = false;
    } else if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree && _appOpenAd == null && !_isLoadingAppOpenAd) {
      // Premium/Reklamsız değilse ve reklam yoksa yükle
      debugPrint('📱 [AdMob] Premium/Reklamsız değil - App Open reklamı yüklenmeye başlıyor...');
      // Biraz gecikme ile yükle ki servisi stable olsun
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree) { // Double check
          debugPrint('🚀 [AdMob] App Open reklamı yükleme komutu veriliyor...');
          loadAppOpenAd();
        }
      });
    } else {
      debugPrint('📊 [AdMob] Reklam yükleme durumu: reklam mevcut=${_appOpenAd != null}, yükleniyor=$_isLoadingAppOpenAd');
    }
  }

  // App Open reklamını yükle
  void loadAppOpenAd() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    
    // Credits service başlatılmadıysa bekle
    if (!_creditsServiceInitialized) {
      debugPrint('⏳ Credits service henüz başlatılmadı, reklam yükleme erteleniyor');
      return;
    }
    
    // Premium kullanıcılar ve reklamsız kullanıcılar için reklam yükleme
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) {
      debugPrint('👑 Premium/Reklamsız kullanıcı - Reklam yüklenmeyecek');
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

  // App Open reklamını göster - iyileştirilmiş versiyon
  void showAppOpenAd() {
    debugPrint('🎯 showAppOpenAd() çağırıldı - detaylı kontroller başlıyor...');
    
    // Credits service başlatılmadıysa bekle
    if (!_creditsServiceInitialized) {
      debugPrint('⏳ Credits service henüz başlatılmadı, reklam gösterilmeyecek');
      return;
    }
    
    // Premium kullanıcılar ve reklamsız kullanıcılar için reklam gösterme
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) {
      debugPrint('👑 Premium/Reklamsız kullanıcı - Reklam gösterilmeyecek');
      return;
    }
    
    // Reklam durumu kontrolü
    debugPrint('📊 Reklam durumu: mevcut=${_appOpenAd != null}, gösteriliyor=$_isShowingAppOpenAd, yükleniyor=$_isLoadingAppOpenAd');
    
    if (_appOpenAd == null) {
      debugPrint('⚠️ App Open reklamı mevcut değil, yeni reklam yükleniyor...');
      loadAppOpenAd();
      return;
    }
    
    if (_isShowingAppOpenAd) {
      debugPrint('⚠️ App Open reklamı zaten gösteriliyor, atlanıyor');
      return;
    }
    
    if (!isAppOpenAdAvailable) {
      debugPrint('⚠️ App Open reklamı kullanılamaz durumda, yeni reklam yükleniyor...');
      loadAppOpenAd();
      return;
    }
    
    // Frekans kontrolü - daha detaylı loglama
    if (_lastAppOpenShowTime != null) {
      final timeSinceLastShow = DateTime.now().difference(_lastAppOpenShowTime!);
      debugPrint('⏱️ Son reklam gösteriminden bu yana geçen süre: ${timeSinceLastShow.inMinutes} dakika');
      if (timeSinceLastShow < _minTimeBetweenAppOpenAds) {
        debugPrint('⏱️ App Open reklamı çok yakın zamanda gösterildi. ${_minTimeBetweenAppOpenAds.inMinutes - timeSinceLastShow.inMinutes} dakika daha beklenecek');
        return;
      }
    } else {
      debugPrint('⏱️ İlk reklam gösterimi - frekans kontrolü yok');
    }

    _isShowingAppOpenAd = true;
    debugPrint('🚀 App Open reklamı gösteriliyor - tüm kontroller geçildi!');

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd ad) {
        debugPrint('✅ App Open reklamı tam ekran başarıyla gösterildi');
        _lastAppOpenShowTime = DateTime.now();
      },
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        debugPrint('👋 App Open reklamı kullanıcı tarafından kapatıldı');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        // Bir sonraki gösterim için yeni reklam yükle
        Future.delayed(const Duration(seconds: 1), () {
          loadAppOpenAd();
        });
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        debugPrint('❌ App Open reklamı gösterim hatası: ${error.code} - ${error.message}');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        // Hata durumunda yeni reklam yükle
        Future.delayed(const Duration(seconds: 2), () {
          loadAppOpenAd();
        });
      },
    );

    try {
      _appOpenAd!.show();
      debugPrint('📱 App Open reklamı show() komutu çalıştırıldı');
    } catch (e) {
      debugPrint('💥 App Open reklamı gösterim exception: $e');
      _isShowingAppOpenAd = false;
      _appOpenAd?.dispose();
      _appOpenAd = null;
      loadAppOpenAd();
    }
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

  // App lifecycle için - 3 SANİYE KURALI İLE
  void onAppStateChanged(AppLifecycleState state) {
    debugPrint('🔄 [LIFECYCLE] $_previousState -> $state (firstLaunch: $_isFirstLaunch, wasBackground: $_wasActuallyInBackground, count: $_backgroundToForegroundCount)');
    
    // Debug durumu her state değişikliğinde göster
    debugAdStatus();
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isFirstLaunch) {
          // İlk açılış - reklam gösterme
          debugPrint('🚀 [LIFECYCLE] İlk açılış - reklam gösterilmeyecek');
          _isFirstLaunch = false;
        } else if (_wasActuallyInBackground && _lastPausedTime != null) {
          // 3 saniye kuralını kontrol et
          final backgroundDuration = DateTime.now().difference(_lastPausedTime!);
          debugPrint('⏱️ [LIFECYCLE] Arka planda geçen süre: ${backgroundDuration.inSeconds} saniye');
          
          if (backgroundDuration >= _minBackgroundTime) {
            // 3 saniyeden fazla arka plandaysa reklam göster
          _backgroundToForegroundCount++;
            debugPrint('✅ [LIFECYCLE] 3 saniye kuralı sağlandı - Arka plandan dönüş #$_backgroundToForegroundCount - REKLAM GÖSTERİLECEK!');
          
          // 100ms gecikme ile reklam göster (UI stable olsun)
          Future.delayed(const Duration(milliseconds: 100), () {
            showAppOpenAd();
          });
          } else {
            debugPrint('⏳ [LIFECYCLE] 3 saniye dolmadı (${backgroundDuration.inSeconds}s) - reklam gösterilmeyecek');
          }
          
          _wasActuallyInBackground = false;
          _lastPausedTime = null;
        } else {
          debugPrint('⚠️ [LIFECYCLE] Resume ama arka plandan gelmiyor veya pause zamanı yok');
        }
        break;
        
      case AppLifecycleState.paused:
        // Pause = arka plana geçti
        debugPrint('⏸️ [LIFECYCLE] Pause - arka plana geçti');
        _wasActuallyInBackground = true;
        _lastPausedTime = DateTime.now();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Bu durumlar da arka plan demektir
        debugPrint('📵 [LIFECYCLE] $state - arka plan durumu');
        if (_lastPausedTime == null) {
          // Eğer pause olmadıysa şimdi zamanı kaydet
          _lastPausedTime = DateTime.now();
        }
        _wasActuallyInBackground = true;
        break;
    }
    
    _previousState = state;
    debugPrint('🔍 [LIFECYCLE] Güncellendi: firstLaunch=$_isFirstLaunch, wasBackground=$_wasActuallyInBackground, lastPaused=$_lastPausedTime');
  }
  
  // Mounted kontrolü için helper
  bool get mounted => _creditsServiceInitialized;
  
  // TEST FONKSIYONU: Zorla app open reklam göster (debug için)
  void forceShowAppOpenAd() {
    debugPrint('🧪 [TEST] ForceShowAppOpenAd çağırıldı');
    debugPrint('🧪 [TEST] Credits initialized: $_creditsServiceInitialized');
    debugPrint('🧪 [TEST] Premium durumu: ${_creditsService.isPremium}');
    debugPrint('🧪 [TEST] App Open Ad mevcut: ${_appOpenAd != null}');
    debugPrint('🧪 [TEST] App Open Ad yükleniyor: $_isLoadingAppOpenAd');
    debugPrint('🧪 [TEST] App Open Ad gösteriliyor: $_isShowingAppOpenAd');
    
    if (!_creditsServiceInitialized) {
      debugPrint('🧪 [TEST] Credits service başlatılmamış, başlatılıyor...');
      _initializeCreditsListener();
      return;
    }
    
    if (_creditsService.isPremium) {
      debugPrint('🧪 [TEST] Premium kullanıcı - reklam gösterilmeyecek');
      return;
    }
    
    if (_appOpenAd == null) {
      debugPrint('🧪 [TEST] Reklam mevcut değil, yükleniyor...');
      loadAppOpenAd();
      return;
    }
    
    debugPrint('🧪 [TEST] Tüm kontroller geçildi, reklam gösterilecek!');
    showAppOpenAd();
  }
  
  // Reklam durumunu detaylı göster (debug için)
  void debugAdStatus() {
    debugPrint('🔍 === APP OPEN AD DEBUG STATUS ===');
    debugPrint('🔍 _isFirstLaunch: $_isFirstLaunch');
    debugPrint('🔍 _wasActuallyInBackground: $_wasActuallyInBackground');
    debugPrint('🔍 _backgroundToForegroundCount: $_backgroundToForegroundCount');
    debugPrint('🔍 _lastPausedTime: $_lastPausedTime');
    debugPrint('🔍 _creditsServiceInitialized: $_creditsServiceInitialized');
    debugPrint('🔍 isPremium: ${_creditsService.isPremium}');
    debugPrint('🔍 _appOpenAd != null: ${_appOpenAd != null}');
    debugPrint('🔍 _isLoadingAppOpenAd: $_isLoadingAppOpenAd');
    debugPrint('🔍 _isShowingAppOpenAd: $_isShowingAppOpenAd');
    debugPrint('🔍 isAppOpenAdAvailable: $isAppOpenAdAvailable');
    debugPrint('🔍 _lastAppOpenShowTime: $_lastAppOpenShowTime');
    debugPrint('🔍 _previousState: $_previousState');
    debugPrint('🔍 ================================');
  }
  
  // Tüm reklamları dispose et (uygulama kapanırken kullan)
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
} 