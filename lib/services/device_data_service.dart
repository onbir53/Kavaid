import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class DeviceDataService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final DatabaseReference _devicesRef = _database.ref().child('cihazlar');
  
  // Singleton instance
  static final DeviceDataService _instance = DeviceDataService._internal();
  factory DeviceDataService() => _instance;
  DeviceDataService._internal() {
    _initializeTimezone();
  }
  
  String? _deviceId;
  bool _timezoneInitialized = false;
  
  // Timezone'ı initialize et
  void _initializeTimezone() {
    if (!_timezoneInitialized) {
      tz.initializeTimeZones();
      _timezoneInitialized = true;
      debugPrint('🌍 [DeviceData] Timezone data yüklendi');
    }
  }
  
  // Cihaz ID'sini al veya oluştur
  Future<String> getDeviceId() async {
    if (_deviceId != null) {
      debugPrint('📱 [DeviceData] Mevcut cihaz ID kullanılıyor: $_deviceId');
      return _deviceId!;
    }
    
    debugPrint('🔍 [DeviceData] Yeni cihaz ID oluşturuluyor...');
    final deviceInfoPlugin = DeviceInfoPlugin();
    String rawDeviceId;
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        rawDeviceId = androidInfo.id;
        debugPrint('📱 [DeviceData] Ham Android ID alındı: $rawDeviceId');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        rawDeviceId = iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch.toString();
        debugPrint('📱 [DeviceData] Ham iOS ID alındı: $rawDeviceId');
      } else {
        // Diğer platformlar için timestamp tabanlı ID
        rawDeviceId = DateTime.now().millisecondsSinceEpoch.toString();
        debugPrint('📱 [DeviceData] Ham Timestamp ID oluşturuldu: $rawDeviceId');
      }
    } catch (e) {
      // Hata durumunda timestamp tabanlı ID
      rawDeviceId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('❌ [DeviceData] Cihaz ID alma hatası, timestamp kullanılıyor: $rawDeviceId, Hata: $e');
    }
    
    // Firebase için geçersiz karakterleri temizle: .#$[]
    _deviceId = rawDeviceId
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_');
    
    debugPrint('✅ [DeviceData] Temizlenmiş cihaz ID hazır: $_deviceId (Ham: $rawDeviceId)');
    return _deviceId!;
  }
  
  // Cihaz verilerini Firebase'den al
  Future<Map<String, dynamic>?> getDeviceData() async {
    try {
      final deviceId = await getDeviceId();
      debugPrint('🔍 [DeviceData] Firebase\'den veri alınıyor, Cihaz ID: $deviceId');
      
      final snapshot = await _devicesRef.child(deviceId).get();
      
      if (!snapshot.exists) {
        debugPrint('🔍 [DeviceData] Firebase\'de cihaz verisi bulunamadı');
        return null;
      }
      
      final data = snapshot.value as Map<dynamic, dynamic>;
      final deviceData = Map<String, dynamic>.from(data.map((k, v) => MapEntry(k.toString(), v)));
      
      debugPrint('✅ [DeviceData] Firebase\'den cihaz verisi alındı: $deviceData');
      return deviceData;
    } catch (e) {
      debugPrint('❌ [DeviceData] Firebase\'den veri alma hatası: $e');
      return null;
    }
  }
  
  // Cihaz verilerini Firebase'e kaydet
  Future<bool> saveDeviceData(Map<String, dynamic> data) async {
    try {
      final deviceId = await getDeviceId();
      debugPrint('💾 [DeviceData] Firebase\'e kaydetme başlıyor, Cihaz ID: $deviceId');
      debugPrint('📊 [DeviceData] Kaydedilecek veri: $data');
      
      // Son güncelleme zamanını ekle
      data['sonGuncelleme'] = ServerValue.timestamp;
      
      await _devicesRef.child(deviceId).update(data);
      
      debugPrint('✅ [DeviceData] Firebase\'e cihaz verisi kaydedildi');
      return true;
    } catch (e) {
      debugPrint('❌ [DeviceData] Firebase\'e veri kaydetme hatası: $e');
      return false;
    }
  }
  
  // Premium bilgilerini kaydet (Artık sadece premium bilgisi kaydediliyor)
  Future<bool> saveCreditsData({
    required int credits,
    required bool isPremium,
    DateTime? premiumExpiry,
    required bool initialCreditsUsed,
    DateTime? lastResetDate,
    List<String>? sessionOpenedWords,
  }) async {
    try {
      debugPrint('💳 [DeviceData] Premium verisi kaydetme başlıyor...');
      
      // Artık sadece premium bilgisi kaydediliyor
      final data = {
        'premiumDurumu': isPremium,
        'premiumBitisTarihi': premiumExpiry?.millisecondsSinceEpoch,
      };
      
      debugPrint('💳 [DeviceData] Hazırlanan premium verisi: $data');
      
      final success = await saveDeviceData(data);
      
      if (success) {
        debugPrint('✅ [DeviceData] Premium verisi başarıyla kaydedildi');
      } else {
        debugPrint('❌ [DeviceData] Premium verisi kaydetme başarısız');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ [DeviceData] Premium verisi kaydetme hatası: $e');
      return false;
    }
  }
  
  // İlk açılış kontrolü
  Future<bool> isDeviceFirstLaunch() async {
    try {
      final deviceData = await getDeviceData();
      return deviceData == null || deviceData['ilkAcilis'] != false;
    } catch (e) {
      debugPrint('❌ [DeviceData] İlk açılış kontrol hatası: $e');
      return true;
    }
  }
  
  // İlk açılışı işaretle
  Future<void> markDeviceFirstLaunch() async {
    try {
      await saveDeviceData({'ilkAcilis': false});
    } catch (e) {
      debugPrint('❌ [DeviceData] İlk açılış işaretleme hatası: $e');
    }
  }
  
  // Firebase server timestamp al (güvenlik için)
  Future<DateTime?> getServerTimestamp() async {
    try {
      debugPrint('🕐 [DeviceData] Firebase server timestamp alınıyor...');
      
      // Temporary bir key ile server timestamp oluştur
      final tempRef = _database.ref().child('server_time_check').push();
      await tempRef.set({
        'timestamp': ServerValue.timestamp,
      });
      
      // Oluşturulan veriyi oku
      final snapshot = await tempRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final serverTimestamp = data['timestamp'] as int;
        
        // Temporary veriyi sil
        await tempRef.remove();
        
        final serverTime = DateTime.fromMillisecondsSinceEpoch(serverTimestamp);
        debugPrint('✅ [DeviceData] Server timestamp alındı: $serverTime');
        
        return serverTime;
      }
      
      debugPrint('❌ [DeviceData] Server timestamp alınamadı');
      return null;
    } catch (e) {
      debugPrint('❌ [DeviceData] Server timestamp hatası: $e');
      return null;
    }
  }
  
  // Türkiye saati için server timestamp al (timezone ile doğru hesaplama)
  Future<DateTime?> getTurkeyServerTime() async {
    final serverTime = await getServerTimestamp();
    if (serverTime != null) {
      try {
        // Server saatini UTC olarak al
        final utcTime = tz.TZDateTime.from(serverTime, tz.UTC);
        
        // Türkiye timezone'ını al (Europe/Istanbul)
        final turkeyLocation = tz.getLocation('Europe/Istanbul');
        
        // UTC'den Türkiye saatine çevir
        final turkeyTime = tz.TZDateTime.from(utcTime, turkeyLocation);
        
        debugPrint('🇹🇷 [DeviceData] Türkiye server saati (timezone): $turkeyTime');
        debugPrint('📍 [DeviceData] Timezone: ${turkeyLocation.name}, Offset: ${turkeyTime.timeZoneOffset}');
        
        // Türkiye saatini DateTime'a çevir (timezone bilgisini koru)
        return DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day, 
                       turkeyTime.hour, turkeyTime.minute, turkeyTime.second, 
                       turkeyTime.millisecond);
      } catch (e) {
        debugPrint('❌ [DeviceData] Timezone çevirme hatası: $e');
        // Fallback: Manuel UTC+3 ekleme
        final turkeyTime = serverTime.add(const Duration(hours: 3));
        debugPrint('🇹🇷 [DeviceData] Türkiye server saati (fallback): $turkeyTime');
        return turkeyTime;
      }
    }
    return null;
  }
  
  // Mevcut Türkiye saatini al (server saati yoksa yerel saat)
  DateTime getCurrentTurkeyTime() {
    try {
      final now = DateTime.now();
      final utcTime = tz.TZDateTime.from(now.toUtc(), tz.UTC);
      
      // Türkiye timezone'ını al
      final turkeyLocation = tz.getLocation('Europe/Istanbul');
      
      // UTC'den Türkiye saatine çevir
      final turkeyTime = tz.TZDateTime.from(utcTime, turkeyLocation);
      
      debugPrint('🇹🇷 [DeviceData] Mevcut Türkiye saati (timezone): $turkeyTime');
      
      // Türkiye saatini DateTime'a çevir (timezone bilgisini koru)
      return DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day, 
                     turkeyTime.hour, turkeyTime.minute, turkeyTime.second, 
                     turkeyTime.millisecond);
    } catch (e) {
      debugPrint('❌ [DeviceData] Yerel timezone çevirme hatası: $e');
      // Fallback: Manuel UTC+3 ekleme
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      debugPrint('🇹🇷 [DeviceData] Mevcut Türkiye saati (fallback): $turkeyTime');
      return turkeyTime;
    }
  }
  
  // Türkiye saatine göre gece yarısı hesapla (00:00:00)
  DateTime getTurkeyMidnight(DateTime turkeyTime) {
    return DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
  }
} 