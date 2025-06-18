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
                  const SizedBox(height: 12),
                  _buildPremiumCard(),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
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
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF1C1C1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF48484A).withOpacity(0.3)
              : const Color(0xFFE5E5EA).withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık satırı
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.stars_rounded,
                        color: const Color(0xFF007AFF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kullanım Hakları',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _creditsService.isPremium 
                                ? 'Premium üyelik aktif'
                                : 'Günlük ${_creditsService.credits} hak kaldı',
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDarkMode
                                  ? const Color(0xFF8E8E93)
                                  : const Color(0xFF636366),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_creditsService.isPremium) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Premium',
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
                
                // İçerik
                if (!_creditsService.isPremium) ...[
                  const SizedBox(height: 20),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _creditsService.credits / 50,
                      backgroundColor: widget.isDarkMode
                          ? const Color(0xFF48484A).withOpacity(0.3)
                          : const Color(0xFFE5E5EA),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _creditsService.credits <= 10 
                            ? Colors.red 
                            : const Color(0xFF007AFF),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_creditsService.credits} / 50 hak',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _creditsService.credits <= 10 
                              ? Colors.red 
                              : widget.isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                        ),
                      ),
                      Text(
                        'Günlük yenilenir',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDarkMode
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF636366),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          color: const Color(0xFF007AFF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sınırsız Erişim',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF007AFF),
                                ),
                              ),
                              if (_creditsService.premiumExpiry != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Bitiş: ${_creditsService.premiumExpiry!.day}/${_creditsService.premiumExpiry!.month}/${_creditsService.premiumExpiry!.year}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.isDarkMode
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
        ),
      ),
    );
  }

  Widget _buildPremiumCard() {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF1C1C1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF48484A).withOpacity(0.3)
              : const Color(0xFFE5E5EA).withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Üst kısım - Icon ve başlık
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium Üyelik',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subscriptionService.monthlyPrice,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Özellikler listesi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF2C2C2E).withOpacity(0.5)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        icon: Icons.all_inclusive,
                        text: 'Sınırsız kelime görüntüleme',
                        isDarkMode: widget.isDarkMode,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        icon: Icons.bookmark_border,
                        text: 'Sınırsız kelime kaydetme',
                        isDarkMode: widget.isDarkMode,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        icon: Icons.block,
                        text: 'Reklam yok',
                        isDarkMode: widget.isDarkMode,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        icon: Icons.rocket_launch_outlined,
                        text: 'Öncelikli destek',
                        isDarkMode: widget.isDarkMode,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Satın al butonu
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                        : Text(
                            _subscriptionService.isAvailable
                                ? 'Premium\'a Geç'
                                : 'Şu anda kullanılamıyor',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Alt bilgi metni
                Text(
                  'İstediğiniz zaman iptal edebilirsiniz',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDarkMode
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF636366),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String text,
    required bool isDarkMode,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF007AFF),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestButtons() {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF1C1C1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF48484A).withOpacity(0.3)
              : const Color(0xFFE5E5EA).withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bug_report,
                    color: Colors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test İşlemleri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Geliştirme modunda',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDarkMode
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF636366),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  'Hakları Bitir',
                  Colors.red,
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
    );
  }

  Widget _buildTestButton(String label, Color color, VoidCallback onPressed) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
} 
} 