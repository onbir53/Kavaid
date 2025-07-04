import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUsageService extends ChangeNotifier {
  static const String _totalUsageKey = 'total_app_usage_minutes';
  static const String _lastActiveKey = 'last_active_time';
  static const String _sessionStartKey = 'session_start_time';
  static const String _hasShownRatingKey = 'has_shown_rating_ui';
  
  int _totalUsageMinutes = 0;
  DateTime? _sessionStartTime;
  bool _hasShownRatingUI = false;
  
  // Singleton
  static final AppUsageService _instance = AppUsageService._internal();
  factory AppUsageService() => _instance;
  AppUsageService._internal();
  
  int get totalUsageMinutes => _totalUsageMinutes;
  bool get shouldShowRating => _totalUsageMinutes >= 5 && !_hasShownRatingUI;
  bool get hasShownRatingUI => _hasShownRatingUI;
  
  // Uygulama başlatıldığında çağrılacak
  Future<void> startSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Önceki toplam kullanım süresini yükle
    _totalUsageMinutes = prefs.getInt(_totalUsageKey) ?? 0;
    _hasShownRatingUI = prefs.getBool(_hasShownRatingKey) ?? false;
    
    // Yeni oturum başlat
    _sessionStartTime = DateTime.now();
    await prefs.setString(_sessionStartKey, _sessionStartTime!.toIso8601String());
    
    debugPrint('📱 [AppUsage] Oturum başladı. Toplam kullanım: $_totalUsageMinutes dakika');
    notifyListeners();
  }
  
  // Uygulama arka plana alındığında veya kapatıldığında çağrılacak
  Future<void> endSession() async {
    if (_sessionStartTime == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final sessionDuration = now.difference(_sessionStartTime!).inMinutes;
    
    // Toplam kullanım süresini güncelle
    _totalUsageMinutes += sessionDuration;
    await prefs.setInt(_totalUsageKey, _totalUsageMinutes);
    await prefs.setString(_lastActiveKey, now.toIso8601String());
    
    debugPrint('📱 [AppUsage] Oturum sona erdi. Bu oturum: $sessionDuration dakika, Toplam: $_totalUsageMinutes dakika');
    
    // 5 dakikayı geçtiyse ve henüz gösterilmediyse bildir
    if (_totalUsageMinutes >= 5 && !_hasShownRatingUI) {
      debugPrint('🌟 [AppUsage] 5 dakika kullanım süresi aşıldı! Değerlendirme UI gösterilebilir.');
    }
    
    _sessionStartTime = null;
    notifyListeners();
  }
  
  // Periyodik güncelleme (uygulama açıkken)
  Future<void> updateUsage() async {
    if (_sessionStartTime == null) return;
    
    final now = DateTime.now();
    final currentSessionMinutes = now.difference(_sessionStartTime!).inMinutes;
    final totalMinutes = (await SharedPreferences.getInstance()).getInt(_totalUsageKey) ?? 0;
    
    _totalUsageMinutes = totalMinutes + currentSessionMinutes;
    
    // 5 dakikayı yeni geçtiyse bildir
    if (_totalUsageMinutes >= 5 && !_hasShownRatingUI && totalMinutes < 5) {
      debugPrint('🌟 [AppUsage] 5 dakika kullanım süresi şimdi aşıldı!');
      notifyListeners();
    }
  }
  
  // Değerlendirme UI'si gösterildiğinde çağrılacak
  Future<void> markRatingUIShown() async {
    _hasShownRatingUI = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownRatingKey, true);
    debugPrint('✅ [AppUsage] Değerlendirme UI\'si gösterildi olarak işaretlendi');
    notifyListeners();
  }
  
  // Kullanım istatistiklerini sıfırla (test için)
  Future<void> resetUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_totalUsageKey);
    await prefs.remove(_lastActiveKey);
    await prefs.remove(_sessionStartKey);
    await prefs.remove(_hasShownRatingKey);
    
    _totalUsageMinutes = 0;
    _hasShownRatingUI = false;
    _sessionStartTime = null;
    
    debugPrint('🔄 [AppUsage] Kullanım istatistikleri sıfırlandı');
    notifyListeners();
  }
  
  // TEST: Kullanım süresini ayarla
  Future<void> setUsageTimeForTest(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    _totalUsageMinutes = minutes;
    await prefs.setInt(_totalUsageKey, minutes);
    
    debugPrint('🧪 [AppUsage] TEST: Kullanım süresi $minutes dakikaya ayarlandı');
    notifyListeners();
  }
} 