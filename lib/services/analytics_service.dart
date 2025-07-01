// TODO: Firebase Analytics paketini ekledikten sonra bu dosyayı aktifleştir
// import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  // Firebase Analytics henüz eklenmediği için tüm metodlar boş
  
  // Singleton pattern
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();
  
  // Analytics observer'ı dışarıya açalım (routing için)
  // static FirebaseAnalyticsObserver get observer => _observer;
  
  // Analytics'i başlat
  static Future<void> initialize() async {
    debugPrint('⚠️ Firebase Analytics henüz eklenmedi');
  }
  
  // Uygulama açılış eventi
  static Future<void> logAppOpen() async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Kelime arama eventi
  static Future<void> logWordSearch(String query, {int? resultCount}) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Kelime detayına tıklama eventi
  static Future<void> logWordView(String word, {String? source}) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Kelime kaydetme eventi
  static Future<void> logWordSave(String word) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Abone olma eventi
  static Future<void> logSubscriptionPurchase(String productId, double price) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Premium aktifleştirme eventi
  static Future<void> logPremiumActivated(String method) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Reklam görüntüleme eventi
  static Future<void> logAdImpression(String adType, {String? adUnitId}) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Reklam tıklama eventi
  static Future<void> logAdClick(String adType, {String? adUnitId}) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Ekran görüntüleme eventi (otomatik olarak çalışır ama manuel de çağırılabilir)
  static Future<void> logScreenView(String screenName, {String? screenClass}) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Kullanıcı özelliklerini ayarla
  static Future<void> setUserProperties({
    bool? isPremium,
    int? totalSearches,
    int? savedWordsCount,
  }) async {
    // TODO: Implement when Firebase Analytics is added
  }
  
  // Özel event gönderme
  static Future<void> logCustomEvent(String eventName, Map<String, dynamic> parameters) async {
    // TODO: Implement when Firebase Analytics is added
  }
} 