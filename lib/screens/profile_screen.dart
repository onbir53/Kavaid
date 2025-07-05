import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../services/credits_service.dart';
import '../services/one_time_purchase_service.dart';
import '../services/turkce_analytics_service.dart';
import '../services/app_usage_service.dart';
import '../services/global_config_service.dart';
import '../services/admob_service.dart';
import '../widgets/fps_counter_widget.dart';

class ProfileScreen extends StatefulWidget {
  final double bottomPadding;
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const ProfileScreen({
    super.key,
    required this.bottomPadding,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final CreditsService _creditsService = CreditsService();
  final OneTimePurchaseService _purchaseService = OneTimePurchaseService();
  final AppUsageService _appUsageService = AppUsageService();
  final GlobalConfigService _globalConfigService = GlobalConfigService();
  bool _hasRatedApp = false;

  @override
  void initState() {
    super.initState();
    _creditsService.addListener(_updateState);
    _purchaseService.addListener(_updateState);
    _appUsageService.addListener(_updateState);
    _globalConfigService.addListener(_updateState);
    
    // Play Console'dan fiyat bilgilerini yükle
    _loadPurchaseData();
    // Değerlendirme durumunu kontrol et
    _checkRatingStatus();
  }
  
  Future<void> _checkRatingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasRatedApp = prefs.getBool('has_rated_app') ?? false;
    });
  }
  
  Future<void> _setRatedApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_rated_app', true);
    setState(() {
      _hasRatedApp = true;
    });
  }

  Future<void> _loadPurchaseData() async {
    // OneTimePurchaseService henüz başlatılmamışsa başlat
    try {
      if (_purchaseService.products.isEmpty) {
        debugPrint('📦 [PROFILE] One-time purchase service ürünleri yükleniyor...');
        await _purchaseService.initialize();
        debugPrint('✅ [PROFILE] One-time purchase service başlatıldı, ürün sayısı: ${_purchaseService.products.length}');
      }
      
      // Fiyat güncellemesi için UI'ı yenile
      if (mounted) {
        setState(() {});
        debugPrint('🔄 [PROFILE] UI güncellendi, fiyat: ${_purchaseService.removeAdsPrice}');
      }
    } catch (e) {
      debugPrint('❌ [PROFILE] Purchase data yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _creditsService.removeListener(_updateState);
    _purchaseService.removeListener(_updateState);
    _appUsageService.removeListener(_updateState);
    _globalConfigService.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return FPSOverlay(
      showFPS: kDebugMode, // Debug modda FPS göster
      detailedFPS: true,   // Detaylı FPS bilgileri
      child: Scaffold(
      backgroundColor: isDarkMode 
          ? const Color(0xFF1C1C1E) 
          : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF007AFF),
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profil bilgileri - tema switch ile
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? const Color(0xFF1C1C1E) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode 
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFE5E5EA),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kavaid',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  // Tema değiştirme - custom switch
                  Container(
                    width: 50,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: widget.isDarkMode 
                          ? const Color(0xFF007AFF).withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          left: widget.isDarkMode ? 22 : 2,
                          top: 2,
                          child: GestureDetector(
                            onTap: widget.onThemeToggle,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                                  size: 16,
                                  color: widget.isDarkMode 
                                      ? const Color(0xFF007AFF)
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Tıklanabilir alan
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: widget.onThemeToggle,
                            child: Container(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Google Play Değerlendirme Butonu - 30 dakika kullanım sonrası ve değerlendirme yapılmamışsa göster
            if (!_hasRatedApp && _appUsageService.shouldShowRating) ...[
              GestureDetector(
                onTap: _openInAppReview,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? const Color(0xFF2C2C2E) 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode 
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFE5E5EA),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: const Color(0xFFFFD700),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Uygulamayı Değerlendir',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: isDarkMode 
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF6D6D70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // TEST: Debug butonları (sadece debug modda)
            if (!kReleaseMode) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEBUG PANEL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _appUsageService.setUsageTimeForTest(31);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kullanım süresi 31 dakikaya ayarlandı'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text(
                              '31 dakika',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _appUsageService.resetUsageStats();
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('has_rated_app', false);
                              await _checkRatingStatus();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tüm veriler sıfırlandı'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text(
                              'Sıfırla',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Reklam kaldırma durumunu toggle et
                              await _creditsService.toggleAdsFreeForTest();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_creditsService.isLifetimeAdsFree
                                        ? 'Reklamsız kullanım aktif'
                                        : 'Reklamsız kullanım deaktif'),
                                    backgroundColor: _creditsService.isLifetimeAdsFree
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _creditsService.isLifetimeAdsFree
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                            child: Text(
                              _creditsService.isLifetimeAdsFree ? 'Premium AÇ' : 'Premium KAP',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Gerçek satın alma testi
                              try {
                                await _purchaseService.loadProducts();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ürünler yüklendi: ${_purchaseService.products.length}'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ürün yükleme hatası: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                            ),
                            child: Text(
                              'Ürün Test',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Interstitial reklam testi
                              try {
                                final AdMobService adService = AdMobService();
                                adService.forceShowInterstitialAd();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Interstitial reklam test edildi'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reklam test hatası: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                            ),
                            child: Text(
                              'Reklam Test',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Debug durumunu göster
                              final AdMobService adService = AdMobService();
                              adService.debugAdStatus();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Debug bilgileri console\'da'),
                                    backgroundColor: Colors.purple,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                            ),
                            child: Text(
                              'Debug Info',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mevcut kullanım: ${_appUsageService.totalUsageMinutes} dakika',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'Reklamsız durumu: ${_creditsService.isLifetimeAdsFree ? "AKTİF" : "DEAKTİF"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _creditsService.isLifetimeAdsFree ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Play Console: ${_purchaseService.isAvailable ? "BAĞLI" : "BAĞLI DEĞİL"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _purchaseService.isAvailable ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ürün sayısı: ${_purchaseService.products.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _purchaseService.products.isEmpty ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      'Fiyat: ${_purchaseService.removeAdsPrice}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      'AdMob Credits: ${AdMobService().mounted ? "HAZIR" : "BEKLİYOR"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AdMobService().mounted ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text(
                      'Interstitial Ad: ${AdMobService().isInterstitialAdAvailable ? "MEVCUT" : "YOK"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AdMobService().isInterstitialAdAvailable ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      'Native Ad Performance: OPTİMİZE',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Native Ad Mode: DİREKT YÜKLEME',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Performance Mode: KAPALI (Hızlı Yükleme)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 16),
            
            // Paylaşım butonu - UI ile uyumlu
            GestureDetector(
              onTap: _shareApp,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? const Color(0xFF2C2C2E) 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode 
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFE5E5EA),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: const Color(0xFF007AFF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Uygulamayı Paylaş',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDarkMode 
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6D6D70),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Reklam kaldırma önerisi veya durumu
            if (!_creditsService.isLifetimeAdsFree) ...[
              // Reklam kaldırma önerisi
                GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _showPurchaseDialog();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF007AFF).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.block,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reklamları Kaldır',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _purchaseService.removeAdsPrice,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Reklamsız durumu - daha küçük
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF007AFF).withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.all_inclusive,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Reklamsız Kullanım',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _openInAppReview() async {
    try {
      // Analytics event'i gönder
      await TurkceAnalyticsService.uygulamaDegerlendirmeAcildi();
      
      final InAppReview inAppReview = InAppReview.instance;
      
      // Önce uygulama içi değerlendirme mevcut mu kontrol et
      if (await inAppReview.isAvailable()) {
        // Uygulama içinde değerlendirme penceresi aç
        await inAppReview.requestReview();
        debugPrint('✅ Uygulama içi değerlendirme açıldı');
        
        // Değerlendirme açıldığında flag'i set et
        await _setRatedApp();
        
        // AppUsageService'e de bildir
        await _appUsageService.markRatingUIShown();
      } else {
        // Mevcut değilse store sayfasını aç
        debugPrint('⚠️ Uygulama içi değerlendirme mevcut değil, store sayfası açılıyor');
        await _openGooglePlayRating();
      }
    } catch (e) {
      debugPrint('❌ Uygulama içi değerlendirme hatası: $e');
      // Hata durumunda fallback olarak store sayfasını aç
      await _openGooglePlayRating();
    }
  }

  Future<void> _openGooglePlayRating() async {
    const String packageName = 'com.onbir.kavaid';
    final Uri googlePlayUrl = Uri.parse('market://details?id=$packageName');
    final Uri webUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    
    try {
      // Önce Google Play uygulamasını açmayı dene
      if (await canLaunchUrl(googlePlayUrl)) {
        await launchUrl(
          googlePlayUrl,
          mode: LaunchMode.externalApplication,
        );
        // Google Play açıldığında da flag'i set et
        await _setRatedApp();
        // AppUsageService'e de bildir
        await _appUsageService.markRatingUIShown();
      } else if (await canLaunchUrl(webUrl)) {
        // Google Play uygulaması yoksa web'de aç
        await launchUrl(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
        // Web açıldığında da flag'i set et
        await _setRatedApp();
        // AppUsageService'e de bildir
        await _appUsageService.markRatingUIShown();
      } else {
        // Hiçbiri açılamazsa hata göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Play açılamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Google Play değerlendirme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareApp() async {
    try {
      // Uygulama içi işlem flag'ini set et - reklam engellemek için
      AdMobService().setInAppActionFlag('paylaşım');
      
      // Analytics event'i gönder
      await TurkceAnalyticsService.uygulamaPaylasildi();
      
      const String packageName = 'com.onbir.kavaid';
      const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageName';
      
      await Share.share(
        playStoreUrl,
        subject: 'Kavaid - Arapça Sözlük Uygulaması',
      );
      
      debugPrint('✅ Uygulama başarıyla paylaşıldı');
    } catch (e) {
      debugPrint('❌ Paylaşım hatası: $e');
      // Hata durumunda da flag'i temizle
      AdMobService().clearInAppActionFlag();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paylaşım sırasında bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPurchaseDialog() {
    // Güçlü klavye kapatma - dialog açılmadan önce
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    showDialog(
      context: context,
      barrierDismissible: false, // Dışarı tıklayarak kapatmayı engelle
      builder: (context) => SafeArea(
        // 🔧 ANDROID 15 FIX: Dialog safe area padding
        child: WillPopScope(
          onWillPop: () async {
            // Güçlü klavye kapatma - geri tuşu
            FocusManager.instance.primaryFocus?.unfocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
            return true;
          },
          child: AlertDialog(
          title: const Text('Reklamları Kaldır'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ömür boyu reklamsız kullanım'),
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tek Seferlik ',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      _purchaseService.removeAdsPrice,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Güçlü klavye kapatma
                FocusManager.instance.primaryFocus?.unfocus();
                SystemChannels.textInput.invokeMethod('TextInput.hide');
                Navigator.of(context).pop();
                // Çoklu kontrol
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');
                });
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Uygulama içi işlem flag'ini set et - reklam engellemek için
                AdMobService().setInAppActionFlag('satın_alma');
                
                try {
                  // Güçlü klavye kapatma
                  FocusManager.instance.primaryFocus?.unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');
                  Navigator.of(context).pop();
                  // Çoklu kontrol
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                  });
                  await _purchaseService.buyRemoveAds();
                } catch (e) {
                  // Hata durumunda flag'i temizle
                  AdMobService().clearInAppActionFlag();
                  rethrow;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Satın Al'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Color(0xFF007AFF)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
} 