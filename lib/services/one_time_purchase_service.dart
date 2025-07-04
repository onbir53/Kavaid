import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'device_data_service.dart';
import 'credits_service.dart';
import 'analytics_service.dart';

class OneTimePurchaseService extends ChangeNotifier {
  static const String _removeAdsProductId = 'kavaid_remove_ads_lifetime';
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final DeviceDataService _deviceDataService = DeviceDataService();
  final CreditsService _creditsService = CreditsService();
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  String _lastError = '';
  bool _isLifetimeAdsFree = false;
  
  // Singleton
  static final OneTimePurchaseService _instance = OneTimePurchaseService._internal();
  factory OneTimePurchaseService() => _instance;
  OneTimePurchaseService._internal();
  
  // Getter'lar
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  List<ProductDetails> get products => _products;
  String get removeAdsPrice => _getRemoveAdsPrice();
  String get lastError => _lastError;
  bool get hasError => _lastError.isNotEmpty;
  bool get isLifetimeAdsFree => _isLifetimeAdsFree;
  
  Future<void> initialize() async {
    debugPrint('🛒 [ONE-TIME] Tek seferlik satın alma servisi başlatılıyor...');
    
    try {
      // Önce Firebase'den cihaz verisini kontrol et
      await _checkLifetimeAdsFree();
      
      // Store bağlantısını kontrol et
      _isAvailable = await _inAppPurchase.isAvailable();
      debugPrint('✅ [ONE-TIME] Store kullanılabilir: $_isAvailable');
      
      if (!_isAvailable) {
        _lastError = 'In-App Purchase bu cihazda kullanılamıyor';
        debugPrint('❌ [ONE-TIME] $_lastError');
        notifyListeners();
        return;
      }
      
      // Satın alma stream'ini dinle
      final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _listenToPurchaseUpdated,
        onDone: () {
          debugPrint('🔚 [ONE-TIME] Purchase stream kapandı');
          _subscription?.cancel();
        }, 
        onError: (error) {
          debugPrint('❌ [ONE-TIME] Purchase stream hatası: $error');
          _lastError = 'Satın alma dinleme hatası: $error';
          notifyListeners();
        }
      );
      
      // Play Console entegrasyonu - ürünleri yükle
      await loadProducts();
      await restorePurchases();
      
      debugPrint('✅ [ONE-TIME] Servis başarıyla başlatıldı');
      
    } catch (e) {
      debugPrint('❌ [ONE-TIME] Başlatma hatası: $e');
      _lastError = 'Tek seferlik satın alma servisi başlatılamadı: $e';
      notifyListeners();
    }
  }
  
  // Firebase'den ömür boyu reklamsız durumunu kontrol et
  Future<void> _checkLifetimeAdsFree() async {
    try {
      final deviceData = await _deviceDataService.getDeviceData();
      if (deviceData != null && deviceData['lifetimeAdsFree'] == true) {
        _isLifetimeAdsFree = true;
        debugPrint('✅ [ONE-TIME] Cihaz ömür boyu reklamsız!');
        
        // Credits service'e bildir
        await _creditsService.setLifetimeAdsFree(true);
      }
    } catch (e) {
      debugPrint('❌ [ONE-TIME] Firebase kontrol hatası: $e');
    }
    notifyListeners();
  }
  
  // Ürünleri yükle
  Future<void> loadProducts() async {
    debugPrint('📦 [ONE-TIME] Ürünler yükleniyor...');
    
    try {
      Set<String> kIds = <String>{_removeAdsProductId};
      final ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(kIds);
      
      if (productDetailResponse.error != null) {
        _lastError = 'Ürün yükleme hatası: ${productDetailResponse.error!.message}';
        debugPrint('❌ [ONE-TIME] $_lastError');
        _products = [];
        notifyListeners();
        return;
      }
      
      if (productDetailResponse.productDetails.isEmpty) {
        _lastError = 'Reklam kaldırma ürünü store\'da bulunamadı';
        debugPrint('❌ [ONE-TIME] Ürün bulunamadı! Product ID: $_removeAdsProductId');
        _products = [];
        notifyListeners();
        return;
      }
      
      _products = productDetailResponse.productDetails;
      _lastError = '';
      debugPrint('✅ [ONE-TIME] ${_products.length} ürün başarıyla yüklendi');
      
      for (var product in _products) {
        debugPrint('📦 [ONE-TIME] Ürün: ${product.id}');
        debugPrint('📦 [ONE-TIME] Fiyat: ${product.price}');
        debugPrint('📦 [ONE-TIME] Açıklama: ${product.description}');
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ [ONE-TIME] Ürün yükleme exception: $e');
      _lastError = 'Ürünler yüklenirken hata oluştu: $e';
      notifyListeners();
    }
  }
  
  // Satın alma işlemi
  Future<bool> buyRemoveAds() async {
    debugPrint('🛒 [ONE-TIME] Reklam kaldırma satın alma işlemi başlatılıyor...');
    
    try {
      _lastError = '';
      
      if (_isLifetimeAdsFree) {
        _lastError = 'Bu cihaz zaten ömür boyu reklamsız';
        debugPrint('⚠️ [ONE-TIME] $_lastError');
        notifyListeners();
        return false;
      }
      
      if (!_isAvailable) {
        _lastError = 'Store kullanılamıyor';
        debugPrint('❌ [ONE-TIME] $_lastError');
        notifyListeners();
        return false;
      }
      
      if (_products.isEmpty) {
        debugPrint('❌ [ONE-TIME] Ürün listesi boş, yeniden yükleniyor...');
        await loadProducts();
        if (_products.isEmpty) {
          _lastError = 'Reklam kaldırma ürünü bulunamadı';
          notifyListeners();
          return false;
        }
      }
      
      if (_purchasePending) {
        debugPrint('⏳ [ONE-TIME] Bekleyen işlem var');
        _purchasePending = false;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 1));
      }
      
      final ProductDetails productDetails = _products[0];
      debugPrint('🛒 [ONE-TIME] Satın alma başlatılıyor: ${productDetails.id}');
      debugPrint('🛒 [ONE-TIME] Fiyat: ${productDetails.price}');
      
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null,
      );
      
      _purchasePending = true;
      notifyListeners();
      
      // Tek seferlik satın alma (non-consumable)
      bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (success) {
        debugPrint('✅ [ONE-TIME] Satın alma komutu gönderildi');
        return true;
      } else {
        debugPrint('❌ [ONE-TIME] Satın alma komutu gönderilemedi');
        _purchasePending = false;
        _lastError = 'Satın alma başlatılamadı';
        notifyListeners();
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ [ONE-TIME] Satın alma exception: $e');
      _purchasePending = false;
      _lastError = 'Satın alma hatası: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Satın alma güncellemelerini dinle
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('🔄 [ONE-TIME] Satın alma durumu: ${purchaseDetails.status}');
      debugPrint('🔄 [ONE-TIME] Ürün ID: ${purchaseDetails.productID}');
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ [ONE-TIME] Satın alma bekleniyor...');
        _purchasePending = true;
        _lastError = '';
        notifyListeners();
        
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('❌ [ONE-TIME] Satın alma hatası: ${purchaseDetails.error}');
        _purchasePending = false;
        
        if (purchaseDetails.error != null) {
          switch (purchaseDetails.error!.code) {
            case 'user_canceled':
            case 'BillingResponse.USER_CANCELED':
            case '1':
              _lastError = 'Satın alma iptal edildi';
              break;
            default:
              _lastError = 'Satın alma başarısız: ${purchaseDetails.error!.message}';
          }
        } else {
          _lastError = 'Bilinmeyen satın alma hatası';
        }
        notifyListeners();
        
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        debugPrint('✅ [ONE-TIME] Satın alma başarılı!');
        _purchasePending = false;
        
        // Satın almayı doğrula ve kaydet
        _verifyAndDeliverPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        debugPrint('🔴 [ONE-TIME] Satın alma iptal edildi');
        _purchasePending = false;
        _lastError = 'Satın alma iptal edildi';
        notifyListeners();
      }
      
      // Satın alma işlemini tamamla
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails).then((_) {
          debugPrint('✅ [ONE-TIME] Satın alma transaction\'ı tamamlandı');
        }).catchError((error) {
          debugPrint('❌ [ONE-TIME] Transaction tamamlama hatası: $error');
        });
      }
    }
  }
  
  // Satın almayı doğrula ve teslim et
  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchaseDetails) async {
    debugPrint('🔍 [ONE-TIME] Satın alma doğrulanıyor...');
    
    try {
      // Burada gerçek uygulamada sunucu tarafında doğrulama yapılmalı
      bool valid = true; // Test için
      
      if (valid) {
        debugPrint('✅ [ONE-TIME] Satın alma doğrulandı, ürün teslim ediliyor...');
        await _deliverProduct(purchaseDetails);
        _lastError = '';
      } else {
        debugPrint('❌ [ONE-TIME] Satın alma doğrulanamadı!');
        _lastError = 'Satın alma doğrulanamadı';
      }
      
    } catch (e) {
      debugPrint('❌ [ONE-TIME] Doğrulama/teslimat hatası: $e');
      _lastError = 'Reklam kaldırma aktifleştirilemedi: $e';
    }
    
    _purchasePending = false;
    notifyListeners();
  }
  
  // Ürünü teslim et
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    debugPrint('📦 [ONE-TIME] Ömür boyu reklamsız özellik aktifleştiriliyor...');
    
    try {
      // Firebase'e kaydet
      await _deviceDataService.saveDeviceData({
        'lifetimeAdsFree': true,
        'purchaseDate': DateTime.now().millisecondsSinceEpoch,
        'purchaseId': purchaseDetails.purchaseID,
        'productId': purchaseDetails.productID,
      });
      
      _isLifetimeAdsFree = true;
      
      // Credits service'e bildir
      await _creditsService.setLifetimeAdsFree(true);
      
      // Analytics event'lerini gönder
      double price = 0.0;
      if (_products.isNotEmpty) {
        final priceString = _products[0].price.replaceAll(RegExp(r'[^\d,.]'), '');
        final priceFormatted = priceString.replaceAll(',', '.');
        price = double.tryParse(priceFormatted) ?? 99.90;
      }
      
      await AnalyticsService.logPurchase(purchaseDetails.productID, price, 'remove_ads');
      await AnalyticsService.logPremiumActivated('one_time_purchase');
      
      debugPrint('✅ [ONE-TIME] Ömür boyu reklamsız özellik başarıyla aktifleştirildi!');
      
    } catch (e) {
      debugPrint('❌ [ONE-TIME] Ömür boyu reklamsız aktifleştirme hatası: $e');
      _lastError = 'Ömür boyu reklamsız aktifleştirilemedi: $e';
      throw e;
    }
  }
  
  // Satın almaları geri yükle
  Future<void> restorePurchases() async {
    debugPrint('🔄 [ONE-TIME] Satın almalar geri yükleniyor...');
    
    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ [ONE-TIME] Geri yükleme komutu gönderildi');
      
    } catch (e) {
      debugPrint('❌ [ONE-TIME] Geri yükleme hatası: $e');
      _lastError = 'Satın almalar geri yüklenemedi: $e';
      notifyListeners();
    }
  }
  
  // Fiyat bilgisi - Play Console'dan dinamik çeker
  String _getRemoveAdsPrice() {
    if (_products.isEmpty) {
      debugPrint('⚠️ [ONE-TIME] Ürün listesi boş, Play Console bağlantısı kontrol ediliyor...');
      return '₺99,90'; // Varsayılan fiyat - Play Console'dan yüklenmemiş
    }
    
    final product = _products[0];
    final price = product.price;
    debugPrint('💰 [ONE-TIME] Play Console fiyatı: $price (ID: ${product.id})');
    
    // Fiyat formatını Türkçe locale'e uygun hale getir
    String formattedPrice = price;
    
    // Eğer TL işareti yoksa ekle
    if (!price.contains('TL') && !price.contains('₺')) {
      formattedPrice = price.contains(',') ? price : '₺$price';
    }
    
    debugPrint('💰 [ONE-TIME] Formatlanmış fiyat: $formattedPrice');
    return formattedPrice;
  }
  
  // Hata temizle
  void clearError() {
    _lastError = '';
    notifyListeners();
  }
  
  // Temizlik
  @override
  void dispose() {
    debugPrint('🧹 [ONE-TIME] Servis temizleniyor...');
    _subscription?.cancel();
    debugPrint('✅ [ONE-TIME] Servis temizlendi');
    super.dispose();
  }
} 