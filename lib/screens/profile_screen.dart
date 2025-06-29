import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/credits_service.dart';
import '../services/subscription_service.dart';

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

  @override
  void initState() {
    super.initState();
    _creditsService.addListener(_updateState);
    _subscriptionService.addListener(_updateState);
    
    // Play Console'dan fiyat bilgilerini yükle
    _loadSubscriptionData();
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
            
            // Kullanım hakları
            if (!_creditsService.isPremium) ...[
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: const Color(0xFF007AFF),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _creditsService.hasInitialCredits 
                              ? 'Ücretsiz Hak' 
                              : 'Günlük Haklar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${_creditsService.credits}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _creditsService.credits == 0
                                ? Colors.red
                                : const Color(0xFF007AFF),
                          ),
                        ),
                        Text(
                          _creditsService.hasInitialCredits ? ' / 100' : ' / 5',
                          style: TextStyle(
                            fontSize: 20,
                            color: isDarkMode 
                                ? Colors.white.withOpacity(0.4)
                                : Colors.black.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _creditsService.hasInitialCredits 
                            ? _creditsService.credits / 100 
                            : _creditsService.credits / 5,
                        minHeight: 6,
                        backgroundColor: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _creditsService.credits == 0
                              ? Colors.red
                              : const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Sistem açıklaması
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: isDarkMode 
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.black.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Nasıl Çalışır?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode 
                                      ? Colors.white.withOpacity(0.8)
                                      : Colors.black.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _creditsService.hasInitialCredits
                                ? '• İlk açılışta 100 ücretsiz hak kazanırsınız\n• Her kelime detayı 1 hak harcar\n• 100 ücretsiz hak bitince günlük yenilenen 5 hakkınız olur\n• Her gün saat 00:00\'da yenilenir'
                                : '• Her gün saat 00:00\'da 5 hakkınız yenilenir',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: isDarkMode 
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Premium önerisi - daha küçük
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
                              'Sınırsız kelime detayları\nReklamsız deneyim',
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

  void _showPremiumDialog() {
    FocusScope.of(context).unfocus();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Üyelik'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Premium üyelik avantajları:'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.all_inclusive, 'Sınırsız kelime detayları'),
            _buildFeatureRow(Icons.block, 'Reklamsız deneyim'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              FocusScope.of(context).unfocus();
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