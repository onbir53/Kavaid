// TODO: Firebase Analytics paketini ekledikten sonra bu dosyayı aktifleştir
// import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(analytics: _analytics);
  
  // Singleton pattern
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();
  
  // Analytics observer'ı dışarıya açalım (routing için)
  static FirebaseAnalyticsObserver get observer => _observer;
  
  // Analytics'i başlat
  static Future<void> initialize() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('✅ Firebase Analytics başlatıldı');
    } catch (e) {
      debugPrint('❌ Firebase Analytics başlatma hatası: $e');
    }
  }
  
  // Uygulama açılış eventi
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      debugPrint('📊 Analytics: App Open');
    } catch (e) {
      debugPrint('❌ Analytics App Open hatası: $e');
    }
  }
  
  // Kelime arama eventi
  static Future<void> logWordSearch(String query, {int? resultCount}) async {
    try {
      await _analytics.logSearch(
        searchTerm: query,
        parameters: <String, Object>{
          'result_count': resultCount ?? 0,
          'query_length': query.length,
        },
      );
      debugPrint('📊 Analytics: Word Search - $query (${resultCount ?? 0} results)');
    } catch (e) {
      debugPrint('❌ Analytics Word Search hatası: $e');
    }
  }
  
  // Kelime detayına tıklama eventi
  static Future<void> logWordView(String word, {String? source}) async {
    try {
      await _analytics.logEvent(
        name: 'word_view',
        parameters: <String, Object>{
          'word': word,
          'source': source ?? 'unknown',
          'word_length': word.length,
        },
      );
      debugPrint('📊 Analytics: Word View - $word');
    } catch (e) {
      debugPrint('❌ Analytics Word View hatası: $e');
    }
  }
  
  // Kelime kaydetme eventi
  static Future<void> logWordSave(String word) async {
    try {
      await _analytics.logEvent(
        name: 'word_save',
        parameters: <String, Object>{
          'word': word,
          'word_length': word.length,
        },
      );
      debugPrint('📊 Analytics: Word Save - $word');
    } catch (e) {
      debugPrint('❌ Analytics Word Save hatası: $e');
    }
  }
  
  // Abone olma eventi
  static Future<void> logSubscriptionPurchase(String productId, double price) async {
    try {
      await _analytics.logPurchase(
        currency: 'TRY',
        value: price,
        parameters: <String, Object>{
          'item_id': productId,
          'item_name': 'Premium Subscription',
          'item_category': 'subscription',
        },
      );
      debugPrint('📊 Analytics: Subscription Purchase - $productId (₺$price)');
    } catch (e) {
      debugPrint('❌ Analytics Subscription Purchase hatası: $e');
    }
  }
  
  // Premium aktifleştirme eventi
  static Future<void> logPremiumActivated(String method) async {
    try {
      await _analytics.logEvent(
        name: 'premium_activated',
        parameters: <String, Object>{
          'method': method,
        },
      );
      debugPrint('📊 Analytics: Premium Activated - $method');
    } catch (e) {
      debugPrint('❌ Analytics Premium Activated hatası: $e');
    }
  }
  
  // Reklam görüntüleme eventi
  static Future<void> logAdImpression(String adType, {String? adUnitId}) async {
    try {
      await _analytics.logEvent(
        name: 'ad_impression',
        parameters: <String, Object>{
          'ad_type': adType,
          'ad_unit_id': adUnitId ?? 'unknown',
        },
      );
      debugPrint('📊 Analytics: Ad Impression - $adType');
    } catch (e) {
      debugPrint('❌ Analytics Ad Impression hatası: $e');
    }
  }
  
  // Reklam tıklama eventi
  static Future<void> logAdClick(String adType, {String? adUnitId}) async {
    try {
      await _analytics.logEvent(
        name: 'ad_click',
        parameters: <String, Object>{
          'ad_type': adType,
          'ad_unit_id': adUnitId ?? 'unknown',
        },
      );
      debugPrint('📊 Analytics: Ad Click - $adType');
    } catch (e) {
      debugPrint('❌ Analytics Ad Click hatası: $e');
    }
  }
  
  // Ekran görüntüleme eventi
  static Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('📊 Analytics: Screen View - $screenName');
    } catch (e) {
      debugPrint('❌ Analytics Screen View hatası: $e');
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
          name: 'is_premium',
          value: isPremium.toString(),
        );
      }
      if (totalSearches != null) {
        await _analytics.setUserProperty(
          name: 'total_searches',
          value: totalSearches.toString(),
        );
      }
      if (savedWordsCount != null) {
        await _analytics.setUserProperty(
          name: 'saved_words_count',
          value: savedWordsCount.toString(),
        );
      }
      debugPrint('📊 Analytics: User Properties Updated');
    } catch (e) {
      debugPrint('❌ Analytics User Properties hatası: $e');
    }
  }
  
  // Özel event gönderme
  static Future<void> logCustomEvent(String eventName, Map<String, Object> parameters) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );
      debugPrint('📊 Analytics: Custom Event - $eventName');
    } catch (e) {
      debugPrint('❌ Analytics Custom Event hatası: $e');
    }
  }
  
  // AI ile arama eventi
  static Future<void> logAISearch(String query, bool foundResult) async {
    try {
      await _analytics.logEvent(
        name: 'ai_search',
        parameters: <String, Object>{
          'query': query,
          'found_result': foundResult,
          'query_length': query.length,
        },
      );
      debugPrint('📊 Analytics: AI Search - $query (found: $foundResult)');
    } catch (e) {
      debugPrint('❌ Analytics AI Search hatası: $e');
    }
  }
  
  // Arapça klavye kullanımı
  static Future<void> logArabicKeyboardUsage() async {
    try {
      await _analytics.logEvent(
        name: 'arabic_keyboard_used',
        parameters: <String, Object>{},
      );
      debugPrint('📊 Analytics: Arabic Keyboard Used');
    } catch (e) {
      debugPrint('❌ Analytics Arabic Keyboard hatası: $e');
    }
  }
  
  // Tema değiştirme
  static Future<void> logThemeChange(bool isDarkMode) async {
    try {
      await _analytics.logEvent(
        name: 'theme_change',
        parameters: <String, Object>{
          'theme': isDarkMode ? 'dark' : 'light',
        },
      );
      debugPrint('📊 Analytics: Theme Change - ${isDarkMode ? 'dark' : 'light'}');
    } catch (e) {
      debugPrint('❌ Analytics Theme Change hatası: $e');
    }
  }
  
  // Uygulama değerlendirme
  static Future<void> logAppRating() async {
    try {
      await _analytics.logEvent(
        name: 'app_rating_opened',
        parameters: <String, Object>{},
      );
      debugPrint('📊 Analytics: App Rating Opened');
    } catch (e) {
      debugPrint('❌ Analytics App Rating hatası: $e');
    }
  }
} 