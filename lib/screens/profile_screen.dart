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
                // Profil kartı
                _buildProfileCard(),
                const SizedBox(height: 16),
                
                // Kullanım hakları
                _buildUsageCard(),
                
                if (!_creditsService.isPremium) ...[
                  const SizedBox(height: 16),
                  _buildPremiumCard(),
                ],
                
                const SizedBox(height: 16),
                // Ayarlar bölümü
                _buildSettingsSection(),
                
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

  Widget _buildProfileCard() {
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
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Profil avatarı
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _creditsService.isPremium
                      ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                      : [const Color(0xFF007AFF), const Color(0xFF0051D5)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_creditsService.isPremium
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF007AFF)).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _creditsService.isPremium
                    ? Icons.workspace_premium
                    : Icons.person,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            // Kullanıcı bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hoş Geldiniz',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF1C1C1E),
                        ),
                      ),
                      if (_creditsService.isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFFA500)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Premium',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _creditsService.isPremium
                        ? 'Premium üyelik aktif'
                        : 'Ücretsiz plan kullanıyorsunuz',
                    style: TextStyle(
                      fontSize: 14,
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
      ),
    );
  }

  Widget _buildUsageCard() {
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
        ],
      ),
      child: Column(
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? const Color(0xFF48484A).withOpacity(0.3)
                      : const Color(0xFFE5E5EA).withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: const Color(0xFF007AFF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Kullanım Özeti',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          
          // İçerik
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!_creditsService.isPremium) ...[
                  // Kredi göstergesi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Günlük Hak',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF636366),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${_creditsService.credits}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _creditsService.credits <= 10
                                  ? Colors.red
                                  : const Color(0xFF007AFF),
                            ),
                          ),
                          Text(
                            ' / 50',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode
                                  ? const Color(0xFF8E8E93)
                                  : const Color(0xFF636366),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _creditsService.credits / 50,
                      minHeight: 8,
                      backgroundColor: isDarkMode
                          ? const Color(0xFF48484A).withOpacity(0.3)
                          : const Color(0xFFE5E5EA),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _creditsService.credits <= 10
                            ? Colors.red
                            : const Color(0xFF007AFF),
                      ),
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF007AFF).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          color: const Color(0xFF007AFF),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sınırsız Erişim',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF1C1C1E),
                                ),
                              ),
                              if (_creditsService.premiumExpiry != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Bitiş: ${_creditsService.premiumExpiry!.day}/${_creditsService.premiumExpiry!.month}/${_creditsService.premiumExpiry!.year}',
                                  style: TextStyle(
                                    fontSize: 12,
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
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
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
        ],
      ),
      child: Column(
        children: [
          // Tema ayarı
          _buildSettingItem(
            icon: widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            title: 'Tema',
            subtitle: widget.isDarkMode ? 'Koyu' : 'Açık',
            onTap: widget.onThemeToggle,
            showDivider: true,
          ),
          
          // Bildirimler
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: 'Bildirimler',
            subtitle: 'Açık',
            onTap: () {
              // Bildirim ayarları
            },
            showDivider: true,
          ),
          
          // Dil ayarı
          _buildSettingItem(
            icon: Icons.language,
            title: 'Uygulama Dili',
            subtitle: 'Türkçe',
            onTap: () {
              // Dil ayarları
            },
            showDivider: true,
          ),
          
          // Hakkında
          _buildSettingItem(
            icon: Icons.info_outline,
            title: 'Hakkında',
            subtitle: 'Versiyon 1.0.0',
            onTap: () {
              // Hakkında sayfası
            },
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    final isDarkMode = widget.isDarkMode;
    
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
                  Icon(
                    Icons.chevron_right,
                    color: isDarkMode
                        ? const Color(0xFF48484A)
                        : const Color(0xFFE5E5EA),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 64,
            color: isDarkMode
                ? const Color(0xFF48484A).withOpacity(0.3)
                : const Color(0xFFE5E5EA).withOpacity(0.5),
          ),
      ],
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