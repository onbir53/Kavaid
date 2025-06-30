import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(analytics: _analytics);
  static bool _isInitialized = false;
  static bool _isEnabled = true;
  
  // Singleton pattern
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();
  
  // Analytics observer'ı dışarıya açalım (routing için)
  static FirebaseAnalyticsObserver get observer => _observer;
  
  // Safe analytics wrapper - tüm analytics çağrılarını güvenli hale getirir
  static Future<T?> _safeAnalyticsCall<T>(Future<T> Function() analyticsFunction, String operationName) async {
    if (!_isEnabled) {
      debugPrint('⚠️ Analytics devre dışı - $operationName atlanıyor');
      return null;
    }
    
    try {
      return await analyticsFunction();
    } catch (e) {
      debugPrint('⚠️ Analytics $operationName hatası (sessizce devam): $e');
      
      // Eğer çok fazla hata alırsa analytics'i geçici olarak devre dışı bırak
      if (e.toString().contains('channel-error') || e.toString().contains('PlatformException')) {
        debugPrint('⚠️ Platform hatası tespit edildi, Analytics geçici olarak devre dışı');
        _isEnabled = false;
        // 30 saniye sonra tekrar dene
        Future.delayed(const Duration(seconds: 30), () {
          _isEnabled = true;
          debugPrint('🔄 Analytics yeniden aktifleştirildi');
        });
      }
      
      return null;
    }
  }
  
  // Analytics'i başlat
  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ Analytics zaten başlatılmış');
      return;
    }
    
    debugPrint('🚀 Firebase Analytics başlatılıyor...');
    
    // Firebase Analytics'in hazır olmasını bekle
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Analytics collection'ı etkinleştir
    await _safeAnalyticsCall(
      () => _analytics.setAnalyticsCollectionEnabled(true),
      'setAnalyticsCollectionEnabled'
    );
    
    // Test eventi gönder
    await _safeAnalyticsCall(
      () => _analytics.logEvent(name: 'analytics_initialized'),
      'test_event'
    );
    
    if (_isEnabled) {
      _isInitialized = true;
      debugPrint('✅ Firebase Analytics başarıyla başlatıldı');
    } else {
      debugPrint('⚠️ Firebase Analytics başlatılamadı, ama uygulama çalışmaya devam ediyor');
    }
  }
  
  // Uygulama açılış eventi
  static Future<void> logAppOpen() async {
    await _safeAnalyticsCall(
      () async {
        await _analytics.logAppOpen();
        debugPrint('📊 Analytics: App açıldı');
      },
      'logAppOpen'
    );
  }
  
  // Kelime arama eventi
  static Future<void> logWordSearch(String query, {int? resultCount}) async {
    await _safeAnalyticsCall(
      () async {
        await _analytics.logEvent(
          name: 'kelime_arama',
          parameters: <String, Object>{
            'arama_terimi': query,
            'sonuc_sayisi': resultCount ?? 0,
            'arama_uzunlugu': query.length,
          },
        );
        debugPrint('📊 Analytics: Kelime arama - $query (${resultCount ?? 0} sonuç)');
      },
      'logWordSearch'
    );
  }
  
  // Kelime detayına tıklama eventi
  static Future<void> logWordView(String word, {String? source}) async {
    try {
      await _analytics.logEvent(
        name: 'kelime_goruntuleme',
        parameters: <String, Object>{
          'kelime': word,
          'kaynak': source ?? 'unknown',
        },
      );
      debugPrint('📊 Analytics: Kelime görüntüleme - $word');
    } catch (e) {
      debugPrint('❌ Analytics logWordView hatası: $e');
    }
  }
  
  // Kelime kaydetme eventi
  static Future<void> logWordSave(String word) async {
    try {
      await _analytics.logEvent(
        name: 'kelime_kaydetme',
        parameters: <String, Object>{
          'kelime': word,
        },
      );
      debugPrint('📊 Analytics: Kelime kaydedildi - $word');
    } catch (e) {
      debugPrint('❌ Analytics logWordSave hatası: $e');
    }
  }
  
  // Abone olma eventi
  static Future<void> logSubscriptionPurchase(String productId, double price) async {
    try {
      await _analytics.logPurchase(
        currency: 'TRY',
        value: price,
        parameters: <String, Object>{
          'abonelik_turu': productId,
          'fiyat': price,
        },
      );
      debugPrint('📊 Analytics: Abonelik satın alındı - $productId');
    } catch (e) {
      debugPrint('❌ Analytics logSubscriptionPurchase hatası: $e');
    }
  }
  
  // Premium aktifleştirme eventi
  static Future<void> logPremiumActivated(String method) async {
    try {
      await _analytics.logEvent(
        name: 'premium_aktif',
        parameters: <String, Object>{
          'aktivasyon_yontemi': method, // 'subscription', 'credits', etc.
        },
      );
      debugPrint('📊 Analytics: Premium aktifleştirildi - $method');
    } catch (e) {
      debugPrint('❌ Analytics logPremiumActivated hatası: $e');
    }
  }
  
  // Reklam görüntüleme eventi
  static Future<void> logAdImpression(String adType, {String? adUnitId}) async {
    try {
      await _analytics.logEvent(
        name: 'reklam_goruntulenme',
        parameters: <String, Object>{
          'reklam_turu': adType, // 'banner', 'interstitial', 'native', etc.
          'reklam_id': adUnitId ?? 'unknown',
        },
      );
      debugPrint('📊 Analytics: Reklam görüntülendi - $adType');
    } catch (e) {
      debugPrint('❌ Analytics logAdImpression hatası: $e');
    }
  }
  
  // Reklam tıklama eventi
  static Future<void> logAdClick(String adType, {String? adUnitId}) async {
    try {
      await _analytics.logEvent(
        name: 'reklam_tiklama',
        parameters: <String, Object>{
          'reklam_turu': adType,
          'reklam_id': adUnitId ?? 'unknown',
        },
      );
      debugPrint('📊 Analytics: Reklam tıklandı - $adType');
    } catch (e) {
      debugPrint('❌ Analytics logAdClick hatası: $e');
    }
  }
  
  // Ekran görüntüleme eventi (otomatik olarak çalışır ama manuel de çağırılabilir)
  static Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('📊 Analytics: Ekran görüntülendi - $screenName');
    } catch (e) {
      debugPrint('❌ Analytics logScreenView hatası: $e');
    }
  }
  
  // Kullanıcı özelliklerini ayarla
  static Future<void> setUserProperties({
    bool? isPremium,
    int? totalSearches,
    int? savedWordsCount,
  }) async {
    try {
      if (isPremium != null) {
        await _analytics.setUserProperty(
          name: 'premium_kullanici',
          value: isPremium.toString(),
        );
      }
      
      if (totalSearches != null) {
        await _analytics.setUserProperty(
          name: 'toplam_arama',
          value: totalSearches.toString(),
        );
      }
      
      if (savedWordsCount != null) {
        await _analytics.setUserProperty(
          name: 'kaydedilen_kelime_sayisi',
          value: savedWordsCount.toString(),
        );
      }
      
      debugPrint('📊 Analytics: Kullanıcı özellikleri güncellendi');
    } catch (e) {
      debugPrint('❌ Analytics setUserProperties hatası: $e');
    }
  }
  
  // Özel event gönderme
  static Future<void> logCustomEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      // Map<String, dynamic>'i Map<String, Object>'e çevir
      final convertedParameters = parameters.map<String, Object>((key, value) {
        return MapEntry(key, value ?? 'null');
      });
      
      await _analytics.logEvent(
        name: eventName,
        parameters: convertedParameters,
      );
      debugPrint('📊 Analytics: Özel event - $eventName');
    } catch (e) {
      debugPrint('❌ Analytics logCustomEvent hatası: $e');
    }
  }
} 