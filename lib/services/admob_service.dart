import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Adaptive Banner için test reklamları ID'leri
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2435281174';
  
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

  // AdMob'u başlat - sadece mobil platformlarda
  static Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('⚠️ AdMob web platformunda desteklenmiyor');
      return;
    }
    
    try {
      await MobileAds.instance.initialize();
      debugPrint('✅ AdMob başlatıldı');
    } catch (e) {
      debugPrint('❌ AdMob başlatılamadı: $e');
    }
  }
} 