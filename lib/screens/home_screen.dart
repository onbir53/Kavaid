import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/word_model.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart'; // YEREL VERİTABANI SERVİSİ
import '../services/credits_service.dart';
import '../services/turkce_analytics_service.dart';
import '../widgets/word_card.dart';
import '../widgets/search_result_card.dart';
import '../widgets/arabic_keyboard.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/native_ad_widget.dart';
import '../utils/performance_utils.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TemplateType;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import 'package:kavaid/services/connectivity_service.dart';
import 'package:kavaid/services/review_service.dart';
import 'package:kavaid/services/turkce_analytics_service.dart';
import 'package:kavaid/services/sync_service.dart';


class HomeScreen extends StatefulWidget {
  final double bottomPadding;
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final Function(bool)? onArabicKeyboardStateChanged;
  final bool isFirstOpen;
  final VoidCallback? onKeyboardOpened;

  const HomeScreen({
    super.key,
    required this.bottomPadding,
    required this.isDarkMode,
    required this.onThemeToggle,
    this.onArabicKeyboardStateChanged,
    this.isFirstOpen = false,
    this.onKeyboardOpened,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseService _dbService = DatabaseService.instance; // YEREL DB SERVİSİ
  final CreditsService _creditsService = CreditsService();
  
  List<WordModel> _searchResults = [];
  WordModel? _selectedWord;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showAIButton = false;
  bool _showNotFound = false;
  bool _showArabicKeyboard = false;
  StreamSubscription<List<WordModel>>? _searchSubscription;

  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  int _aiSearchClickCount = 0;
  final AdMobService _adMobService = AdMobService();
  final ReviewService _reviewService = ReviewService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();

  @override
  bool get wantKeepAlive => true; // Widget state'ini koru

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    _loadNativeAd();
    _adMobService.loadInterstitialAd(); // Birleştirilmiş yükleme metodunu çağır
    
    // Uygulama açılınca 0.5 saniye bekle sonra focus yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // Önce tüm focusları temizle
          FocusScope.of(context).unfocus();
          
          // Hemen sonra focus ver
          _searchFocusNode.requestFocus();
          debugPrint('🎯 0.5 saniye sonra klavye açıldı');
        }
      });
    });
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchSubscription?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _adMobService.onAppStateChanged(state);
  }

  void _loadNativeAd() {
    // 🚀 PREMIUM KONTROLÜ: Premium kullanıcılar için reklam yükleme.
    if (_creditsService.isPremium || _creditsService.isLifetimeAdsFree) {
      debugPrint('👑 [HomeScreen] Premium/Reklamsız kullanıcı - Native reklam yüklenmeyecek.');
      return;
    }
  
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: AdMobService.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('✅ [HomeScreen] Native ad loaded successfully.');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
            // Yenileme fonksiyonu kaldırıldı.
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('❌ [HomeScreen] Native ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    )..load();
  }

  void _onSearchChanged() {
    // Debounce timer kaldırıldı - harf girildiği anda direkt arama yapılıyor
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    } else {
      setState(() {
        _searchResults = [];
        _selectedWord = null;
        _isSearching = false;
        _showAIButton = false;
        _showNotFound = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _isLoading = true;
      _showAIButton = true; // Her arama sonrası AI butonunu göster
      _showNotFound = false; // "Sonuç bulunamadı" yazısını gösterme
    });

    try {
      debugPrint('🔍 Yerel arama başlatıldı: "$query"');

      // 1. Tüm kelimeleri lokal veritabanından çek
      final allLocalWords = await _dbService.getAllWords();
      debugPrint('📚 Yerel veritabanından ${allLocalWords.length} kelime yüklendi.');


      // 2. Sonuçları uygulama içinde filtrele ve sırala (Eski Firebase mantığı gibi)
      final List<WordModel> results = allLocalWords
          .where((word) => word.searchScore(query) > 0.0)
          .toList();
      
      debugPrint('🔎 Filtreleme sonrası ${results.length} sonuç bulundu.');


      results.sort((a, b) => b.searchScore(query).compareTo(a.searchScore(query)));
      
      // Analytics event'i gönder
      await TurkceAnalyticsService.kelimeArandiNormal(query, results.length);
      
      setState(() {
        _searchResults = results; // Filtrelenmiş ve sıralanmış sonuçları göster
        _isLoading = false;
        _selectedWord = null;
        _showAIButton = true; 
        _showNotFound = false; 
      });
    } catch (e) {
      debugPrint('Yerel Arama hatası: $e');
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _showAIButton = true; // Hata durumunda da AI butonunu göster
        _showNotFound = false;
      });
    }
  }

  Future<void> _selectWord(WordModel word) async {
    // Arapça klavye açıksa kapat
    if (_showArabicKeyboard) {
      setState(() {
        _showArabicKeyboard = false;
      });
      widget.onArabicKeyboardStateChanged?.call(false);
    }
    
    // Analytics event'i gönder
    await TurkceAnalyticsService.kelimeDetayiGoruntulendi(word.kelime);
    
    // Artık hak kontrolü yok, direkt kelimeyi göster
    setState(() {
      _selectedWord = word;
      _searchResults = [];
      _isSearching = false;
      _showAIButton = false;
      _showNotFound = false;
      _searchController.text = word.kelime;
    });
    _searchFocusNode.unfocus();
  }



  Future<void> _searchWithAI() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Arama işlemini arka planda hazırla
      final searchFuture = _performActualAISearch(query, showLoading: false);
      
    // AdMob servisine bir arama isteği olduğunu bildir.
    // Kararı servis verecek.
    await _adMobService.onSearchAdRequest(
        onAdDismissed: () async {
        // Bu blok, reklam gösterilsin veya gösterilmesin her zaman çalışır.
        debugPrint('Arama sonucu gösteriliyor...');
          setState(() => _isLoading = true);
          await searchFuture;
          setState(() => _isLoading = false);
        },
      );
  }

  Future<void> _performActualAISearch(String query, {bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _selectedWord = null;
        _searchResults = [];
        _showAIButton = false;
        _showNotFound = false;
      });
    }

    try {
      debugPrint('🔍 AI ile arama başlatılıyor: $query');
      
      // Önce Firebase'de var mı kontrol et
      final existingWord = await _firebaseService.getWordByName(query);
      if (existingWord != null) {
        debugPrint('📦 Kelime zaten veritabanında mevcut, AI çağrısı yapılmadı: ${existingWord.kelime}');
        setState(() {
          _searchResults = [existingWord];
          _isLoading = false;
          _isSearching = true;
          _showNotFound = false;
        });
        return;
      }
      
      debugPrint('🤖 Kelime veritabanında bulunamadı, AI\'ya soruluyor: $query');
      final aiResult = await _geminiService.searchWord(query);
      
      // AI arama analytics event'i gönder
      await TurkceAnalyticsService.kelimeArandiAI(query, aiResult.bulunduMu);
      
      if (aiResult.bulunduMu) {
        // AI sonucunu Firebase'e kaydetmek yerine SyncService'e gönder
        await _syncService.handleAiFoundWord(aiResult);
        
        setState(() {
          _searchResults = [aiResult];
          _isLoading = false;
          _isSearching = true;
          _showNotFound = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _showAIButton = true;
          _showNotFound = true; // AI arama sonucu bulunamazsa bu flag'i true yap
        });
      }
    } catch (e) {
      debugPrint('❌ AI arama hatası: $e');
      setState(() {
        _isLoading = false;
        _showAIButton = true;
        _showNotFound = true;
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _dismissKeyboard() {
    // Normal klavye açıksa kapat
    if (_searchFocusNode.hasFocus && !_showArabicKeyboard) {
      _searchFocusNode.unfocus();
    }
    // Arapça klavye açıksa kapat
    if (_showArabicKeyboard) {
      setState(() {
        _showArabicKeyboard = false;
      });
      widget.onArabicKeyboardStateChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
    
    // Klavye durumunu kontrol et
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasKeyboard = keyboardHeight > 0;
    
    return PopScope(
      canPop: !_showArabicKeyboard, // Arapça klavye açıkken çıkışı engelle
      onPopInvoked: (didPop) {
        if (_showArabicKeyboard && !didPop) {
          // Arapça klavye açıkken geri tuşuna basıldığında klavyeyi kapat
          setState(() {
            _showArabicKeyboard = false;
          });
          widget.onArabicKeyboardStateChanged?.call(false);
        }
      },
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Ana içerik
          Positioned.fill(
            bottom: 0, // İçerik her zaman en alta kadar uzanacak
            child: GestureDetector(
              onTap: _dismissKeyboard,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification) {
                    _dismissKeyboard();
                  }
                  return false;
                },
                child: RepaintBoundary(
                  child: CustomScrollView(
                    // 🚀 PERFORMANCE: Scroll performans optimizasyonları
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: PerformanceUtils.listCacheExtent, // 🚀 PERFORMANCE: Adaptif cache
                    // 🚀 PERFORMANCE: Scroll optimizasyonu için key
                    key: const PageStorageKey<String>('home_scroll'),
                    slivers: <Widget>[
                      SliverAppBar(
                      backgroundColor: widget.isDarkMode 
                          ? const Color(0xFF1C1C1E)  // Dark tema için siyah
                          : const Color(0xFF007AFF), // Light tema için mavi
                      elevation: 0,
                      pinned: true,
                      floating: true,
                      snap: true,
                      toolbarHeight: 0, // Toolbar'ı gizle
                      expandedHeight: 0, // Genişletilmiş yüksekliği 0 yap
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(56), // Sadece input alanı için yükseklik
                        child: Container(
                          width: double.infinity,
                          color: widget.isDarkMode 
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFF007AFF),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), // Yan padding'leri daha da azalttım (12'den 8'e)
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(4), // 8'den 4'e düşürdüm (daha sert)
                                border: Border.all(
                                  color: widget.isDarkMode
                                      ? const Color(0xFF48484A).withOpacity(0.3)
                                      : const Color(0xFFE5E5EA).withOpacity(0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center, // Ortalama için
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10), // 12'den 10'a düşürdüm
                                    child: Icon(
                                      Icons.search_rounded,
                                      color: widget.isDarkMode
                                          ? const Color(0xFF8E8E93)
                                          : const Color(0xFF8E8E93),
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      alignment: Alignment.center, // TextField'ı dikeyde ortala
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        autofocus: false, // Manuel focus yapacağız
                                        textAlignVertical: TextAlignVertical.center, // Dikey ortalama
                                        style: TextStyle(
                                          fontSize: 16, // 14'ten 16'ya büyüttüm
                                          color: widget.isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1C1C1E),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Kelime ara',
                                          hintStyle: TextStyle(
                                            color: widget.isDarkMode
                                                ? const Color(0xFF8E8E93).withOpacity(0.8)
                                                : const Color(0xFF8E8E93),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          isDense: true, // Daha kompakt
                                          contentPadding: EdgeInsets.zero, // Padding'i sıfırla
                                        ),
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) => _searchWithAI(),
                                        readOnly: _showArabicKeyboard,
                                      ),
                                    ),
                                  ),
                                  // Arapça klavye ikonu - daha belirgin tasarım
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4, left: 4),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _showArabicKeyboard = !_showArabicKeyboard;
                                            if (_showArabicKeyboard) {
                                              _searchFocusNode.unfocus();
                                                                          // Arapça klavye açıldığında analytics event'i gönder
                            TurkceAnalyticsService.arapcaKlavyeKullanildi();
                                            }
                                          });
                                          // Main ekrana klavye durumunu bildir
                                          widget.onArabicKeyboardStateChanged?.call(_showArabicKeyboard);
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          width: 36, // 32'den 36'ya büyüttüm
                                          height: 36, // 32'den 36'ya büyüttüm
                                          decoration: BoxDecoration(
                                            color: _showArabicKeyboard
                                                ? const Color(0xFF007AFF)
                                                : widget.isDarkMode
                                                    ? const Color(0xFF3A3A3C).withOpacity(0.5)
                                                    : const Color(0xFFE5E5EA).withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.keyboard_alt_outlined,
                                            color: _showArabicKeyboard
                                                ? Colors.white
                                                : (widget.isDarkMode
                                                    ? const Color(0xFF8E8E93)
                                                    : const Color(0xFF636366)),
                                            size: 22, // 20'den 22'ye büyüttüm
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchResults = [];
                                              _selectedWord = null;
                                              _isSearching = false;
                                              _showAIButton = false;
                                              _showNotFound = false;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: widget.isDarkMode
                                                  ? Colors.white.withOpacity(0.08)
                                                  : const Color(0xFF8E8E93).withOpacity(0.08),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.clear,
                                              color: widget.isDarkMode
                                                  ? const Color(0xFF8E8E93).withOpacity(0.8)
                                                  : const Color(0xFF8E8E93),
                                              size: 14,
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
                    ),
                    ..._buildMainContentSlivers(),
                  ],
                  ),
                ),
              ),
            ),
          ),
          // Arapça klavye
          if (_showArabicKeyboard)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: widget.isDarkMode 
                    ? const Color(0xFF1C1C1E) 
                    : const Color(0xFFF5F7FB), // Arka plan rengi
                child: SizedBox(
                  height: 280,
                  child: ArabicKeyboard(
                    controller: _searchController,
                    onSearch: _searchWithAI,
                    onClose: () {
                      setState(() {
                        _showArabicKeyboard = false;
                      });
                      // Main ekrana klavye durumunu bildir
                      widget.onArabicKeyboardStateChanged?.call(false);
                    },
                  ),
                ),
              ),
            ),

        ],
      ),
    ), // Scaffold kapanışı
  ); // PopScope kapanışı
  }

  List<Widget> _buildMainContentSlivers() {
    List<Widget> slivers = [];
    
    if (_isLoading) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 180),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF007AFF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aranıyor...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    if (_isSearching) {
      if (_searchResults.isNotEmpty) {
        // Yer tutucu mantığı kaldırıldı, reklam sadece yüklüyse gösterilecek.
        int totalAds = (_isAdLoaded && _nativeAd != null && _searchResults.length >= 3 && !_creditsService.isPremium && !_creditsService.isLifetimeAdsFree) ? 1 : 0;
        const int adPosition = 3;

        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (totalAds == 1 && index == adPosition) {
                    return NativeAdWidget(ad: _nativeAd!);
                  }

                  final itemIndex = (totalAds == 1 && index > adPosition) ? index - 1 : index;
                  if (itemIndex >= _searchResults.length) return const SizedBox.shrink();
                  
                  final word = _searchResults[itemIndex];
                  return RepaintBoundary(
                    key: ValueKey('result_${word.kelime}_$itemIndex'),
                    child: SearchResultCard(
                      word: word,
                      onTap: () => _selectWord(word),
                      onExpand: () {
                        if (_showArabicKeyboard) {
                          setState(() {
                            _showArabicKeyboard = false;
                          });
                          widget.onArabicKeyboardStateChanged?.call(false);
                        }
                      },
                    ),
                  );
                },
                childCount: _searchResults.length + totalAds,
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: false,
                addSemanticIndexes: false,
              ),
            ),
          ),
        );
      }

      // AI ile kelime ara butonu
      if (_showAIButton) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 12, 8, widget.bottomPadding + 20),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF007AFF),
                          const Color(0xFF0051D5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _searchWithAI,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Kelimeyi Ara',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // AI ile arama sonucu bulunamadıysa mesajı göster
                  if (_showNotFound)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Kelime bulunamadı',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.isDarkMode ? Colors.white70 : const Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
      
      return slivers;
    }

    if (_selectedWord != null) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(8, 12, 8, widget.bottomPadding),
          sliver: SliverToBoxAdapter(
            child: RepaintBoundary(
              child: WordCard(
                key: ValueKey('selected_word_${_selectedWord!.kelime}'),
                word: _selectedWord!,
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    // Boş durum - görseldeki gibi temiz alan
    slivers.add(const SliverToBoxAdapter(child: SizedBox.shrink()));
    return slivers;
  }
} 