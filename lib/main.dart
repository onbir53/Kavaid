import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/connectivity_service.dart';
import 'screens/home_screen.dart';
import 'screens/saved_words_screen.dart';
import 'services/firebase_options.dart';
import 'services/saved_words_service.dart';
import 'services/admob_service.dart';
import 'widgets/banner_ad_widget.dart';
import 'services/credits_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // AdMob'u güvenli şekilde başlat
  try {
    await AdMobService.initialize();
  } catch (e) {
    debugPrint('❌ AdMob başlatılamadı: $e');
  }
  
  // SavedWordsService'i initialize et
  final savedWordsService = SavedWordsService();
  await savedWordsService.initialize();
  debugPrint('✅ SavedWordsService başlatıldı: ${savedWordsService.savedWordsCount} kelime yüklendi');
  
  // CreditsService'i initialize et
  final creditsService = CreditsService();
  await creditsService.initialize();
  debugPrint('✅ CreditsService başlatıldı: ${creditsService.credits} hak, Premium: ${creditsService.isPremium}');
  
  runApp(const KavaidApp());
}

class KavaidApp extends StatefulWidget {
  const KavaidApp({super.key});

  @override
  State<KavaidApp> createState() => _KavaidAppState();
}

class _KavaidAppState extends State<KavaidApp> with WidgetsBindingObserver {
  bool _isDarkMode = false;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // İlk başlatmada App Open reklamını göster (daha uzun gecikme ile - kullanıcı deneyimi için)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_isAppInForeground) {
          AdMobService().showAppOpenAd();
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isAppInForeground) {
          _isAppInForeground = true;
          AdMobService().onAppStateChanged(true);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        AdMobService().onAppStateChanged(false);
        break;
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kavaid - Arapça Sözlük',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainScreen(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF),
        brightness: Brightness.light,
        surface: const Color(0xFFF2F2F7),
        onSurface: const Color(0xFF2C2C2E),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFFF2F2F7),
        foregroundColor: Color(0xFF2C2C2E),
        titleTextStyle: TextStyle(
          color: Color(0xFF2C2C2E),
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFFFFFFF).withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFFD1D1D6),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFFD1D1D6),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFF007AFF),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFFFFFFF).withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: const Color(0xFF8E8E93),
        backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.95),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF),
        brightness: Brightness.dark,
        surface: const Color(0xFF2C2C2E),
        onSurface: const Color(0xFFE5E5EA),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF1C1C1E),
        foregroundColor: Color(0xFFE5E5EA),
        titleTextStyle: TextStyle(
          color: Color(0xFFE5E5EA),
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFF3A3A3C),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFF3A3A3C),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFF007AFF),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 16,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF007AFF),
        unselectedItemColor: Color(0xFF8E8E93),
        backgroundColor: Color(0xFF2C2C2E),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  VoidCallback? _refreshSavedWords;
  bool _showArabicKeyboard = false;
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    
    // İnternet bağlantısını kontrol et
    _checkInitialConnectivity();
    
    // Bağlantı değişikliklerini dinle
    _connectivityService.startListening((hasConnection) {
      debugPrint('📶 Bağlantı durumu değişti: $hasConnection');
      if (mounted) {
        if (!hasConnection) {
          debugPrint('❌ Bağlantı kesildi! Dialog gösterilecek...');
          ConnectivityService.showNoInternetDialog(
            context,
            onRetry: () {
              _checkInitialConnectivity();
            },
          );
        } else {
          debugPrint('✅ Bağlantı geri geldi!');
        }
      }
    });
  }
  
  Future<void> _checkInitialConnectivity() async {
    debugPrint('🔍 İlk bağlantı kontrolü başlatılıyor...');
    final hasConnection = await _connectivityService.hasInternetConnection();
    debugPrint('📱 İlk kontrol sonucu - İnternet var mı: $hasConnection');
    
    if (mounted) {
      if (!hasConnection) {
        debugPrint('❌ İnternet bağlantısı yok! Dialog gösterilecek...');
        // İlk açılışta internet yoksa dialog göster
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ConnectivityService.showNoInternetDialog(
            context,
            onRetry: () {
              debugPrint('🔄 Tekrar dene butonuna basıldı');
              _checkInitialConnectivity();
            },
          );
        });
      } else {
        debugPrint('✅ İnternet bağlantısı mevcut');
      }
    }
  }

  @override
  void dispose() {
    _connectivityService.stopListening();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    // Kaydedilenler sekmesine geçildiğinde listeyi yenile
    if (index == 1 && _refreshSavedWords != null) {
      _refreshSavedWords!();
    }
  }

  void _setArabicKeyboardState(bool show) {
    setState(() {
      _showArabicKeyboard = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            isDarkMode: widget.isDarkMode,
            onThemeToggle: widget.onThemeToggle,
            onArabicKeyboardStateChanged: _setArabicKeyboardState,
          ), // Sözlük
          SavedWordsScreen(
            onRefreshCallback: (callback) => _refreshSavedWords = callback,
          ), // Kaydedilenler
          ProfileScreen(
            isDarkMode: widget.isDarkMode,
            onThemeToggle: widget.onThemeToggle,
          ), // Profil
        ],
      ),
      bottomSheet: _showArabicKeyboard ? null : const BannerAdWidget(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF1C1C1E)
              : Colors.white,
          selectedItemColor: const Color(0xFF007AFF),
          unselectedItemColor: widget.isDarkMode
              ? const Color(0xFF8E8E93)
              : const Color(0xFF8E8E93),
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          elevation: 0,
          iconSize: 24,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Icon(Icons.menu_book_outlined),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Icon(Icons.menu_book),
              ),
              label: 'Sözlük',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Icon(Icons.bookmark_border),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Icon(Icons.bookmark),
              ),
              label: 'Kaydedilenler',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Icon(Icons.person_outline),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Icon(Icons.person),
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// Profil Ekranı
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

  @override
  void initState() {
    super.initState();
    _creditsService.addListener(_updateState);
  }

  @override
  void dispose() {
    _creditsService.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(
                widget.isDarkMode 
                    ? Icons.light_mode_outlined 
                    : Icons.dark_mode_outlined,
                size: 28,
              ),
              onPressed: widget.onThemeToggle,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hak bilgileri kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kullanım Hakları',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_creditsService.isPremium) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Premium',
                                style: TextStyle(
                                  fontSize: 14,
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
                  const SizedBox(height: 16),
                  if (!_creditsService.isPremium) ...[
                    Text(
                      'Kalan Hak: ${_creditsService.credits}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _creditsService.credits <= 10 
                            ? Colors.red 
                            : const Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _creditsService.credits / 50,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _creditsService.credits <= 10 
                            ? Colors.red 
                            : const Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Her kelime detayı görüntülediğinizde 1 hak harcanır.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Sınırsız Erişim',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_creditsService.premiumExpiry != null) ...[
                      Text(
                        'Bitiş Tarihi: ${_creditsService.premiumExpiry!.day}/${_creditsService.premiumExpiry!.month}/${_creditsService.premiumExpiry!.year}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Premium satın al butonu (premium değilse)
          if (!_creditsService.isPremium) ...[
            ElevatedButton.icon(
              onPressed: () async {
                // TODO: Gerçek satın alma işlemi
                // Test için premium aktifleştir
                await _creditsService.activatePremium();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Premium üyelik aktifleştirildi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Premium Al (60 Ay)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Test butonları (Debug modda)
          if (kDebugMode) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Test İşlemleri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await _creditsService.resetCredits();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Haklar sıfırlandı (50 hak)'),
                        ),
                      );
                    }
                  },
                  child: const Text('Hakları Sıfırla'),
                ),
                if (_creditsService.isPremium) ...[
                  OutlinedButton(
                    onPressed: () async {
                      await _creditsService.cancelPremium();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Premium iptal edildi'),
                          ),
                        );
                      }
                    },
                    child: const Text('Premium İptal'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
