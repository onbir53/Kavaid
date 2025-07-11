import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'dart:io' show Platform;
import 'services/connectivity_service.dart';
import 'screens/home_screen.dart';
import 'screens/saved_words_screen.dart';
import 'screens/profile_screen.dart';
import 'services/firebase_options.dart';
import 'services/saved_words_service.dart';
import 'services/admob_service.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/native_ad_widget.dart';
import 'services/credits_service.dart';
import 'services/one_time_purchase_service.dart';
import 'services/global_config_service.dart';
import 'utils/performance_utils.dart';
import 'utils/image_cache_manager.dart';
import 'widgets/fps_counter_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/firebase_service.dart';
import 'services/turkce_analytics_service.dart';
import 'models/word_model.dart';
import 'services/app_usage_service.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'services/review_service.dart';
import 'services/sync_service.dart';

// Fontları önbelleğe almak için yardımcı bir fonksiyon
void _precacheFonts() {
  final arapcaTextPainter = TextPainter(
    text: const TextSpan(
      style: TextStyle(fontFamily: 'ScheherazadeNew'),
      text: 'ا', // Herhangi bir Arapça karakter
    ),
    textDirection: TextDirection.rtl,
  )..layout();

  final latinTextPainter = TextPainter(
    text: const TextSpan(
      style: TextStyle(fontFamily: 'Inter'),
      text: 'a', // Herhangi bir Latin karakter
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  debugPrint('✅ Fontlar önbelleğe alındı: ScheherazadeNew & Inter');
}

// Custom ScrollBehavior - overscroll glow efektini kaldırmak için
class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // Glow efektini gösterme
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // YEREL VERİTABANI SENKRONİZASYONU
  // Uygulama başlamadan önce lokal veritabanını Firebase ile senkronize etmeyi dene.
  // Bu işlem arka planda çalışacak ve uygulamanın açılışını engellemeyecektir.
  try {
    await SyncService().initializeLocalDatabase();
    debugPrint('✅ Yerel veritabanı senkronizasyon kontrolü tamamlandı.');
  } catch (e) {
    debugPrint('❌ Yerel veritabanı senkronizasyonu sırasında bir hata oluştu: $e');
  }
  
  // Android sistem seviyesi log'larını filtrele
  if (!kIsWeb && Platform.isAndroid) {
    SystemChannels.platform.setMethodCallHandler(null);
    // Gralloc4 ve Surface debug mesajlarını engelle
    FlutterError.onError = (details) {
      final message = details.toString();
      // Gereksiz sistem log'larını filtrele
      if (message.contains('gralloc4') || 
          message.contains('Surface') || 
          message.contains('FrameEvents') ||
          message.contains('SMPTE 2094-40') ||
          message.contains('lockHardwareCanvas') ||
          message.contains('updateAcquireFence')) {
        return; // Bu log'ları gösterme
      }
      // Diğer hataları normal şekilde göster
      FlutterError.presentError(details);
    };
  }
  
  // 🚀 PERFORMANCE MOD: Engine optimizasyonları
  if (!kIsWeb) {
    // Frame scheduler'ı optimize et
    SchedulerBinding.instance.scheduleWarmUpFrame();
    
    // Raster cache'i optimize et
    SystemChannels.platform.invokeMethod('SystemChrome.setEnabledSystemUI',
        SystemUiOverlay.values.map((e) => e.toString()).toList());
    
    // 🚀 SHADER WARM-UP: İlk açılış jank'ini önle
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Shader'ları önceden derle
      final shaderWarmUp = Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.fill;
      
      // Çeşitli shader kombinasyonlarını tetikle
      for (int i = 0; i < 3; i++) {
        SchedulerBinding.instance.scheduleWarmUpFrame();
      }
      
      debugPrint('🎨 Shader warm-up tamamlandı');
    });
  }
  
  // 🚀 PERFORMANCE MOD: Android yüksek FPS desteği (GELİŞTİRİLMİŞ)
  if (!kIsWeb && Platform.isAndroid) {
    try {
      // Desteklenen tüm display mode'ları al
      final modes = await FlutterDisplayMode.supported;
      debugPrint('📱 Desteklenen tüm ekran modları:');
      for (final mode in modes) {
        debugPrint('   ${mode.width}x${mode.height} @ ${mode.refreshRate}Hz');
      }
      
      // Mevcut aktif mode'u al
      final activeMode = await FlutterDisplayMode.active;
      debugPrint('📊 Mevcut aktif mod: ${activeMode?.width}x${activeMode?.height} @ ${activeMode?.refreshRate}Hz');
      
      // En yüksek refresh rate'i bul (çözünürlük de dikkate alınarak)
      DisplayMode? bestMode;
      double maxRefreshRate = 60.0;
      
      // Önce mevcut çözünürlükte en yüksek refresh rate'i ara
      final currentWidth = activeMode?.width ?? 0;
      final currentHeight = activeMode?.height ?? 0;
      
      for (final mode in modes) {
        // Aynı çözünürlükte daha yüksek refresh rate
        if (mode.width == currentWidth && 
            mode.height == currentHeight && 
            mode.refreshRate > maxRefreshRate) {
          maxRefreshRate = mode.refreshRate;
          bestMode = mode;
        }
      }
      
      // Eğer aynı çözünürlükte bulunamazsa, tüm modlardan en yükseği seç
      if (bestMode == null) {
        for (final mode in modes) {
          if (mode.refreshRate > maxRefreshRate) {
            maxRefreshRate = mode.refreshRate;
            bestMode = mode;
          }
        }
      }
      
      // Uygun olan en yüksek refresh rate'i ayarla
      if (bestMode != null) {
        // Önce high refresh rate'i etkinleştir
        await FlutterDisplayMode.setHighRefreshRate();
        
        // Sonra spesifik modu ayarla
        await FlutterDisplayMode.setPreferredMode(bestMode);
        
        // Ayarın başarılı olup olmadığını kontrol et
        await Future.delayed(const Duration(milliseconds: 100));
        final newActiveMode = await FlutterDisplayMode.active;
        
        if (newActiveMode?.refreshRate == bestMode.refreshRate) {
          debugPrint('✅ YENİLEME HIZI BAŞARIYLA AYARLANDI!');
          debugPrint('🚀 Aktif mod: ${newActiveMode?.width}x${newActiveMode?.height} @ ${newActiveMode?.refreshRate}Hz');
        } else {
          debugPrint('⚠️ Yenileme hızı ayarlanamadı, fallback deneniyor...');
          // Fallback: setHighRefreshRate kullan
          await FlutterDisplayMode.setHighRefreshRate();
        }
        
        // Frame rate'e göre engine'i optimize et
        final finalRefreshRate = newActiveMode?.refreshRate ?? bestMode.refreshRate;
        if (finalRefreshRate >= 120) {
          debugPrint('⚡ 120Hz mod aktif - Ultra performans');
        } else if (finalRefreshRate >= 90) {
          debugPrint('⚡ 90Hz mod aktif - Yüksek performans');
        } else {
          debugPrint('⚡ 60Hz mod aktif - Standart performans');
        }
      } else {
        debugPrint('⚠️ Yüksek refresh rate bulunamadı, 60Hz kullanılıyor');
      }
    } catch (e) {
      debugPrint('❌ Display mode ayarlanamadı: $e');
      // Hata durumunda bile high refresh rate'i dene
      try {
        await FlutterDisplayMode.setHighRefreshRate();
        debugPrint('🔄 Fallback: setHighRefreshRate kullanıldı');
      } catch (fallbackError) {
        debugPrint('❌ Fallback da başarısız: $fallbackError');
      }
    }
  }
  
  // 🚀 PERFORMANCE MOD: iOS ProMotion optimizasyonu
  if (!kIsWeb && Platform.isIOS) {
    debugPrint('🍎 iOS ProMotion aktif - Sistem otomatik adaptasyonu');
    // iOS ProMotion otomatik olarak 120Hz'e kadar çıkabilir
    // Sistem power management'a göre dinamik olarak ayarlanır
  }
  
  // 📱 STATUS BAR: Başlangıç için şeffaf ayar - tema değişikliği main screen'de yapılacak
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        // Başlangıç için şeffaf status bar
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light, // iOS için
        // System navigation bar şeffaf bırak
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    debugPrint('✅ Status bar şeffaf olarak ayarlandı');
  }
  
  // 🚀 PERFORMANCE MOD: Memory ve GC optimizasyonları
  if (!kIsWeb) {
    // Image cache optimizasyonu
    ImageCacheManager.initialize();
    
    // Garbage collection'ı optimize et
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // FPS counter devre dışı - gereksiz debug log'larını önlemek için
      // PerformanceUtils.enableFPSCounter();
      
      // 🚀 PERFORMANCE MOD: Cihaz performansını tespit et
      PerformanceUtils.detectDevicePerformance();
    });
  }
  
  try {
    // Firebase'i başlat (zorunlu) - 10 saniye timeout ile
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⏱️ Firebase başlatma zaman aşımı!');
        throw TimeoutException('Firebase başlatma zaman aşımı');
      },
    );
    debugPrint('✅ Firebase başarıyla başlatıldı');
  } catch (e) {
    debugPrint('❌ Firebase başlatma hatası: $e');
    // Firebase olmadan devam et - offline modda çalışabilir
  }

  // Diğer servisleri arka planda başlat
  _initializeServicesInBackground();
  
  runApp(const KavaidApp());
}

// Servisleri arka planda başlat
void _initializeServicesInBackground() {
  // 🚀 FONT ÖN YÜKLEME: Uygulama başladıktan hemen sonra fontları arka planda belleğe al
  Future.microtask(() {
    _precacheFonts();
  });

  // Firebase Analytics'i ilk olarak başlat
  Future.delayed(const Duration(milliseconds: 50), () async {
    try {
      await TurkceAnalyticsService.uygulamaBaslatildi();
      debugPrint('✅ Türkçe Analytics Service başlatıldı');
    } catch (e) {
      debugPrint('❌ Türkçe Analytics Service başlatılamadı: $e');
    }
  });

  // Önce CreditsService'i başlat (premium kontrolü için)
  Future.delayed(const Duration(milliseconds: 100), () async {
    final creditsService = CreditsService();
    await creditsService.initialize();
    debugPrint('✅ CreditsService başlatıldı: ${creditsService.credits} hak, Premium: ${creditsService.isPremium}');
    
    // CreditsService başlatıldıktan sonra AdMob'u arka planda başlat (uygulamayı engellemez)
    try {
      // AdMob'u 15 saniye zaman aşımı ile başlat. Başarısız olursa veya zaman aşımına uğrarsa,
      // uygulama reklamsız çalışmaya devam eder.
      await AdMobService.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏱️ AdMob başlatma zaman aşımı! Uygulama reklamsız devam edecek.');
          // Hata fırlatmaya gerek yok, sadece logla ve devam et.
        },
      );

      debugPrint('✅ AdMob başarıyla başlatıldı');

      // Test cihazı kimliğini ayarla (sadece debug modunda etkili olur)
      RequestConfiguration configuration = RequestConfiguration(
        testDeviceIds: ['bbffd4ef-bbec-48dd-9123-fac2b36aa283'],
      );
      await MobileAds.instance.updateRequestConfiguration(configuration);
      
      // Premium üye değilse reklamları önden yükle
      if (!creditsService.isPremium && !creditsService.isLifetimeAdsFree) {
        debugPrint('🚀 [MAIN] Interstitial reklam ön-yükleniyor...');
        AdMobService().loadInterstitialAd();
      }
    } catch (e) {
      debugPrint('❌ AdMob başlatılırken bir hata oluştu: $e');
    }
  });

  // SavedWordsService'i arka planda başlat
  Future.delayed(const Duration(milliseconds: 200), () async {
    final savedWordsService = SavedWordsService();
    await savedWordsService.initialize();
    debugPrint('✅ SavedWordsService başlatıldı: ${savedWordsService.savedWordsCount} kelime yüklendi');
  });

  // OneTimePurchaseService'i arka planda başlat
  Future.delayed(const Duration(milliseconds: 300), () async {
    final oneTimePurchaseService = OneTimePurchaseService();
    await oneTimePurchaseService.initialize();
    debugPrint('✅ OneTimePurchaseService başlatıldı - Store: ${oneTimePurchaseService.isAvailable}');
  });
  
  // AppUsageService'i arka planda başlat
  Future.delayed(const Duration(milliseconds: 400), () async {
    final appUsageService = AppUsageService();
    await appUsageService.startSession();
    debugPrint('✅ AppUsageService başlatıldı');
  });
  
  // TTS Service'i arka planda başlat
  Future.delayed(const Duration(milliseconds: 450), () async {
    final ttsService = TTSService();
    await ttsService.initialize();
    debugPrint('✅ TTSService başlatıldı');
  });
  
  // GlobalConfigService'i arka planda başlat
  Future.delayed(const Duration(milliseconds: 500), () async {
    final globalConfigService = GlobalConfigService();
    debugPrint('✅ GlobalConfigService başlatıldı - Subscription disabled: ${globalConfigService.subscriptionDisabled}');
  });
  
  // GeminiService Firebase config oluştur ve test et
  Future.delayed(const Duration(milliseconds: 600), () async {
    try {
      // Firebase config'ini oluştur (varsa dokunmaz)
      await GeminiService.createFirebaseConfig();
      debugPrint('✅ GeminiService Firebase config kontrol edildi');
      
      // API bağlantısını test et
      await GeminiService.testApiConnection();
      debugPrint('✅ GeminiService API testi tamamlandı');
    } catch (e) {
      debugPrint('❌ GeminiService hatası: $e');
    }
  });

  // Değerlendirme servisini başlat
  Future.delayed(const Duration(milliseconds: 700), () async {
    final reviewService = ReviewService();
    await reviewService.initialize();
    debugPrint('✅ ReviewService başlatıldı');
  });
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
  bool _themeLoaded = false;
  final CreditsService _creditsService = CreditsService();
  final AppUsageService _appUsageService = AppUsageService();
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
    
    // Credits service'i başlat ve dinle
    _initializeCreditsService();
    
    // İlk açılışta app open ad gösterme - sadece resume'da göster
    
    // Kullanım süresini periyodik olarak güncelle
    _startUsageTimer();
  }
  
  void _startUsageTimer() {
    // Her dakika kullanım süresini güncelle
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isAppInForeground) {
        _appUsageService.updateUsage();
        debugPrint('⏱️ [AppUsage] Kullanım süresi güncellendi');
      }
    });
  }
  
  Future<void> _initializeCreditsService() async {
    await _creditsService.initialize();
    // Premium durumu değiştiğinde rebuild için dinle
    _creditsService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _creditsService.removeListener(() {});
    _usageTimer?.cancel();
    _appUsageService.endSession();
    
    super.dispose();
  }

  // Tema tercihi yükle
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool(_themeKey) ?? false;
        _themeLoaded = true;
      });
    } catch (e) {
      debugPrint('❌ Tema yükleme hatası: $e');
      // Hata durumunda varsayılan değerle devam et
      setState(() {
        _isDarkMode = false;
        _themeLoaded = true;
      });
    }
  }

  // Tema tercihi kaydet
  Future<void> _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDarkMode);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('🔄 [MAIN] App lifecycle state değişti: $state');
    
    // AdMobService'e lifecycle state'i gönder
    try {
      AdMobService().onAppStateChanged(state);
      debugPrint('✅ [MAIN] AdMobService.onAppStateChanged() başarıyla çağırıldı');
    } catch (e) {
      debugPrint('❌ [MAIN] AdMobService.onAppStateChanged() hatası: $e');
    }
    
    // 🚀 PERFORMANCE MOD: Lifecycle'a göre cache optimizasyonu
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        ImageCacheManager.restoreForForeground();
        
        // Uygulama aktif olduğunda kullanım süresini güncelle
        _appUsageService.updateUsage();
        
        // TEST: 2 saniye sonra debug durumunu göster
        Future.delayed(const Duration(seconds: 2), () {
          debugPrint('🧪 [TEST] 2 saniye sonra debug durumu:');
          AdMobService().debugAdStatus();
        });
        break;
      case AppLifecycleState.paused:
        _isAppInForeground = false;
        ImageCacheManager.optimizeForBackground();
        
        // Uygulama arka plana alındığında oturumu sonlandır
        _appUsageService.endSession();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        break;
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _saveThemePreference(_isDarkMode);
    
    // Analytics event'i gönder
    TurkceAnalyticsService.temaDegistirildi(_isDarkMode ? 'koyu' : 'acik');
  }

  @override
  Widget build(BuildContext context) {
    // Tema yüklenene kadar minimal loading göster
    if (!_themeLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFFF5F7FB), // Yeni mavimsi arka plan
          body: SizedBox.shrink(), // Boş widget, daha hızlı render
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
      builder: (context, child) {
        // 🚀 PERFORMANCE MOD: Yüksek FPS için optimize edilmiş MediaQuery
        final mediaQuery = MediaQuery.of(context);
        
        return MediaQuery(
          data: mediaQuery.copyWith(
            // Performans için optimize edilmiş değerler
            devicePixelRatio: mediaQuery.devicePixelRatio,
            // Text scaling'i stabil tut
            textScaleFactor: mediaQuery.textScaleFactor.clamp(0.8, 1.2),
          ),
          child: ScrollConfiguration(
            // Overscroll glow efektini kaldır - performans artışı sağlar
            behavior: NoGlowScrollBehavior(),
            child: RepaintBoundary(
              // 🚀 PERFORMANCE MOD: Ana uygulama RepaintBoundary ile sarılı
              child: FPSOverlay(
                showFPS: false, // Debug mesajlarını önlemek için tamamen kapalı
                detailedFPS: false,
                child: SafeArea(
                  // 🔧 ANDROID 15 FIX: Global SafeArea - Navigation bar overlap fix
                  bottom: true,
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      fontFamily: 'Inter', // Varsayılan font ailesi
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF),
        brightness: Brightness.light,
        surface: const Color(0xFFF5F7FB), // Daha mavimsi arka plan
        onSurface: const Color(0xFF2C2C2E),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7FB), // Daha mavimsi arka plan
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFFF5F7FB), // Daha mavimsi arka plan
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
        color: const Color(0xFFFFFFFF), // Tam beyaz kartlar daha belirgin olması için
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
        selectedLabelStyle: const TextStyle(fontFamily: 'Inter'), // Font ailesini uygula
        unselectedLabelStyle: const TextStyle(fontFamily: 'Inter'), // Font ailesini uygula
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      fontFamily: 'Inter', // Varsayılan font ailesi
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
        backgroundColor: Color(0xFF1C1C1E), // Karanlık tema için siyah navigation bar
        selectedLabelStyle: TextStyle(fontFamily: 'Inter'), // Font ailesini uygula
        unselectedLabelStyle: TextStyle(fontFamily: 'Inter'), // Font ailesini uygula
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
  bool _isFirstOpen = true;
  final ConnectivityService _connectivityService = ConnectivityService();
  double _bannerHeight = 0; // Dinamik banner yüksekliği için state

  @override
  void initState() {
    super.initState();
    
    // İnternet kontrolünü arka planda yap (başlangıcı yavaşlatmasın)
    Future.delayed(const Duration(milliseconds: 1000), () {
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasSystemKeyboard = keyboardHeight > 0;
    const navBarHeight = 56.0;
    // 🔧 ANDROID 15 FIX: System navigation bar yüksekliğini hesapla
    final systemNavBarHeight = MediaQuery.of(context).viewPadding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        // 📱 STATUS BAR: Tema uyumlu renk ayarları
        statusBarColor: widget.isDarkMode 
            ? const Color(0xFF1C1C1E)  // Dark tema için siyah
            : const Color(0xFF007AFF), // Light tema için ana mavi
        statusBarIconBrightness: widget.isDarkMode 
            ? Brightness.light       // Dark tema için beyaz iconlar
            : Brightness.light,      // Light tema için beyaz iconlar (mavi arka planda)
        statusBarBrightness: widget.isDarkMode 
            ? Brightness.dark        // iOS için - dark tema
            : Brightness.dark,       // iOS için - light tema
        // System navigation bar ayarları
        systemNavigationBarColor: widget.isDarkMode 
            ? const Color(0xFF1C1C1E)  // Dark tema için siyah
            : Colors.white,            // Light tema için beyaz
        systemNavigationBarIconBrightness: widget.isDarkMode ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Ana İçerik
          Positioned.fill(
            child: RepaintBoundary(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  HomeScreen(
                    bottomPadding: _bannerHeight + navBarHeight + systemNavBarHeight,
                    isDarkMode: widget.isDarkMode,
                    onThemeToggle: widget.onThemeToggle,
                    onArabicKeyboardStateChanged: _setArabicKeyboardState,
                    isFirstOpen: _isFirstOpen && _currentIndex == 0,
                    onKeyboardOpened: () {
                      if (_isFirstOpen) setState(() => _isFirstOpen = false);
                    },
                  ),
                  SavedWordsScreen(
                    bottomPadding: _bannerHeight + navBarHeight + systemNavBarHeight,
                    onRefreshCallback: (callback) => _refreshSavedWords = callback,
                  ),
                  ProfileScreen(
                    bottomPadding: _bannerHeight + navBarHeight + systemNavBarHeight,
                    isDarkMode: widget.isDarkMode,
                    onThemeToggle: widget.onThemeToggle,
                  ),
                ],
              ),
            ),
          ),

          // 2. Banner Reklam - RepaintBoundary ile performans optimizasyonu
          Positioned(
            bottom: hasSystemKeyboard
                ? keyboardHeight
                : _showArabicKeyboard
                    ? 280.0
                    : navBarHeight + MediaQuery.of(context).viewPadding.bottom,
            left: 0,
            right: 0,
            height: _bannerHeight,
            child: RepaintBoundary(
              child: BannerAdWidget(
                onAdHeightChanged: (height) {
                  if (mounted && _bannerHeight != height) {
                    setState(() => _bannerHeight = height);
                  }
                },
                key: const ValueKey('main_banner_ad_stable'),
                stableKey: 'main_banner_stable',
              ),
            ),
          ),

          // 3. Bottom Navigation Bar - RepaintBoundary ile performans optimizasyonu
          Positioned(
            bottom: (hasSystemKeyboard || _showArabicKeyboard) ? -navBarHeight : 0,
            left: 0,
            right: 0,
            height: navBarHeight + MediaQuery.of(context).viewPadding.bottom,
            child: RepaintBoundary(
              child: Container(
                // 🔧 ANDROID 15 FIX: System navigation bar padding eklendi
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
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
                  backgroundColor: Colors.transparent, // Arka planı parent container'dan alır
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
                      icon: const Icon(Icons.menu_book_outlined),
                      activeIcon: const Icon(Icons.menu_book),
                      label: 'Sözlük',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.bookmark_border),
                      activeIcon: const Icon(Icons.bookmark),
                      label: 'Kaydedilenler',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline),
                      activeIcon: const Icon(Icons.person),
                      label: 'Profil',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}


