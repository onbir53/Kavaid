import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class DeviceDataService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final DatabaseReference _devicesRef = _database.ref().child('cihazlar');
  
  // Singleton instance
  static final DeviceDataService _instance = DeviceDataService._internal();
  factory DeviceDataService() => _instance;
  DeviceDataService._internal();
  
  String? _deviceId;
  
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
  
  // Kredi bilgilerini kaydet
  Future<bool> saveCreditsData({
    required int credits,
    required bool isPremium,
    DateTime? premiumExpiry,
    required bool initialCreditsUsed,
    DateTime? lastResetDate,
    List<String>? sessionOpenedWords,
  }) async {
    try {
      debugPrint('💳 [DeviceData] Kredi verisi kaydetme başlıyor...');
      
      final data = {
        'krediler': credits,
        'premiumDurumu': isPremium,
        'premiumBitisTarihi': premiumExpiry?.millisecondsSinceEpoch,
        'ilkKredilerKullanildi': initialCreditsUsed,
        'sonSifirlamaTarihi': lastResetDate?.toIso8601String(),
        'oturumAcilanKelimeler': sessionOpenedWords ?? [],
      };
      
      debugPrint('💳 [DeviceData] Hazırlanan kredi verisi: $data');
      
      final success = await saveDeviceData(data);
      
      if (success) {
        debugPrint('✅ [DeviceData] Kredi verisi başarıyla kaydedildi');
      } else {
        debugPrint('❌ [DeviceData] Kredi verisi kaydetme başarısız');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ [DeviceData] Kredi verisi kaydetme hatası: $e');
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
} 