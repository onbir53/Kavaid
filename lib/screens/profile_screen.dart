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
          : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: <Widget>[
          // Üst başlık alanı - sözlük gibi
          SliverAppBar(
            backgroundColor: isDarkMode 
                ? const Color(0xFF1C1C1E)
                : const Color(0xFF007AFF),
            elevation: 0,
            pinned: true,
            floating: true,
            snap: true,
            toolbarHeight: 0,
            expandedHeight: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                width: double.infinity,
                color: isDarkMode 
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFF007AFF),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: isDarkMode
                            ? const Color(0xFF48484A).withOpacity(0.3)
                            : const Color(0xFFE5E5EA).withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.person_rounded,
                            color: isDarkMode
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF8E8E93),
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Profil',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Tema değiştirme butonu
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onThemeToggle,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.08)
                                      : const Color(0xFF8E8E93).withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.isDarkMode 
                                      ? Icons.dark_mode 
                                      : Icons.light_mode,
                                  color: isDarkMode
                                      ? const Color(0xFF8E8E93).withOpacity(0.8)
                                      : const Color(0xFF8E8E93),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: isDarkMode
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF007AFF),
                          Color(0xFF0051D5),
                        ],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : const Color(0xFF007AFF).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          
          // İçerik
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 90),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHakBilgileriCard(),
                if (!_creditsService.isPremium) ...[
                  const SizedBox(height: 16),
                  _buildPremiumCard(),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  _buildTestButtons(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHakBilgileriCard() {
    final isDarkMode = widget.isDarkMode;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode 
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFFAFAFA),
                ],
              ),
        color: isDarkMode ? const Color(0xFF1C1C1E) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
              ? const Color(0xFF48484A)
              : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF007AFF).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          if (!isDarkMode) ...[
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 1,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Text(
              'Kullanım Hakları',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            
            if (!_creditsService.isPremium) ...[
              // Kredi göstergesi
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${_creditsService.credits}',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: _creditsService.credits <= 10 
                          ? Colors.red 
                          : const Color(0xFF007AFF),
                      height: 1,
                    ),
                  ),
                  Text(
                    ' / 50',
                    style: TextStyle(
                      fontSize: 20,
                      color: isDarkMode
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF636366),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'hak',
                    style: TextStyle(
                      fontSize: 17,
                      color: isDarkMode
                          ? const Color(0xFFE5E5EA)
                          : const Color(0xFF1C1C1E),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isDarkMode
                      ? const Color(0xFF48484A).withOpacity(0.3)
                      : const Color(0xFFE5E5EA),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _creditsService.credits / 50,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _creditsService.credits <= 10 
                          ? Colors.red 
                          : const Color(0xFF007AFF),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Bilgi metni
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? const Color(0xFF3A3A3C).withOpacity(0.3)
                      : const Color(0xFFE5E5EA).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDarkMode
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF636366),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Her kelime detayı görüntülediğinizde 1 hak harcanır. Günlük yenilenir.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF636366),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Premium durumu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF007AFF).withOpacity(0.1),
                      const Color(0xFF0051D5).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.all_inclusive,
                                color: const Color(0xFF007AFF),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sınırsız Erişim',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF1C1C1E),
                                ),
                              ),
                            ],
                          ),
                          if (_creditsService.premiumExpiry != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Bitiş: ${_creditsService.premiumExpiry!.day}/${_creditsService.premiumExpiry!.month}/${_creditsService.premiumExpiry!.year}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF636366),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard() {
    final isDarkMode = widget.isDarkMode;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode 
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFFAFAFA),
                ],
              ),
        color: isDarkMode ? const Color(0xFF1C1C1E) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
              ? const Color(0xFF48484A)
              : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF007AFF).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          if (!isDarkMode) ...[
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 1,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Üst gradient şerit
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve fiyat
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.workspace_premium,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Premium Üyelik',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1C1C1E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _subscriptionService.monthlyPrice,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Özellikler
                  _buildFeatureItem(
                    icon: Icons.all_inclusive,
                    title: 'Sınırsız Erişim',
                    subtitle: 'Tüm kelimelere sınırsız erişim',
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    icon: Icons.bookmark,
                    title: 'Sınırsız Kaydetme',
                    subtitle: 'İstediğiniz kadar kelime kaydedin',
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    icon: Icons.block,
                    title: 'Reklamsız Deneyim',
                    subtitle: 'Kesintisiz öğrenme deneyimi',
                    isDarkMode: isDarkMode,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Satın al butonu
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _subscriptionService.purchasePending || !_subscriptionService.isAvailable
                          ? null
                          : () async {
                              try {
                                await _subscriptionService.buySubscription();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Satın alma hatası: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _subscriptionService.purchasePending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.rocket_launch,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _subscriptionService.isAvailable
                                          ? 'Premium\'a Geç'
                                          : 'Şu anda kullanılamıyor',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'İstediğiniz zaman iptal edebilirsiniz',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF636366),
                      ),
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

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF3A3A3C).withOpacity(0.3)
            : const Color(0xFFE5E5EA).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF007AFF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF636366),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButtons() {
    final isDarkMode = widget.isDarkMode;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode 
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFFAFAFA),
                ],
              ),
        color: isDarkMode ? const Color(0xFF1C1C1E) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
              ? const Color(0xFF48484A)
              : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF007AFF).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          if (!isDarkMode) ...[
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 1,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Üst gradient şerit
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.orange.shade800],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.bug_report,
                          color: Colors.orange.shade700,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Test İşlemleri',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sadece geliştirme modunda kullanılabilir',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF636366),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Test butonları
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTestButton(
                        'Hakları Bitir',
                        Colors.red,
                        Icons.remove_circle_outline,
                        () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('user_credits', 0);
                          await _creditsService.initialize();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Haklar bitti!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      if (!_creditsService.isPremium) ...[
                        _buildTestButton(
                          'Premium Aktifleştir',
                          Colors.green,
                          Icons.star_rounded,
                          () async {
                            await _creditsService.activatePremiumMonthly();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test: Aylık premium aktif!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                      ] else ...[
                        _buildTestButton(
                          'Free Test',
                          Colors.blue,
                          Icons.card_giftcard,
                          () async {
                            await _creditsService.cancelPremium();
                            await _creditsService.resetCredits();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Premium iptal edildi, 50 hak verildi'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
} 