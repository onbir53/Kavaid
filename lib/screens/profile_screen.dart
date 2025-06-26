import 'package:flutter/material.dart';
import '../services/credits_service.dart';
import '../services/subscription_service.dart';
import '../services/device_data_service.dart';

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

            // Debug Test Butonu (sadece debug modda)
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'Hak Sistemi Test',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // İlk 100 hak sistemi testleri
                  Text(
                    '100 Hak Sistemi:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testUseAllInitialCredits,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('100 Hakkı Bitir', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testResetToInitial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('100 Hakka Sıfırla', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Günlük 5 hak sistemi testleri
                  Text(
                    'Günlük 5 Hak Sistemi:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testDailyReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Gece Yarısı Sim.', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testUseDailyCredits,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('5 Hakkı Bitir', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Firebase testleri
                  Text(
                    'Firebase Test:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testFirebaseSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Firebase\'e Kaydet', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testFirebaseLoad,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Firebase\'den Yükle', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Güvenlik testi
                  Text(
                    'Güvenlik Test:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final deviceDataService = DeviceDataService();
                      final serverTime = await deviceDataService.getTurkeyServerTime();
                      final localTime = deviceDataService.getCurrentTurkeyTime();
                      
                      final message = serverTime != null 
                        ? 'Türkiye Server Saati (timezone): $serverTime\nYerel Türkiye Saati (timezone): $localTime'
                        : 'Server saati alınamadı\nYerel Türkiye Saati (timezone): $localTime';
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message, style: const TextStyle(fontSize: 12))),
                        );
                      }
                    },
                    child: const Text('🇹🇷 Türkiye Saat Test'),
                  ),
                  
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      // Günlük hak sistemi durumunu kontrol et
                      final creditsService = CreditsService();
                      await creditsService.initialize();
                      
                      final deviceDataService = DeviceDataService();
                      final serverTime = await deviceDataService.getTurkeyServerTime();
                      final localTime = deviceDataService.getCurrentTurkeyTime();
                      
                      final currentTime = serverTime ?? localTime;
                      final todayMidnight = deviceDataService.getTurkeyMidnight(currentTime);
                      final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));
                      final timeToMidnight = tomorrowMidnight.difference(currentTime);
                      
                      final message = '''
📊 HAK SİSTEMİ DURUMU:
💰 Mevcut hak: ${creditsService.credits}
👑 Premium: ${creditsService.isPremium}
🔄 İlk 100 bitti: ${creditsService.initialCreditsUsed}

⏰ ZAMAN BİLGİSİ:
🇹🇷 Türkiye saati: ${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}:${currentTime.second.toString().padLeft(2, '0')}
🌙 Son sıfırlama: ${creditsService.lastResetDate}
⏳ Gece yarısına: ${timeToMidnight.inHours}s ${timeToMidnight.inMinutes % 60}d ${timeToMidnight.inSeconds % 60}sn''';
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message, style: const TextStyle(fontSize: 10)),
                            duration: const Duration(seconds: 8),
                          ),
                        );
                      }
                    },
                    child: const Text('📊 Günlük Hak Durumu'),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Mevcut durum bilgisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mevcut Durum:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kredi: ${_creditsService.credits}\n'
                          'Sistem: ${_creditsService.hasInitialCredits ? "100 Hak (İlk)" : "5 Hak (Günlük)"}\n'
                          'Premium: ${_creditsService.isPremium ? "Aktif" : "Pasif"}\n'
                          '🔒 Güvenlik: Server Saati Korumalı',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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

  void _testFirebaseSave() async {
    print('🧪 [Test] Firebase kaydetme testi başlıyor...');
    try {
      final deviceDataService = DeviceDataService();
      final success = await deviceDataService.saveCreditsData(
        credits: 123,
        isPremium: false,
        initialCreditsUsed: false,
        sessionOpenedWords: ['test1', 'test2'],
      );
      
      if (success) {
        print('✅ [Test] Firebase kaydetme başarılı!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Firebase\'e test verisi kaydedildi!')),
        );
      } else {
        print('❌ [Test] Firebase kaydetme başarısız!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Firebase kaydetme başarısız!')),
        );
      }
    } catch (e) {
      print('❌ [Test] Firebase kaydetme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e')),
      );
    }
  }

  void _testFirebaseLoad() async {
    print('🧪 [Test] Firebase yükleme testi başlıyor...');
    try {
      final deviceDataService = DeviceDataService();
      final data = await deviceDataService.getDeviceData();
      
      if (data != null) {
        print('✅ [Test] Firebase\'den veri yüklendi: $data');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Veri yüklendi: ${data['krediler']} kredi')),
        );
      } else {
        print('⚠️ [Test] Firebase\'de veri bulunamadı');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Firebase\'de veri bulunamadı')),
        );
      }
    } catch (e) {
      print('❌ [Test] Firebase yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e')),
      );
    }
  }

  void _testUseAllInitialCredits() async {
    print('🧪 [Test] İlk 100 hakkı bitirme testi başlıyor...');
    try {
      await _creditsService.useAllInitialCreditsForTesting();
      print('✅ [Test] İlk 100 hak bitti, günlük sisteme geçildi');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ İlk 100 hak bitti! Artık günlük 5 hak sistemindesiniz.')),
      );
      setState(() {}); // UI güncelle
    } catch (e) {
      print('❌ [Test] İlk hak bitirme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e')),
      );
    }
  }

  void _testResetToInitial() async {
    print('🧪 [Test] 100 hakka sıfırlama testi başlıyor...');
    try {
      await _creditsService.resetToInitialCreditsForTesting();
      print('✅ [Test] 100 hak sistemi geri yüklendi');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 100 hak sistemi geri yüklendi!')),
      );
      setState(() {}); // UI güncelle
    } catch (e) {
      print('❌ [Test] 100 hak sıfırlama hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e')),
      );
    }
  }

  void _testDailyReset() async {
    print('🧪 [Test] Gece yarısı simülasyonu başlıyor...');
    try {
      await _creditsService.simulateMidnightResetForTesting();
      print('✅ [Test] Gece yarısı geçti, günlük haklar yenilendi');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🌙 Gece yarısı geçti! 5 yeni hakkınız var.')),
      );
      setState(() {}); // UI güncelle
    } catch (e) {
      print('❌ [Test] Gece yarısı simülasyon hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e')),
      );
    }
  }

  void _testUseDailyCredits() async {
    print('🧪 [Test] Günlük 5 hakkı bitirme testi başlıyor...');
    try {
      await _creditsService.useAllDailyCreditsForTesting();
      print('✅ [Test] Günlük 5 hak bitti');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Günlük 5 hak bitti! Yarın saat 00:00\'da yenilenecek.')),
      );
      setState(() {}); // UI güncelle
    } catch (e) {
      print('❌ [Test] Günlük hak bitirme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e')),
      );
    }
  }
} 