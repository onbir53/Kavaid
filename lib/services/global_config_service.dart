import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class GlobalConfigService extends ChangeNotifier {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final DatabaseReference _configRef = _database.ref().child('config');
  
  // Singleton instance
  static final GlobalConfigService _instance = GlobalConfigService._internal();
  factory GlobalConfigService() => _instance;
  GlobalConfigService._internal() {
    _initializeListener();
  }
  
  bool _subscriptionDisabled = false;
  bool _isInitialized = false;
  
  // Getter'lar
  bool get subscriptionDisabled => _subscriptionDisabled;
  bool get isInitialized => _isInitialized;
  
  // Firebase listener
  void _initializeListener() {
    debugPrint('🌐 [GlobalConfig] Firebase listener başlatılıyor...');
    
    // subscription_disabled değerini dinle
    _configRef.child('subscription_disabled').onValue.listen((event) {
      final value = event.snapshot.value;
      bool newValue = false;
      
      if (value != null) {
        if (value is bool) {
          newValue = value;
        } else if (value is String) {
          newValue = value.toLowerCase() == 'true';
        }
      }
      
      if (_subscriptionDisabled != newValue) {
        debugPrint('🔄 [GlobalConfig] subscription_disabled değişti: $_subscriptionDisabled -> $newValue');
        _subscriptionDisabled = newValue;
        _isInitialized = true;
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint('❌ [GlobalConfig] Firebase dinleme hatası: $error');
    });
    
    // İlk değeri al
    _loadInitialValue();
  }
  
  // İlk değeri yükle
  Future<void> _loadInitialValue() async {
    try {
      final snapshot = await _configRef.child('subscription_disabled').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        if (value is bool) {
          _subscriptionDisabled = value;
        } else if (value is String) {
          _subscriptionDisabled = value.toLowerCase() == 'true';
        }
      }
      
      _isInitialized = true;
      debugPrint('✅ [GlobalConfig] İlk değer yüklendi: subscription_disabled = $_subscriptionDisabled');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ [GlobalConfig] İlk değer yükleme hatası: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  // Subscription durumunu toggle et
  Future<bool> toggleSubscriptionStatus() async {
    try {
      final newValue = !_subscriptionDisabled;
      
      debugPrint('🔄 [GlobalConfig] Subscription durumu değiştiriliyor: $newValue');
      
      await _configRef.child('subscription_disabled').set(newValue);
      
      debugPrint('✅ [GlobalConfig] Firebase\'e yazıldı: subscription_disabled = $newValue');
      
      // Local değeri hemen güncelle (listener ile de gelecek ama anında yanıt için)
      _subscriptionDisabled = newValue;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      debugPrint('❌ [GlobalConfig] Toggle hatası: $e');
      return false;
    }
  }
  
  // Manuel olarak sıfırla (test için)
  Future<void> resetSubscriptionStatus() async {
    try {
      await _configRef.child('subscription_disabled').set(false);
      debugPrint('✅ [GlobalConfig] Subscription durumu sıfırlandı');
    } catch (e) {
      debugPrint('❌ [GlobalConfig] Sıfırlama hatası: $e');
    }
  }
} 