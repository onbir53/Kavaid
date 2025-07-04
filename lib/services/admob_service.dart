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
    // Constructor'da credits service'i dinlemeye başla
    _initializeCreditsListener();
  }
  
  final CreditsService _creditsService = CreditsService();

  // Interstitial reklamı için değişkenler
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitialAd = false;
  bool _isShowingInterstitialAd = false;
  DateTime? _interstitialLoadTime;
  DateTime? _lastInterstitialShowTime;
  
  // Uygulama lifecycle kontrolü için  
  DateTime? _lastPausedTime;
  bool _wasActuallyInBackground = false;
  AppLifecycleState? _previousState;
  bool _creditsServiceInitialized = false;
  int _backgroundToForegroundCount = 0; // Arka plandan öne geçiş sayacı
  bool _isShortPause = false; // Bildirim paneli gibi kısa süreli pause durumları için
  Timer? _pauseTimer; // Pause süresini kontrol etmek için timer
  
  // Background time kuralı - Debug modda kısa, production'da normal
  static Duration get _minBackgroundTime => kDebugMode 
      ? const Duration(seconds: 2) // Debug modda 2 saniye - test için
      : const Duration(seconds: 3); // Production'da 3 saniye
  
  // Reklam frekans kontrolü için sabitler - Debug modda çok kısa, production'da uzun
  static Duration get _minTimeBetweenInterstitialAds => kDebugMode 
      ? const Duration(seconds: 5) // Debug modda 5 saniye - test için
      : const Duration(minutes: 5); // Production'da 5 dakika minimum
  static const Duration _interstitialAdExpiration = Duration(hours: 4); // Interstitial reklam geçerlilik süresi
  static const int _maxAdLoadRetries = 3; // Maksimum reklam yükleme deneme sayısı
  int _currentRetryCount = 0;

  // Adaptive Banner için test reklamları ID'leri
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2435281174';
  
  // Interstitial reklamı için test ID'leri
  static const String _testInterstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  
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

  // Interstitial reklamı ID'si
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Test ID'leri
      if (Platform.isAndroid) {
        return _testInterstitialAdUnitIdAndroid;
      } else if (Platform.isIOS) {
        return _testInterstitialAdUnitIdIOS;
      }
    }
    
    // Production ID'leri
    if (Platform.isAndroid) {
      return 'ca-app-pub-3375249639458473/4972153248'; // Geçiş - Android interstitial ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3375249639458473/4972153248'; // Geçiş - iOS interstitial ID (aynı birim)
    }
    
    // Fallback
    return _testInterstitialAdUnitIdAndroid;
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
      
      // Interstitial reklamı yükleme artık credits service listener'da yapılacak
      // _instance.loadInterstitialAd(); // Credits service listener'da yüklenecek
    } catch (e) {
      debugPrint('❌ AdMob başlatılamadı: $e');
    }
  }

  void _initializeCreditsListener() async {
    debugPrint('🔄 [AdMob] Credits service listener başlatılıyor...');
    
    // Credits service başlatılmasını bekle
    await _creditsService.initialize();
    _creditsServiceInitialized = true;
    debugPrint('✅ [AdMob] Credits service başlatıldı, premium: ${_creditsService.isPremium}, adsFree: ${_creditsService.isLifetimeAdsFree}');
    
    // Premium durumu değişikliklerini dinle
    _creditsService.addListener(_onPremiumStatusChanged);
    
    // İlk kontrol ve reklam yükleme
    _onPremiumStatusChanged();
    
    // 2 saniye gecikme ile zorunlu reklam yükleme (eğer hala yüklenmemişse)
    Future.delayed(const Duration(seconds: 2), () {
      if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree && _interstitialAd == null && !_isLoadingInterstitialAd) {
        debugPrint('🚀 [AdMob] Zorunlu reklam yükleme tetikleniyor...');
        loadInterstitialAd();
      }
    });
  }
  
  void _onPremiumStatusChanged() {
    debugPrint('🔄 Premium/Reklamsız durumu değişti: isPremium=${_creditsService.isPremium}, isLifetimeAdsFree=${_creditsService.isLifetimeAdsFree}');
    
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) {
      // Premium/Reklamsız olduysa mevcut reklamı temizle
      debugPrint('👑 [AdMob] Premium/Reklamsız aktif - Interstitial reklamı temizleniyor');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isShowingInterstitialAd = false;
      _isLoadingInterstitialAd = false;
    } else if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree && _interstitialAd == null && !_isLoadingInterstitialAd) {
      // Premium/Reklamsız değilse ve reklam yoksa yükle
      debugPrint('📱 [AdMob] Premium/Reklamsız değil - Interstitial reklamı yüklenmeye başlıyor...');
      // Biraz gecikme ile yükle ki servisi stable olsun
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_creditsService.isPremium && !_creditsService.isLifetimeAdsFree) { // Double check
          debugPrint('🚀 [AdMob] Interstitial reklamı yükleme komutu veriliyor...');
          loadInterstitialAd();
        }
      });
    } else {
      debugPrint('📊 [AdMob] Reklam yükleme durumu: reklam mevcut=${_interstitialAd != null}, yükleniyor=$_isLoadingInterstitialAd');
    }
  }

  // Interstitial reklamını yükle
  void loadInterstitialAd() {
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

    if (_isLoadingInterstitialAd || isInterstitialAdAvailable) {
      return;
    }

    _isLoadingInterstitialAd = true;
    debugPrint('🔄 Interstitial reklamı yükleniyor...');

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('✅ Interstitial reklamı yüklendi');
          _interstitialAd = ad;
          _interstitialLoadTime = DateTime.now();
          _isLoadingInterstitialAd = false;
          _currentRetryCount = 0; // Başarılı yüklemede retry sayacını sıfırla
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ Interstitial reklamı yüklenemedi: ${error.message}');
          _isLoadingInterstitialAd = false;
          
          // Retry mantığı
          _currentRetryCount++;
          if (_currentRetryCount < _maxAdLoadRetries) {
            debugPrint('🔄 Interstitial reklamı tekrar denenecek (${_currentRetryCount}/$_maxAdLoadRetries)');
            Future.delayed(Duration(seconds: 2 * _currentRetryCount), () {
              loadInterstitialAd();
            });
          }
        },
      ),
    );
  }

  // Interstitial reklamını göster - iyileştirilmiş versiyon
  void showInterstitialAd() {
    debugPrint('🎯 showInterstitialAd() çağırıldı - detaylı kontroller başlıyor...');
    
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
    debugPrint('📊 Reklam durumu: mevcut=${_interstitialAd != null}, gösteriliyor=$_isShowingInterstitialAd, yükleniyor=$_isLoadingInterstitialAd');
    
    if (_interstitialAd == null) {
      debugPrint('⚠️ Interstitial reklamı mevcut değil, yeni reklam yükleniyor...');
      loadInterstitialAd();
      return;
    }
    
    if (_isShowingInterstitialAd) {
      debugPrint('⚠️ Interstitial reklamı zaten gösteriliyor, atlanıyor');
      return;
    }
    
    if (!isInterstitialAdAvailable) {
      debugPrint('⚠️ Interstitial reklamı kullanılamaz durumda, yeni reklam yükleniyor...');
      loadInterstitialAd();
      return;
    }
    
    // Frekans kontrolü - daha detaylı loglama
    if (_lastInterstitialShowTime != null) {
      final timeSinceLastShow = DateTime.now().difference(_lastInterstitialShowTime!);
      debugPrint('⏱️ Son reklam gösteriminden bu yana geçen süre: ${timeSinceLastShow.inMinutes} dakika');
      if (timeSinceLastShow < _minTimeBetweenInterstitialAds) {
        debugPrint('⏱️ Interstitial reklamı çok yakın zamanda gösterildi. ${_minTimeBetweenInterstitialAds.inMinutes - timeSinceLastShow.inMinutes} dakika daha beklenecek');
        return;
      }
    } else {
      debugPrint('⏱️ İlk reklam gösterimi - frekans kontrolü yok');
    }

    _isShowingInterstitialAd = true;
    debugPrint('🚀 Interstitial reklamı gösteriliyor - tüm kontroller geçildi!');

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        debugPrint('✅ Interstitial reklamı tam ekran başarıyla gösterildi');
        _lastInterstitialShowTime = DateTime.now();
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('👋 Interstitial reklamı kullanıcı tarafından kapatıldı');
        _isShowingInterstitialAd = false;
        ad.dispose();
        _interstitialAd = null;
        // Bir sonraki gösterim için yeni reklam yükle
        Future.delayed(const Duration(seconds: 1), () {
          loadInterstitialAd();
        });
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('❌ Interstitial reklamı gösterim hatası: ${error.code} - ${error.message}');
        _isShowingInterstitialAd = false;
        ad.dispose();
        _interstitialAd = null;
        // Hata durumunda yeni reklam yükle
        Future.delayed(const Duration(seconds: 2), () {
          loadInterstitialAd();
        });
      },
    );

    try {
      _interstitialAd!.show();
      debugPrint('📱 Interstitial reklamı show() komutu çalıştırıldı');
    } catch (e) {
      debugPrint('💥 Interstitial reklamı gösterim exception: $e');
      _isShowingInterstitialAd = false;
      _interstitialAd?.dispose();
      _interstitialAd = null;
      loadInterstitialAd();
    }
  }

  // Interstitial reklamının kullanılabilir olup olmadığını kontrol et
  bool get isInterstitialAdAvailable {
    if (_interstitialAd == null) return false;
    
    // Reklam süresi dolmuş mu kontrol et
    if (_interstitialLoadTime != null && 
        DateTime.now().difference(_interstitialLoadTime!) > _interstitialAdExpiration) {
      debugPrint('⏰ Interstitial reklamı süresi dolmuş, dispose ediliyor');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      return false;
    }
    
    return true;
  }

  // App lifecycle için - 3 SANİYE KURALI İLE + BİLDİRİM PANELİ FİLTRESİ
  void onAppStateChanged(AppLifecycleState state) {
    debugPrint('🔄 [LIFECYCLE] $_previousState -> $state (wasBackground: $_wasActuallyInBackground, count: $_backgroundToForegroundCount, shortPause: $_isShortPause)');
    
    // Debug durumu her state değişikliğinde göster
    debugAdStatus();
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Pause timer'ı iptal et (eğer varsa)
        _pauseTimer?.cancel();
        _pauseTimer = null;
        
        // Background-resume geçişi kontrol et
        if (_wasActuallyInBackground && _lastPausedTime != null) {
          // Background süresini kontrol et
          final backgroundDuration = DateTime.now().difference(_lastPausedTime!);
          debugPrint('⏱️ [LIFECYCLE] Arka planda geçen süre: ${backgroundDuration.inSeconds} saniye (${backgroundDuration.inMilliseconds}ms)');
          
          // Çok kısa pause ise bildirim paneli olabilir
          if (backgroundDuration < const Duration(milliseconds: 800)) {
            debugPrint('📱 [LIFECYCLE] Çok kısa pause detected (${backgroundDuration.inMilliseconds}ms) - bildirim paneli olabilir, reklam gösterilmeyecek');
            _isShortPause = true;
          } else if (backgroundDuration >= _minBackgroundTime) {
            // 3 saniyeden fazla arka plandaysa reklam göster
            _backgroundToForegroundCount++;
            debugPrint('✅ [LIFECYCLE] 3 saniye kuralı sağlandı - Arka plandan dönüş #$_backgroundToForegroundCount - REKLAM GÖSTERİLECEK!');
          
            // 500ms gecikme ile reklam göster (UI stable olsun + credits service hazır olsun)
            Future.delayed(const Duration(milliseconds: 500), () {
              debugPrint('🎯 [LIFECYCLE] Reklam gösterme komutu çalıştırılıyor...');
              showInterstitialAd();
            });
          } else {
            debugPrint('⏳ [LIFECYCLE] 3 saniye dolmadı (${backgroundDuration.inSeconds}s) - reklam gösterilmeyecek');
          }
        } else if (_isShortPause) {
          debugPrint('📱 [LIFECYCLE] Kısa pause tespit edildi (bildirim paneli gibi) - reklam gösterilmeyecek');
        } else {
          debugPrint('ℹ️ [LIFECYCLE] Resume - arka plandan gelmiyor veya pause zamanı yok (normal durum)');
        }
        
        // Resume durumunda değişkenleri sıfırla
        _wasActuallyInBackground = false;
        _lastPausedTime = null;
        _isShortPause = false;
        break;
        
      case AppLifecycleState.paused:
        // Pause durumunda hemen background olarak kabul et
        debugPrint('⏸️ [LIFECYCLE] Pause - arka plana geçti');
        _lastPausedTime = DateTime.now();
        _wasActuallyInBackground = true;
        _isShortPause = false;
        
        // Timer'ı iptal et (eğer varsa)
        _pauseTimer?.cancel();
        _pauseTimer = null;
        break;
        
      case AppLifecycleState.inactive:
        // Inactive durumunda hemen background olarak kabul et (eğer henüz pause zamanı yoksa)
        if (_lastPausedTime == null) {
          debugPrint('📵 [LIFECYCLE] Inactive - arka plana geçti');
          _lastPausedTime = DateTime.now();
          _wasActuallyInBackground = true;
          _isShortPause = false;
        }
        break;
        
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Bu durumlar kesin arka plan demektir
        debugPrint('📵 [LIFECYCLE] $state - kesin arka plan durumu');
        _pauseTimer?.cancel();
        _pauseTimer = null;
        if (_lastPausedTime == null) {
          _lastPausedTime = DateTime.now();
        }
        _wasActuallyInBackground = true;
        _isShortPause = false;
        break;
    }
    
    _previousState = state;
    debugPrint('🔍 [LIFECYCLE] Güncellendi: wasBackground=$_wasActuallyInBackground, lastPaused=$_lastPausedTime, shortPause=$_isShortPause');
  }
  
  // Mounted kontrolü için helper
  bool get mounted => _creditsServiceInitialized;
  
  // TEST FONKSIYONU: Zorla interstitial reklam göster (debug için)
  void forceShowInterstitialAd() {
    debugPrint('🧪 [TEST] ForceShowInterstitialAd çağırıldı');
    debugPrint('🧪 [TEST] Credits initialized: $_creditsServiceInitialized');
    debugPrint('🧪 [TEST] Premium durumu: ${_creditsService.isPremium}');
    debugPrint('🧪 [TEST] Lifetime ads free: ${_creditsService.isLifetimeAdsFree}');
    debugPrint('🧪 [TEST] Interstitial Ad mevcut: ${_interstitialAd != null}');
    debugPrint('🧪 [TEST] Interstitial Ad yükleniyor: $_isLoadingInterstitialAd');
    debugPrint('🧪 [TEST] Interstitial Ad gösteriliyor: $_isShowingInterstitialAd');
    
    if (!_creditsServiceInitialized) {
      debugPrint('🧪 [TEST] Credits service başlatılmamış, beklemede...');
      // 1 saniye bekle ve tekrar dene
      Future.delayed(const Duration(seconds: 1), () {
        forceShowInterstitialAd();
      });
      return;
    }
    
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) {
      debugPrint('🧪 [TEST] Premium/Reklamsız kullanıcı - reklam gösterilmeyecek');
      return;
    }
    
    if (_interstitialAd == null) {
      debugPrint('🧪 [TEST] Reklam mevcut değil, yükleniyor ve 3 saniye sonra gösteriliyor...');
      loadInterstitialAd();
      // 3 saniye bekle ve tekrar dene
      Future.delayed(const Duration(seconds: 3), () {
        if (_interstitialAd != null) {
          debugPrint('🧪 [TEST] Reklam yüklendi, şimdi gösteriliyor!');
          showInterstitialAd();
        } else {
          debugPrint('🧪 [TEST] Reklam hala yüklenemedi, tekrar deneniyor...');
          forceShowInterstitialAd();
        }
      });
      return;
    }
    
    debugPrint('🧪 [TEST] Tüm kontroller geçildi, reklam gösterilecek!');
    
    // Frekans kontrolünü bypass et (test için)
    _lastInterstitialShowTime = null;
    
    showInterstitialAd();
  }
  
  // Reklam durumunu detaylı göster (debug için)
  void debugAdStatus() {
    debugPrint('🔍 === INTERSTITIAL AD DEBUG STATUS ===');
    debugPrint('🔍 _wasActuallyInBackground: $_wasActuallyInBackground');
    debugPrint('🔍 _backgroundToForegroundCount: $_backgroundToForegroundCount');
    debugPrint('🔍 _lastPausedTime: $_lastPausedTime');
    debugPrint('🔍 _isShortPause: $_isShortPause');
    debugPrint('🔍 _pauseTimer active: ${_pauseTimer?.isActive ?? false}');
    debugPrint('🔍 _creditsServiceInitialized: $_creditsServiceInitialized');
    debugPrint('🔍 isPremium: ${_creditsService.isPremium}');
    debugPrint('🔍 isLifetimeAdsFree: ${_creditsService.isLifetimeAdsFree}');
    debugPrint('🔍 _interstitialAd != null: ${_interstitialAd != null}');
    debugPrint('🔍 _isLoadingInterstitialAd: $_isLoadingInterstitialAd');
    debugPrint('🔍 _isShowingInterstitialAd: $_isShowingInterstitialAd');
    debugPrint('🔍 isInterstitialAdAvailable: $isInterstitialAdAvailable');
    debugPrint('🔍 _lastInterstitialShowTime: $_lastInterstitialShowTime');
    debugPrint('🔍 _previousState: $_previousState');
    debugPrint('🔍 ======================================');
  }
  
  // Tüm reklamları dispose et (uygulama kapanırken kullan)
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _pauseTimer?.cancel();
    _pauseTimer = null;
  }
} 