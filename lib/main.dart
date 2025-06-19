import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/connectivity_service.dart';
import 'screens/home_screen.dart';
import 'screens/saved_words_screen.dart';
import 'screens/profile_screen.dart';
import 'services/firebase_options.dart';
import 'services/saved_words_service.dart';
import 'services/admob_service.dart';
import 'widgets/banner_ad_widget.dart';
import 'services/credits_service.dart';
import 'services/subscription_service.dart';

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
  
  // SubscriptionService'i initialize et
  final subscriptionService = SubscriptionService();
  await subscriptionService.initialize();
  debugPrint('✅ SubscriptionService başlatıldı');
  
  runApp(const KavaidApp());
}

class KavaidApp extends StatefulWidget {
  const KavaidApp({super.key});

  @override
  State<KavaidApp> createState() => _KavaidAppState();
}

class _KavaidAppState extends State<KavaidApp> with WidgetsBindingObserver {
  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = false;
  bool _isAppInForeground = true;
  bool _isFirstLaunch = true;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
    
    // İlk açılışta app open ad gösterme - sadece resume'da göster
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Tema tercihi yükle
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      _themeLoaded = true;
    });
  }

  // Tema tercihi kaydet
  Future<void> _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDarkMode);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isAppInForeground) {
          _isAppInForeground = true;
          AdMobService().onAppStateChanged(true);
          
          // Sadece ilk açılış değilse app open ad göster
          if (!_isFirstLaunch) {
            debugPrint('📱 Uygulama geri döndü - App Open Ad gösteriliyor');
            AdMobService().showAppOpenAd();
          } else {
            _isFirstLaunch = false;
            debugPrint('📱 İlk açılış - App Open Ad gösterilmiyor');
          }
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
    _saveThemePreference(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    // Tema yüklenene kadar loading göster
    if (!_themeLoaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF007AFF),
            ),
          ),
        ),
      );
    }

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
  bool _isFirstOpen = true; // İlk açılış kontrolü için
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

    // İlk açılış durumunu sıfırla (sekme değişiminde)
    if (_isFirstOpen && index != 0) {
      _isFirstOpen = false;
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
            isFirstOpen: _isFirstOpen && _currentIndex == 0,
            onKeyboardOpened: () {
              if (_isFirstOpen) {
                setState(() {
                  _isFirstOpen = false;
                });
              }
            },
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
      bottomSheet: _showArabicKeyboard ? null : const BannerAdWidget(
        key: ValueKey('main_banner_ad'),
        stableKey: 'main_banner',
      ),
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


