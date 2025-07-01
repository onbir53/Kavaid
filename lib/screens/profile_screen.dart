import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/credits_service.dart';
import '../services/subscription_service.dart';
import '../services/analytics_service.dart';

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
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _hasRatedApp = false;

  @override
  void initState() {
    super.initState();
    _creditsService.addListener(_updateState);
    _subscriptionService.addListener(_updateState);
    
    // Play Console'dan fiyat bilgilerini yükle
    _loadSubscriptionData();
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

  Future<void> _loadSubscriptionData() async {
    // SubscriptionService henüz başlatılmamışsa başlat
    try {
      if (_subscriptionService.products.isEmpty) {
        debugPrint('📦 [PROFILE] Subscription service ürünleri yükleniyor...');
        await _subscriptionService.initialize();
        debugPrint('✅ [PROFILE] Subscription service başlatıldı, ürün sayısı: ${_subscriptionService.products.length}');
      }
      
      // Fiyat güncellemesi için UI'ı yenile
      if (mounted) {
        setState(() {});
        debugPrint('🔄 [PROFILE] UI güncellendi, fiyat: ${_subscriptionService.monthlyPrice}');
      }
    } catch (e) {
      debugPrint('❌ [PROFILE] Subscription data yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _creditsService.removeListener(_updateState);
    _subscriptionService.removeListener(_updateState);
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
    
    return Scaffold(
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
            // Kullanıcı bilgileri - daha küçük
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
                      color: _creditsService.isPremium
                          ? const Color(0xFF007AFF)
                          : const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _creditsService.isPremium
                          ? Icons.workspace_premium
                          : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _creditsService.isPremium
                              ? 'Premium Üye'
                              : 'Ücretsiz Kullanıcı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
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
            
            // Google Play Değerlendirme Butonu - sadece değerlendirme yapılmamışsa göster
            if (!_hasRatedApp) ...[
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

            const SizedBox(height: 16),
            
            // Premium önerisi veya durumu
            if (!_creditsService.isPremium) ...[
              // Premium önerisi
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _showPremiumDialog();
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
                          Icons.rocket_launch,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium\'a Yükselt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reklamları kaldır',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_subscriptionService.monthlyPrice}/Ay',
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
              // Premium durumu - daha küçük
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Premium Aktif',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Sınırsız Erişim',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_creditsService.premiumExpiry != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Bitiş: ${_creditsService.premiumExpiry!.day}/${_creditsService.premiumExpiry!.month}/${_creditsService.premiumExpiry!.year}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInAppReview() async {
    try {
      // Analytics event'i gönder
      await AnalyticsService.logAppRating();
      
      final InAppReview inAppReview = InAppReview.instance;
      
      // Önce uygulama içi değerlendirme mevcut mu kontrol et
      if (await inAppReview.isAvailable()) {
        // Uygulama içinde değerlendirme penceresi aç
        await inAppReview.requestReview();
        debugPrint('✅ Uygulama içi değerlendirme açıldı');
        
        // Değerlendirme açıldığında flag'i set et
        await _setRatedApp();
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
      } else if (await canLaunchUrl(webUrl)) {
        // Google Play uygulaması yoksa web'de aç
        await launchUrl(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
        // Web açıldığında da flag'i set et
        await _setRatedApp();
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

  void _showPremiumDialog() {
    // Güçlü klavye kapatma - dialog açılmadan önce
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    showDialog(
      context: context,
      barrierDismissible: false, // Dışarı tıklayarak kapatmayı engelle
      builder: (context) => WillPopScope(
        onWillPop: () async {
          // Güçlü klavye kapatma - geri tuşu
          FocusManager.instance.primaryFocus?.unfocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
          return true;
        },
        child: AlertDialog(
          title: const Text('Premium'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Premium ile reklamları kaldırın.'),
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
                      'Aylık ',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      _subscriptionService.monthlyPrice,
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
                // Güçlü klavye kapatma
                FocusManager.instance.primaryFocus?.unfocus();
                SystemChannels.textInput.invokeMethod('TextInput.hide');
                Navigator.of(context).pop();
                // Çoklu kontrol
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');
                });
                await _subscriptionService.buySubscription();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Abone Ol'),
            ),
          ],
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