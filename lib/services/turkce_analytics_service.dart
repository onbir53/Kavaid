import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class TurkceAnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(analytics: _analytics);
  
  // Singleton pattern
  static final TurkceAnalyticsService _instance = TurkceAnalyticsService._internal();
  factory TurkceAnalyticsService() => _instance;
  TurkceAnalyticsService._internal();
  
  // Analytics observer'ı dışarıya açalım (routing için)
  static FirebaseAnalyticsObserver get observer => _observer;
  
  // ============= SİSTEM EVENT'LERİ =============
  
  /// Uygulama başlatma
  static Future<void> uygulamaBaslatildi() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      await _analytics.logAppOpen();
      debugPrint('📊 [Analytics] Uygulama başlatıldı');
    } catch (e) {
      debugPrint('❌ [Analytics] Uygulama başlatma hatası: $e');
    }
  }
  
  /// Ekran görüntüleme
  static Future<void> ekranGoruntulendi(String ekranAdi) async {
    try {
      await _analytics.logScreenView(
        screenName: ekranAdi,
        screenClass: ekranAdi,
      );
      debugPrint('📊 [Analytics] Ekran görüntülendi: $ekranAdi');
    } catch (e) {
      debugPrint('❌ [Analytics] Ekran görüntüleme hatası: $e');
    }
  }
  
  // ============= KELIME İŞLEMLERİ =============
  
  /// Kelime arama yapıldı
  static Future<void> kelimeArandiNormal(String kelime, int sonucSayisi) async {
    try {
      await _analytics.logEvent(
        name: 'kelime_arama',
        parameters: {
          'kelime': kelime,
          'sonuc_sayisi': sonucSayisi,
          'kelime_uzunluk': kelime.length,
        },
      );
      debugPrint('📊 [Analytics] Kelime arandı: $kelime (${sonucSayisi} sonuç)');
    } catch (e) {
      debugPrint('❌ [Analytics] Kelime arama hatası: $e');
    }
  }
  
  /// AI ile kelime arama
  static Future<void> kelimeArandiAI(String kelime, bool bulundu) async {
    try {
      await _analytics.logEvent(
        name: 'ai_kelime_arama',
        parameters: {
          'kelime': kelime,
          'bulundu': bulundu ? 'evet' : 'hayir',
          'kelime_uzunluk': kelime.length,
        },
      );
      debugPrint('📊 [Analytics] AI kelime arama: $kelime (${bulundu ? 'bulundu' : 'bulunamadı'})');
    } catch (e) {
      debugPrint('❌ [Analytics] AI arama hatası: $e');
    }
  }
  
  /// Kelime detayı görüntülendi
  static Future<void> kelimeDetayiGoruntulendi(String kelime) async {
    try {
      await _analytics.logEvent(
        name: 'kelime_detay',
        parameters: {
          'kelime': kelime,
          'kelime_uzunluk': kelime.length,
        },
      );
      debugPrint('📊 [Analytics] Kelime detayı görüntülendi: $kelime');
    } catch (e) {
      debugPrint('❌ [Analytics] Kelime detayı hatası: $e');
    }
  }
  
  /// Kelime kaydedildi
  static Future<void> kelimeKaydedildi(String kelime) async {
    try {
      await _analytics.logEvent(
        name: 'kelime_kaydet',
        parameters: {
          'kelime': kelime,
          'kelime_uzunluk': kelime.length,
        },
      );
      debugPrint('📊 [Analytics] Kelime kaydedildi: $kelime');
    } catch (e) {
      debugPrint('❌ [Analytics] Kelime kaydetme hatası: $e');
    }
  }
  
  /// Kelime kayıttan çıkarıldı
  static Future<void> kelimeKayittanCikarildi(String kelime) async {
    try {
      await _analytics.logEvent(
        name: 'kelime_kayit_cikar',
        parameters: {
          'kelime': kelime,
        },
      );
      debugPrint('📊 [Analytics] Kelime kayıttan çıkarıldı: $kelime');
    } catch (e) {
      debugPrint('❌ [Analytics] Kelime kayıttan çıkarma hatası: $e');
    }
  }
  
  /// Tüm kayıtlı kelimeler temizlendi
  static Future<void> tumKelimelerTemizlendi(int kelimeSayisi) async {
    try {
      await _analytics.logEvent(
        name: 'tum_kelimeler_temizle',
        parameters: {
          'temizlenen_kelime_sayisi': kelimeSayisi,
        },
      );
      debugPrint('📊 [Analytics] Tüm kelimeler temizlendi: $kelimeSayisi kelime');
    } catch (e) {
      debugPrint('❌ [Analytics] Tüm kelimeler temizleme hatası: $e');
    }
  }
  
  /// Kayıtlı kelimelerde arama
  static Future<void> kayitliKelimelerdeArama(String aramaKelime, int sonucSayisi) async {
    try {
      await _analytics.logEvent(
        name: 'kayitli_kelime_arama',
        parameters: {
          'arama_kelime': aramaKelime,
          'sonuc_sayisi': sonucSayisi,
        },
      );
      debugPrint('📊 [Analytics] Kayıtlı kelimelerde arama: $aramaKelime (${sonucSayisi} sonuç)');
    } catch (e) {
      debugPrint('❌ [Analytics] Kayıtlı kelime arama hatası: $e');
    }
  }
  
  // ============= KLAVYE İŞLEMLERİ =============
  
  /// Arapça klavye kullanıldı
  static Future<void> arapcaKlavyeKullanildi() async {
    try {
      await _analytics.logEvent(
        name: 'arapca_klavye',
        parameters: {},
      );
      debugPrint('📊 [Analytics] Arapça klavye kullanıldı');
    } catch (e) {
      debugPrint('❌ [Analytics] Arapça klavye hatası: $e');
    }
  }
  
  // ============= PREMIUM İŞLEMLERİ =============
  
  /// Premium satın alma başlatıldı
  static Future<void> premiumSatinAlmaBaslatildi(String urunTipi) async {
    try {
      await _analytics.logEvent(
        name: 'premium_baslatma',
        parameters: {
          'urun_tipi': urunTipi, // 'abonelik' veya 'tek_seferlik'
        },
      );
      debugPrint('📊 [Analytics] Premium satın alma başlatıldı: $urunTipi');
    } catch (e) {
      debugPrint('❌ [Analytics] Premium başlatma hatası: $e');
    }
  }
  
  /// Premium satın alma başarılı
  static Future<void> premiumSatinAlinaBasarili(String urunTipi, double fiyat) async {
    try {
      await _analytics.logPurchase(
        currency: 'TRY',
        value: fiyat,
        parameters: {
          'urun_tipi': urunTipi,
          'fiyat': fiyat,
        },
      );
      debugPrint('📊 [Analytics] Premium satın alındı: $urunTipi (₺$fiyat)');
    } catch (e) {
      debugPrint('❌ [Analytics] Premium satın alma hatası: $e');
    }
  }
  
  /// Premium iptal edildi
  static Future<void> premiumIptalEdildi() async {
    try {
      await _analytics.logEvent(
        name: 'premium_iptal',
        parameters: {},
      );
      debugPrint('📊 [Analytics] Premium iptal edildi');
    } catch (e) {
      debugPrint('❌ [Analytics] Premium iptal hatası: $e');
    }
  }
  
  // ============= REKLAM İŞLEMLERİ =============
  
  /// Reklam görüntülendi
  static Future<void> reklamGoruntulendi(String reklamTipi) async {
    try {
      await _analytics.logEvent(
        name: 'reklam_goruntuleme',
        parameters: {
          'reklam_tipi': reklamTipi, // 'banner', 'native', 'interstitial'
        },
      );
      debugPrint('📊 [Analytics] Reklam görüntülendi: $reklamTipi');
    } catch (e) {
      debugPrint('❌ [Analytics] Reklam görüntüleme hatası: $e');
    }
  }
  
  /// Reklam tıklandı
  static Future<void> reklamTiklandi(String reklamTipi) async {
    try {
      await _analytics.logEvent(
        name: 'reklam_tiklama',
        parameters: {
          'reklam_tipi': reklamTipi,
        },
      );
      debugPrint('📊 [Analytics] Reklam tıklandı: $reklamTipi');
    } catch (e) {
      debugPrint('❌ [Analytics] Reklam tıklama hatası: $e');
    }
  }
  
  // ============= KULLANICI ETKİLEŞİMLERİ =============
  
  /// Tema değiştirildi
  static Future<void> temaDegistirildi(String temaTipi) async {
    try {
      await _analytics.logEvent(
        name: 'tema_degistir',
        parameters: {
          'tema_tipi': temaTipi, // 'koyu' veya 'acik'
        },
      );
      debugPrint('📊 [Analytics] Tema değiştirildi: $temaTipi');
    } catch (e) {
      debugPrint('❌ [Analytics] Tema değiştirme hatası: $e');
    }
  }
  
  /// Uygulama değerlendirme penceresi açıldı
  static Future<void> uygulamaDegerlendirmeAcildi() async {
    try {
      await _analytics.logEvent(
        name: 'uygulama_degerlendirme',
        parameters: {},
      );
      debugPrint('📊 [Analytics] Uygulama değerlendirme açıldı');
    } catch (e) {
      debugPrint('❌ [Analytics] Uygulama değerlendirme hatası: $e');
    }
  }
  
  /// Uygulama paylaşıldı
  static Future<void> uygulamaPaylasildi() async {
    try {
      await _analytics.logEvent(
        name: 'uygulama_paylas',
        parameters: {},
      );
      debugPrint('📊 [Analytics] Uygulama paylaşıldı');
    } catch (e) {
      debugPrint('❌ [Analytics] Uygulama paylaşma hatası: $e');
    }
  }
  
  // ============= KULLANICI ÖZELLİKLERİ =============
  
  /// Kullanıcı özelliklerini güncelle
  static Future<void> kullaniciOzellikleriniGuncelle({
    bool? premiumMu,
    int? toplamAramaSayisi,
    int? kayitliKelimeSayisi,
  }) async {
    try {
      if (premiumMu != null) {
        await _analytics.setUserProperty(
          name: 'premium_mu',
          value: premiumMu ? 'evet' : 'hayir',
        );
      }
      if (toplamAramaSayisi != null) {
        await _analytics.setUserProperty(
          name: 'toplam_arama',
          value: toplamAramaSayisi.toString(),
        );
      }
      if (kayitliKelimeSayisi != null) {
        await _analytics.setUserProperty(
          name: 'kayitli_kelime_sayisi',
          value: kayitliKelimeSayisi.toString(),
        );
      }
      debugPrint('📊 [Analytics] Kullanıcı özellikleri güncellendi');
    } catch (e) {
      debugPrint('❌ [Analytics] Kullanıcı özellikleri hatası: $e');
    }
  }
  
  // ============= HATA RAPORLAMA =============
  
  /// Hata oluştu
  static Future<void> hataOlustu(String hataKodu, String hataAciklama) async {
    try {
      await _analytics.logEvent(
        name: 'hata_olustu',
        parameters: {
          'hata_kodu': hataKodu,
          'hata_aciklama': hataAciklama,
        },
      );
      debugPrint('📊 [Analytics] Hata oluştu: $hataKodu - $hataAciklama');
    } catch (e) {
      debugPrint('❌ [Analytics] Hata raporlama hatası: $e');
    }
  }
} 