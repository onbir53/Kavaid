import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'credits_service.dart';

class SubscriptionService extends ChangeNotifier {
  static const String _monthlySubscriptionId = 'kavaid_monthly_subscription';
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final CreditsService _creditsService = CreditsService();
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  String _queryProductError = '';
  String _lastError = '';
  
  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();
  
  // Getter'lar
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  List<ProductDetails> get products => _products;
  String get monthlyPrice => _getMonthlyPrice();
  String get lastError => _lastError;
  bool get hasError => _lastError.isNotEmpty;
  
  Future<void> initialize() async {
    debugPrint('🛒 [SUBSCRIPTION] Abonelik servisi başlatılıyor...');
    
    try {
      // Store bağlantısını kontrol et
      _isAvailable = await _inAppPurchase.isAvailable();
      debugPrint('✅ [SUBSCRIPTION] Store kullanılabilir: $_isAvailable');
      
      if (!_isAvailable) {
        _lastError = 'In-App Purchase bu cihazda kullanılamıyor';
        debugPrint('❌ [SUBSCRIPTION] $_lastError');
        notifyListeners();
        return;
      }
      
      // iOS için pending transaction'ları tamamla
      if (Platform.isIOS) {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        await iosPlatformAddition.setDelegate(KavaidPaymentQueueDelegate());
        debugPrint('✅ [SUBSCRIPTION] iOS Payment Queue Delegate ayarlandı');
      }
      
      // Satın alma stream'ini dinle
      final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _listenToPurchaseUpdated,
        onDone: () {
          debugPrint('🔚 [SUBSCRIPTION] Purchase stream kapandı');
          _subscription?.cancel();
        }, 
        onError: (error) {
          debugPrint('❌ [SUBSCRIPTION] Purchase stream hatası: $error');
          _lastError = 'Satın alma dinleme hatası: $error';
          notifyListeners();
        }
      );
      
      // Ürünleri yükle
      await loadProducts();
      
      // Mevcut abonelikleri kontrol et
      await restorePurchases();
      
      debugPrint('✅ [SUBSCRIPTION] Servis başarıyla başlatıldı');
      
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Başlatma hatası: $e');
      _lastError = 'Abonelik servisi başlatılamadı: $e';
      notifyListeners();
    }
  }
  
  // Ürünleri yükle
  Future<void> loadProducts() async {
    debugPrint('📦 [SUBSCRIPTION] Ürünler yükleniyor...');
    
    try {
      // Gerçek ürün ID'sini kullan
      Set<String> kIds = <String>{_monthlySubscriptionId};
      final ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(kIds);
      
      if (productDetailResponse.error != null) {
        _queryProductError = productDetailResponse.error!.message;
        _lastError = 'Ürün yükleme hatası: $_queryProductError';
        debugPrint('❌ [SUBSCRIPTION] $_lastError');
        debugPrint('❌ [SUBSCRIPTION] Error Code: ${productDetailResponse.error!.code}');
        _products = [];
        notifyListeners();
        return;
      }
      
      if (productDetailResponse.productDetails.isEmpty) {
        _queryProductError = 'Ürün bulunamadı';
        _lastError = 'Abonelik ürünü store\'da bulunamadı. Lütfen daha sonra tekrar deneyin.';
        debugPrint('❌ [SUBSCRIPTION] Ürün bulunamadı! Product ID: $_monthlySubscriptionId');
        debugPrint('❌ [SUBSCRIPTION] Store\'da ürün tanımlı mı kontrol edin');
        _products = [];
        notifyListeners();
        return;
      }
      
      _products = productDetailResponse.productDetails;
      _lastError = ''; // Başarılı yükleme, hata temizle
      debugPrint('✅ [SUBSCRIPTION] ${_products.length} ürün başarıyla yüklendi');
      
      for (var product in _products) {
        debugPrint('📦 [SUBSCRIPTION] Ürün: ${product.id}');
        debugPrint('📦 [SUBSCRIPTION] Fiyat: ${product.price}');
        debugPrint('📦 [SUBSCRIPTION] Açıklama: ${product.description}');
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Ürün yükleme exception: $e');
      _lastError = 'Ürünler yüklenirken hata oluştu: $e';
      notifyListeners();
    }
  }
  
  // Satın alma işlemi
  Future<bool> buySubscription() async {
    debugPrint('🛒 [SUBSCRIPTION] Satın alma işlemi başlatılıyor...');
    
    try {
      // Hata temizle
      _lastError = '';
      
      if (!_isAvailable) {
        _lastError = 'Store kullanılamıyor';
        debugPrint('❌ [SUBSCRIPTION] $_lastError');
        notifyListeners();
        return false;
      }
      
      if (_products.isEmpty) {
        debugPrint('❌ [SUBSCRIPTION] Ürün listesi boş, yeniden yükleniyor...');
        await loadProducts();
        if (_products.isEmpty) {
          _lastError = 'Abonelik ürünü bulunamadı';
          notifyListeners();
          return false;
        }
      }
      
      if (_purchasePending) {
        _lastError = 'Zaten bir satın alma işlemi devam ediyor';
        debugPrint('⏳ [SUBSCRIPTION] $_lastError');
        notifyListeners();
        return false;
      }
      
      final ProductDetails productDetails = _products[0];
      debugPrint('🛒 [SUBSCRIPTION] Satın alma başlatılıyor: ${productDetails.id}');
      debugPrint('🛒 [SUBSCRIPTION] Fiyat: ${productDetails.price}');
      
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null,
      );
      
      _purchasePending = true;
      notifyListeners();
      
      // Platform'a göre satın alma türü seç
      bool success;
      if (Platform.isIOS || productDetails.id.contains('subscription')) {
        success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      if (success) {
        debugPrint('✅ [SUBSCRIPTION] Satın alma komutu gönderildi');
        return true;
      } else {
        debugPrint('❌ [SUBSCRIPTION] Satın alma komutu gönderilemedi');
        _purchasePending = false;
        _lastError = 'Satın alma başlatılamadı';
        notifyListeners();
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Satın alma exception: $e');
      _purchasePending = false;
      _lastError = 'Satın alma hatası: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Satın alma güncellemelerini dinle
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('🔄 [SUBSCRIPTION] Satın alma durumu: ${purchaseDetails.status}');
      debugPrint('🔄 [SUBSCRIPTION] Ürün ID: ${purchaseDetails.productID}');
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ [SUBSCRIPTION] Satın alma bekleniyor...');
        _purchasePending = true;
        _lastError = '';
        notifyListeners();
        
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('❌ [SUBSCRIPTION] Satın alma hatası: ${purchaseDetails.error}');
        _purchasePending = false;
        
        // Kullanıcı dostu hata mesajları
        if (purchaseDetails.error != null) {
          switch (purchaseDetails.error!.code) {
            case 'user_canceled':
              _lastError = 'Satın alma iptal edildi';
              break;
            case 'payment_invalid':
              _lastError = 'Ödeme bilgileri geçersiz';
              break;
            case 'payment_not_allowed':
              _lastError = 'Bu cihazda satın alma yapılamıyor';
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
        debugPrint('✅ [SUBSCRIPTION] Satın alma başarılı!');
        
        // Satın almayı doğrula
        _verifyAndDeliverPurchase(purchaseDetails);
      }
      
      // Satın alma işlemini tamamla
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails).then((_) {
          debugPrint('✅ [SUBSCRIPTION] Satın alma transaction\'ı tamamlandı');
        }).catchError((error) {
          debugPrint('❌ [SUBSCRIPTION] Transaction tamamlama hatası: $error');
        });
      }
    }
  }
  
  // Satın almayı doğrula ve teslim et
  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchaseDetails) async {
    debugPrint('🔍 [SUBSCRIPTION] Satın alma doğrulanıyor...');
    
    try {
      // Gerçek uygulamada burada sunucu tarafında doğrulama yapılmalı
      bool valid = await _verifyPurchase(purchaseDetails);
      
      if (valid) {
        debugPrint('✅ [SUBSCRIPTION] Satın alma doğrulandı, ürün teslim ediliyor...');
        await _deliverProduct(purchaseDetails);
        _lastError = '';
      } else {
        debugPrint('❌ [SUBSCRIPTION] Satın alma doğrulanamadı!');
        _lastError = 'Satın alma doğrulanamadı';
        _handleInvalidPurchase(purchaseDetails);
      }
      
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Doğrulama/teslimat hatası: $e');
      _lastError = 'Abonelik aktifleştirilemedi: $e';
    }
    
    _purchasePending = false;
    notifyListeners();
  }
  
  // Satın almayı doğrula
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    debugPrint('🔍 [SUBSCRIPTION] Receipt doğrulanıyor...');
    
    // Gerçek uygulamada burada:
    // 1. Purchase token'ı sunucuya gönder
    // 2. Google Play Billing API veya App Store API ile doğrula
    // 3. Receipt'i kaydet
    // 4. Abonelik durumunu takip et
    
    // Test için her zaman true dön
    await Future.delayed(const Duration(milliseconds: 500)); // Gerçekçi gecikme
    debugPrint('✅ [SUBSCRIPTION] Receipt doğrulandı (test modu)');
    
    return true;
  }
  
  // Ürünü teslim et
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    debugPrint('📦 [SUBSCRIPTION] Premium abonelik aktifleştiriliyor...');
    
    try {
      // Premium'u aktifleştir (30 gün)
      await _creditsService.activatePremiumMonthly();
      
      _purchases.add(purchaseDetails);
      debugPrint('✅ [SUBSCRIPTION] Premium başarıyla aktifleştirildi!');
      
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Premium aktifleştirme hatası: $e');
      _lastError = 'Premium aktifleştirilemedi: $e';
      throw e;
    }
  }
  
  // Geçersiz satın alma
  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('❌ [SUBSCRIPTION] Geçersiz satın alma: ${purchaseDetails.productID}');
    // Gerçek uygulamada burada fraud prevention yapılabilir
  }
  
  // Satın almaları geri yükle
  Future<void> restorePurchases() async {
    debugPrint('🔄 [SUBSCRIPTION] Satın almalar geri yükleniyor...');
    
    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ [SUBSCRIPTION] Geri yükleme komutu gönderildi');
      // Sonuçlar _listenToPurchaseUpdated'de işlenecek
      
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Geri yükleme hatası: $e');
      _lastError = 'Satın almalar geri yüklenemedi: $e';
      notifyListeners();
    }
  }
  
  // Aylık fiyat bilgisi
  String _getMonthlyPrice() {
    if (_products.isEmpty) {
      debugPrint('⚠️ [SUBSCRIPTION] Ürün listesi boş, varsayılan fiyat döndürülüyor');
      return '60 TL';
    }
    
    final price = _products[0].price;
    debugPrint('💰 [SUBSCRIPTION] Fiyat bilgisi: $price');
    return price;
  }
  
  // Hata temizle
  void clearError() {
    _lastError = '';
    notifyListeners();
  }
  
  // Abonelik durumunu kontrol et
  Future<void> checkSubscriptionStatus() async {
    debugPrint('🔍 [SUBSCRIPTION] Abonelik durumu kontrol ediliyor...');
    
    try {
      // Gerçek uygulamada burada sunucu API'si ile abonelik durumu kontrol edilir
      await _creditsService.checkPremiumStatus();
      debugPrint('✅ [SUBSCRIPTION] Abonelik durumu güncellendi');
      
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Durum kontrol hatası: $e');
    }
  }
  
  // Temizlik
  @override
  void dispose() {
    debugPrint('🧹 [SUBSCRIPTION] Servis temizleniyor...');
    
    if (Platform.isIOS) {
      try {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        iosPlatformAddition.setDelegate(null);
        debugPrint('✅ [SUBSCRIPTION] iOS delegate temizlendi');
      } catch (e) {
        debugPrint('⚠️ [SUBSCRIPTION] iOS delegate temizleme hatası: $e');
      }
    }
    
    _subscription?.cancel();
    debugPrint('✅ [SUBSCRIPTION] Servis temizlendi');
    super.dispose();
  }
}

// iOS için Payment Queue Delegate
class KavaidPaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    debugPrint('🍎 [iOS] Transaction devam etsin mi? ${transaction.transactionIdentifier}');
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    debugPrint('🍎 [iOS] Fiyat onayı gösterilsin mi?');
    return false;
  }
} 