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
  
  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();
  
  // Getter'lar
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  List<ProductDetails> get products => _products;
  String get monthlyPrice => _getMonthlyPrice();
  
  Future<void> initialize() async {
    debugPrint('🛒 Abonelik servisi başlatılıyor...');
    
    // Store bağlantısını kontrol et
    _isAvailable = await _inAppPurchase.isAvailable();
    debugPrint('✅ Store kullanılabilir: $_isAvailable');
    
    if (!_isAvailable) {
      debugPrint('❌ In-App Purchase kullanılamıyor!');
      return;
    }
    
    // iOS için pending transaction'ları tamamla
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }
    
    // Satın alma stream'ini dinle
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      debugPrint('❌ Purchase stream hatası: $error');
    });
    
    // Ürünleri yükle
    await loadProducts();
    
    // Mevcut abonelikleri kontrol et
    await restorePurchases();
  }
  
  // Ürünleri yükle
  Future<void> loadProducts() async {
    debugPrint('📦 Ürünler yükleniyor...');
    
    // Gerçek ürün ID'sini kullan
    Set<String> kIds = <String>{_monthlySubscriptionId};
    final ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(kIds);
    
    if (productDetailResponse.error != null) {
      _queryProductError = productDetailResponse.error!.message;
      debugPrint('❌ Ürün yükleme hatası: $_queryProductError');
      _products = productDetailResponse.productDetails;
      notifyListeners();
      return;
    }
    
    if (productDetailResponse.productDetails.isEmpty) {
      _queryProductError = 'Ürün bulunamadı';
      debugPrint('❌ Ürün bulunamadı!');
      _products = productDetailResponse.productDetails;
      notifyListeners();
      return;
    }
    
    _products = productDetailResponse.productDetails;
    debugPrint('✅ ${_products.length} ürün yüklendi');
    
    for (var product in _products) {
      debugPrint('📦 Ürün: ${product.id} - ${product.price}');
    }
    
    notifyListeners();
  }
  
  // Satın alma işlemi
  Future<void> buySubscription() async {
    if (_products.isEmpty) {
      debugPrint('❌ Ürün listesi boş!');
      return;
    }
    
    final ProductDetails productDetails = _products[0];
    
    debugPrint('🛒 Satın alma başlatılıyor: ${productDetails.id}');
    
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: null,
    );
    
    _purchasePending = true;
    notifyListeners();
    
    try {
      // Gerçek abonelik satın alması
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('❌ Satın alma hatası: $e');
      _purchasePending = false;
      notifyListeners();
    }
  }
  
  // Satın alma güncellemelerini dinle
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      debugPrint('🔄 Satın alma durumu: ${purchaseDetails.status}');
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ Satın alma bekleniyor...');
        _purchasePending = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ Satın alma hatası: ${purchaseDetails.error}');
          _purchasePending = false;
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('✅ Satın alma başarılı!');
          
          // Satın almayı doğrula
          bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            // Premium'u aktifleştir
            await _deliverProduct(purchaseDetails);
          } else {
            debugPrint('❌ Satın alma doğrulanamadı!');
            _handleInvalidPurchase(purchaseDetails);
          }
          
          _purchasePending = false;
          notifyListeners();
        }
        
        // Satın alma işlemini tamamla
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
          debugPrint('✅ Satın alma tamamlandı');
        }
      }
    });
  }
  
  // Satın almayı doğrula
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Gerçek uygulamada burada sunucu tarafında doğrulama yapılmalı
    // Receipt validation yapılmalı
    debugPrint('🔍 Satın alma doğrulanıyor...');
    
    // Test için her zaman true dön
    return true;
  }
  
  // Ürünü teslim et
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    debugPrint('📦 Ürün teslim ediliyor...');
    
    // Premium'u aktifleştir (30 gün)
    await _creditsService.activatePremiumMonthly();
    
    _purchases.add(purchaseDetails);
    notifyListeners();
  }
  
  // Geçersiz satın alma
  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('❌ Geçersiz satın alma işlemi');
  }
  
  // Satın almaları geri yükle
  Future<void> restorePurchases() async {
    debugPrint('🔄 Satın almalar geri yükleniyor...');
    
    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ Geri yükleme tamamlandı');
    } catch (e) {
      debugPrint('❌ Geri yükleme hatası: $e');
    }
  }
  
  // Aylık fiyat bilgisi
  String _getMonthlyPrice() {
    if (_products.isEmpty) return '₺60.00/ay';
    
    return '${_products[0].price}/ay';
  }
  
  // Temizlik
  @override
  void dispose() {
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      iosPlatformAddition.setDelegate(null);
    }
    _subscription?.cancel();
    super.dispose();
  }
}

// iOS için Payment Queue Delegate
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
} 