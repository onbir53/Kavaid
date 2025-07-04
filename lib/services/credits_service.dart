import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'device_data_service.dart';
import 'turkce_analytics_service.dart';

class CreditsService extends ChangeNotifier {
  static const String _premiumKey = 'is_premium';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _deviceIdKey = 'device_id';
  
  bool _isPremium = false;
  DateTime? _premiumExpiry;
  String? _deviceId;
  
  // Singleton instance
  static final CreditsService _instance = CreditsService._internal();
  factory CreditsService() => _instance;
  CreditsService._internal();
  
  // Getter'lar
  bool get isPremium => _isPremium && (_premiumExpiry?.isAfter(DateTime.now()) ?? false);
  DateTime? get premiumExpiry => _premiumExpiry;
  bool get isLifetimeAdsFree => _isPremium; // Premium kullanıcıları için reklamsız
  
  Future<void> initialize() async {
    debugPrint('🚀 [CreditsService] Initialize başlıyor...');
    final prefs = await SharedPreferences.getInstance();
    
    // Cihaz ID'sini al veya oluştur
    await _initializeDeviceId(prefs);
    debugPrint('📱 [CreditsService] Cihaz ID: $_deviceId');
    
    // Önce Firebase'den ana cihaz verisini almayı dene
    debugPrint('🔥 [CreditsService] Firebase\'den veriler alınmaya çalışılıyor...');
    final deviceDataService = DeviceDataService();
    final firebaseData = await deviceDataService.getDeviceData();
    
    // Önce reklamsız cihazlar koleksiyonunu kontrol et
    bool isAdFreeDevice = await _checkAdFreeDeviceStatus();
    
    if (firebaseData != null) {
      debugPrint('✅ [CreditsService] Firebase\'de veri bulundu: $firebaseData');
      
      // Eğer cihaz reklamsız listesindeyse veya Firebase'de reklamsız olarak işaretlenmişse
      if (isAdFreeDevice || firebaseData['lifetimeAdsFree'] == true || firebaseData['adFreeForever'] == true) {
        _isPremium = true;
        _premiumExpiry = DateTime.now().add(const Duration(days: 365 * 100)); // 100 yıl
        debugPrint('🔒 [CreditsService] Cihaz reklamsız cihazlar listesinde veya Firebase\'de reklamsız!');
      } else {
        // Normal premium kontrolü
        _isPremium = firebaseData['premiumDurumu'] ?? false;
        
        if (firebaseData['premiumBitisTarihi'] != null) {
          _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(firebaseData['premiumBitisTarihi']);
        }
      }
      
      // Firebase'den alınan verileri SharedPreferences'a da kaydet (cache için)
      final devicePremiumKey = '${_premiumKey}_$_deviceId';
      final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
      
      await prefs.setBool(devicePremiumKey, _isPremium);
      
      if (_premiumExpiry != null) {
        await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
      }
      
      debugPrint('✅ [CreditsService] Firebase\'den veriler yüklendi: Premium: $_isPremium, AdFree: $isAdFreeDevice');
    } else {
      debugPrint('⚠️ [CreditsService] Firebase\'de veri yok');
      
      // Eğer cihaz reklamsız listesindeyse offline bile olsa premium olarak işaretle
      if (isAdFreeDevice) {
        _isPremium = true;
        _premiumExpiry = DateTime.now().add(const Duration(days: 365 * 100)); // 100 yıl
        debugPrint('🔒 [CreditsService] Offline ama cihaz reklamsız listesinde!');
        
        // SharedPreferences'a da kaydet
        final devicePremiumKey = '${_premiumKey}_$_deviceId';
        final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
        
        await prefs.setBool(devicePremiumKey, _isPremium);
        await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
      } else {
        // SharedPreferences'tan yükle
        final devicePremiumKey = '${_premiumKey}_$_deviceId';
        final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
        
        // Premium durumunu yükle
        _isPremium = prefs.getBool(devicePremiumKey) ?? false;
        
        final expiryMillis = prefs.getInt(devicePremiumExpiryKey);
        if (expiryMillis != null) {
          _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
        }
      }
    }
    
    debugPrint('🎯 [CreditsService] Initialize tamamlandı - Premium: $_isPremium, AdFree: $isAdFreeDevice');
    notifyListeners();
  }
  
  // Reklamsız cihaz durumunu kontrol et
  Future<bool> _checkAdFreeDeviceStatus() async {
    try {
      debugPrint('🔍 [CreditsService] Reklamsız cihaz durumu kontrol ediliyor...');
      
      final deviceDataService = DeviceDataService();
      final deviceId = await deviceDataService.getDeviceId();
      
      // Firebase'den reklamsız cihazlar koleksiyonunu kontrol et
      final adFreeDevicesRef = FirebaseDatabase.instance.ref().child('reklamsiz_cihazlar').child(deviceId);
      final snapshot = await adFreeDevicesRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final isActive = data['isActive'] == true;
        final purchaseVerified = data['purchaseVerified'] == true;
        
        if (isActive && purchaseVerified) {
          debugPrint('✅ [CreditsService] Cihaz reklamsız listesinde aktif olarak kayıtlı!');
          
          // Son kontrol zamanını güncelle
          await adFreeDevicesRef.update({
            'lastChecked': DateTime.now().millisecondsSinceEpoch,
          });
          
          return true;
        }
      }
      
      debugPrint('❌ [CreditsService] Cihaz reklamsız listesinde bulunamadı');
      return false;
    } catch (e) {
      debugPrint('❌ [CreditsService] Reklamsız cihaz kontrolü hatası: $e');
      return false;
    }
  }
  
  // Cihaz ID'sini al veya oluştur
  Future<void> _initializeDeviceId(SharedPreferences prefs) async {
    _deviceId = prefs.getString(_deviceIdKey);
    
    if (_deviceId == null) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      
      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          _deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          _deviceId = iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch.toString();
        } else {
          // Diğer platformlar için timestamp tabanlı ID
          _deviceId = DateTime.now().millisecondsSinceEpoch.toString();
        }
      } catch (e) {
        // Hata durumunda timestamp tabanlı ID
        _deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
  }
  
  // Kelime açılımı kontrolü - artık sadece true döndürüyor
  Future<bool> canOpenWord(String wordId) async {
    return true; // Herkes sınırsız kelime açabilir
  }
  
  // Kelime açıldığında - artık hiçbir şey yapmıyor
  Future<bool> consumeCredit(String wordId) async {
    return true; // Her zaman başarılı
  }
  
  // Premium üyelik aktifleştir (60 ay)
  Future<void> activatePremium() async {
    _isPremium = true;
    _premiumExpiry = DateTime.now().add(const Duration(days: 60 * 30)); // 60 ay
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, true);
    await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    // Analytics user properties'ini güncelle
    await TurkceAnalyticsService.kullaniciOzellikleriniGuncelle(premiumMu: _isPremium);
    
    notifyListeners();
  }
  
  // Premium üyelik aktifleştir (1 ay) - Aylık abonelik için
  Future<void> activatePremiumMonthly() async {
    _isPremium = true;
    _premiumExpiry = DateTime.now().add(const Duration(days: 30)); // 1 ay
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, true);
    await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    // Analytics user properties'ini güncelle
    await TurkceAnalyticsService.kullaniciOzellikleriniGuncelle(premiumMu: _isPremium);
    
    notifyListeners();
  }
  
  // GIZLI KOD: Premium üyelik sonsuza kadar aktifleştir
  Future<void> activatePremiumForever() async {
    _isPremium = true;
    // 100 yıl sonraya ayarla (pratikte sonsuza kadar)
    _premiumExpiry = DateTime.now().add(const Duration(days: 365 * 100));
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, true);
    await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    // Analytics user properties'ini güncelle
    await TurkceAnalyticsService.kullaniciOzellikleriniGuncelle(premiumMu: _isPremium);
    
    notifyListeners();
  }
  
  // GIZLI KOD: Premium durumunu toggle et (premium ise free yap, free ise premium yap)
  Future<bool> togglePremiumStatus() async {
    if (isPremium) {
      // Premium'dan free'ye geç
      await cancelPremium();
      return false; // Artık free
    } else {
      // Free'den premium'a geç
      await activatePremiumForever();
      return true; // Artık premium
    }
  }
  
  // Premium durumu kontrol et
  Future<void> checkPremiumStatus() async {
    if (_premiumExpiry != null && _premiumExpiry!.isBefore(DateTime.now())) {
      _isPremium = false;
      final prefs = await SharedPreferences.getInstance();
      final devicePremiumKey = '${_premiumKey}_$_deviceId';
      await prefs.setBool(devicePremiumKey, false);
      notifyListeners();
    }
  }
  
  // Premium'u iptal et (test için)
  Future<void> cancelPremium() async {
    _isPremium = false;
    _premiumExpiry = null;
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, false);
    await prefs.remove(devicePremiumExpiryKey);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    // Analytics user properties'ini güncelle
    await TurkceAnalyticsService.kullaniciOzellikleriniGuncelle(premiumMu: _isPremium);
    
    notifyListeners();
  }
  
  // Firebase'e verileri kaydet
  Future<void> _saveToFirebase() async {
    try {
      debugPrint('💾 [CreditsService] Firebase\'e kaydetme başlıyor...');
      debugPrint('📊 [CreditsService] Kaydedilecek veriler: Premium: $_isPremium');
      
      final deviceDataService = DeviceDataService();
      // Basitleştirilmiş veri kaydı - sadece premium bilgisi
      final Map<String, dynamic> dataToSave = {
        'premiumDurumu': _isPremium,
      };
      
      if (_premiumExpiry != null) {
        dataToSave['premiumBitisTarihi'] = _premiumExpiry!.millisecondsSinceEpoch;
      }
      
      final success = await deviceDataService.saveDeviceData(dataToSave);
      
      if (success) {
        debugPrint('✅ [CreditsService] Firebase\'e veriler başarıyla kaydedildi');
      } else {
        debugPrint('❌ [CreditsService] Firebase\'e veri kaydetme başarısız');
      }
    } catch (e) {
      debugPrint('❌ [CreditsService] Firebase\'e veri kaydetme hatası: $e');
    }
  }
  
  // Eski metotlar için uyumluluk - artık hiçbir şey yapmıyorlar
  int get credits => 999; // Sınırsız gösterim için
  bool get hasInitialCredits => false;
  bool get initialCreditsUsed => true;
  DateTime? get lastResetDate => null;
  
  Future<void> resetCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> useAllInitialCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> resetToInitialCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> simulateMidnightResetForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> useAllDailyCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> checkDailyResetManually() async {
    // Artık bir şey yapmıyor
  }
  
  // Lifetime Ads Free durumunu ayarla (OneTimePurchase için)
  Future<void> setLifetimeAdsFree(bool value) async {
    if (value) {
      // Lifetime ads free = premium forever
      await activatePremiumForever();
    } else {
      // Lifetime ads free'yi kaldır
      await cancelPremium();
    }
  }
  
  // DEBUG: Reklamsız durumunu test için toggle et
  Future<void> toggleAdsFreeForTest() async {
    await togglePremiumStatus();
  }
} 