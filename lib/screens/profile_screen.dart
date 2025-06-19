import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/credits_service.dart';
import '../services/subscription_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const ProfileScreen({
    super.key,
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
          ? const Color(0xFF000000) 
          : const Color(0xFFFFFFFF),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kullanıcı bilgileri - daha küçük
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? const Color(0xFF1C1C1E) 
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
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
                          'Hoş Geldiniz',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _creditsService.isPremium
                              ? 'Premium Üye'
                              : 'Ücretsiz Kullanıcı',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode 
                                ? Colors.white.withOpacity(0.6)
                                : Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_creditsService.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
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
                              ? 'Hoşgeldin Hakları' 
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
                          _creditsService.hasInitialCredits ? ' / 50' : ' / 5',
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
                            ? _creditsService.credits / 50 
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
                                ? '• İlk açılışta 50 ücretsiz hak kazanırsınız\n• Her kelime detayı 1 hak harcar\n• 50 ücretsiz hak bitince günlük yenilenen 5 hakkınız olur\n• Her gün saat 00:00\'da yenilenir'
                                : '• Her gün saat 00:00\'da 5 yeni hak kazanırsınız\n• Günlük haklar birikemez\n• Premium ile sınırsız erişim\n• Telefon açıp kapama, silip yükleme sistemi bozmaz',
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
                          '₺60/Ay',
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
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PREMIUM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
            
            const SizedBox(height: 24),
            
            // Ayarlar
            Text(
              'Ayarlar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            
            // Tema değiştirme
            Container(
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? const Color(0xFF1C1C1E) 
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 20,
                ),
                title: Text(
                  'Tema',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  isDarkMode ? 'Koyu tema' : 'Açık tema',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode 
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.6),
                  ),
                ),
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isDarkMode,
                    onChanged: (_) => widget.onThemeToggle(),
                    activeColor: const Color(0xFF007AFF),
                  ),
                ),
              ),
            ),
            
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              Text(
                'Geliştirici Araçları',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              _buildTestButtons(),
            ],
          ],
        ),
      ),
    );
  }

  void _showPremiumDialog() {
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
                    '60 TL',
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

  Widget _buildTestButtons() {
    final isDarkMode = widget.isDarkMode;
    
    return Column(
      children: [
        // Durum Bilgisi
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF1C1C1E) 
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF007AFF).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SİSTEM DURUMU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF007AFF),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusRow('Krediler', '${_creditsService.credits}', isDarkMode),
              _buildStatusRow('İlk Haklar', _creditsService.hasInitialCredits ? 'Aktif' : 'Bitti', isDarkMode),
              _buildStatusRow('Premium', _creditsService.isPremium ? 'Aktif' : 'Pasif', isDarkMode),
              if (_creditsService.premiumExpiry != null)
                _buildStatusRow('Premium Bitiş', 
                    '${_creditsService.premiumExpiry!.day}/${_creditsService.premiumExpiry!.month}/${_creditsService.premiumExpiry!.year}', 
                    isDarkMode),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Temel Test İşlemleri
        Text(
          'TEMEL TEST İŞLEMLERİ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF007AFF),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        
        // Hak sıfırlama
        _buildTestButton(
          icon: Icons.refresh,
          title: 'Hakları Sıfırla',
          subtitle: _creditsService.hasInitialCredits ? 'İlk hakları 50\'ye sıfırla' : 'Günlük hakları 5\'e sıfırla',
          color: Colors.orange,
          onTap: () async {
            await _creditsService.resetCreditsForTesting();
            _showTestResult('Haklar sıfırlandı! Krediler: ${_creditsService.credits}');
          },
          isDarkMode: isDarkMode,
        ),
        
        const SizedBox(height: 8),
        
        // İlk kredileri bitir
        if (_creditsService.hasInitialCredits) ...[
          _buildTestButton(
            icon: Icons.fast_forward,
            title: 'İlk Kredileri Bitir',
            subtitle: 'Günlük 5 hak sistemine geç',
            color: Colors.purple,
            onTap: () async {
              await _creditsService.useAllInitialCreditsForTesting();
              _showTestResult('İlk krediler bitirildi! Günlük sisteme geçildi.');
            },
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 8),
        ],
        
        // Premium toggle
        _buildTestButton(
          icon: _creditsService.isPremium ? Icons.remove_circle : Icons.add_circle,
          title: _creditsService.isPremium ? 'Premium\'u İptal Et' : 'Premium Aktifleştir',
          subtitle: _creditsService.isPremium ? 'Sınırlı sisteme geri dön' : '30 günlük premium ver',
          color: _creditsService.isPremium ? Colors.red : Colors.green,
          onTap: () async {
            if (_creditsService.isPremium) {
              await _creditsService.cancelPremium();
              _showTestResult('Premium iptal edildi! Artık sınırlı sistem aktif.');
            } else {
              await _creditsService.activatePremiumMonthly();
              _showTestResult('Premium aktifleştirildi! Sınırsız erişim kazandınız.');
            }
          },
          isDarkMode: isDarkMode,
        ),
        
        const SizedBox(height: 16),
        
        // Gelişmiş Test İşlemleri
        Text(
          'GELİŞMİŞ TEST İŞLEMLERİ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.red,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        
        // Yeni gün simülasyonu
        if (!_creditsService.hasInitialCredits) ...[
          _buildTestButton(
            icon: Icons.schedule,
            title: 'Yeni Gün Simülasyonu',
            subtitle: 'Günlük hakları yenile (sadece günlük sistemde)',
            color: Colors.blue,
            onTap: () async {
              // Manuel olarak günlük sistemi tetikle
              final prefs = await SharedPreferences.getInstance();
              final now = DateTime.now();
              final turkeyTime = now.toUtc().add(const Duration(hours: 3));
              final yesterday = turkeyTime.subtract(const Duration(days: 1));
              await prefs.setString('last_reset_date', yesterday.toIso8601String());
              
              // Servisi yeniden başlat
              await _creditsService.initialize();
              _showTestResult('Yeni gün simülasyonu tamamlandı! Günlük haklar yenilendi.');
            },
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 8),
        ],
        
        // Sistemi tamamen sıfırla
        _buildTestButton(
          icon: Icons.delete_forever,
          title: 'SİSTEMİ TAMAMEN SIFIRLA',
          subtitle: 'TEHLİKELİ: İlk kurulum durumuna döner',
          color: Colors.red,
          onTap: () => _showResetConfirmation(),
          isDarkMode: isDarkMode,
        ),
        
        const SizedBox(height: 8),
        
        // Kelime test et
        _buildTestButton(
          icon: Icons.search,
          title: 'Kelime Açma Testi',
          subtitle: 'Hak düşürme sistemini test et',
          color: Colors.indigo,
          onTap: () => _testWordOpening(),
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }
  
  Widget _buildStatusRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode 
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTestButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF1C1C1E) 
            : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode 
                ? Colors.white.withOpacity(0.6)
                : Colors.black.withOpacity(0.6),
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
  
  void _showTestResult(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF007AFF),
        ),
      );
    }
  }
  
  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ TEHLİKELİ İŞLEM'),
        content: const Text(
          'Bu işlem tüm kullanıcı verilerini siler ve uygulamayı ilk kurulum durumuna döndürür.\n\n'
          'Sistem sıfırlandıktan sonra:\n'
          '• 50 yeni ücretsiz hak verilir\n'
          '• Premium iptal edilir\n'
          '• Tüm geçmiş silinir\n\n'
          'Devam etmek istediğinizden emin misiniz?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetCompleteSystem();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SIFIRLA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _resetCompleteSystem() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Tüm anahtarları sil
    await prefs.clear();
    
    // Servisi yeniden başlat
    await _creditsService.initialize();
    
    _showTestResult('SİSTEM TAMAMEN SIFIRLANDI! İlk kurulum durumuna döndü.');
  }
  
  void _testWordOpening() async {
    final testWordId = 'test_kelime_${DateTime.now().millisecondsSinceEpoch}';
    
    if (_creditsService.isPremium) {
      _showTestResult('Premium aktif - Sınırsız erişim var!');
      return;
    }
    
    final canOpen = await _creditsService.canOpenWord(testWordId);
    
    if (canOpen) {
      final success = await _creditsService.consumeCredit(testWordId);
      if (success) {
        _showTestResult('✅ Kelime açıldı! Kalan hak: ${_creditsService.credits}');
      } else {
        _showTestResult('❌ Kelime açılamadı - Hak yetersiz!');
      }
    } else {
      _showTestResult('❌ Hak yetersiz - Kelime açılamaz!');
    }
  }
} 