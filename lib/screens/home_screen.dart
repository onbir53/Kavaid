import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/word_model.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../services/credits_service.dart';
import '../widgets/word_card.dart';
import '../widgets/search_result_card.dart';
import '../widgets/arabic_keyboard.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/native_ad_widget.dart';


class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final Function(bool)? onArabicKeyboardStateChanged;
  final bool isFirstOpen;
  final VoidCallback? onKeyboardOpened;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    this.onArabicKeyboardStateChanged,
    this.isFirstOpen = false,
    this.onKeyboardOpened,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();
  final CreditsService _creditsService = CreditsService();
  
  List<WordModel> _searchResults = [];
  WordModel? _selectedWord;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showAIButton = false;
  bool _showNotFound = false;
  bool _showArabicKeyboard = false;
  Timer? _debounceTimer;
  StreamSubscription<List<WordModel>>? _searchSubscription;

  @override
  bool get wantKeepAlive => true; // Widget state'ini koru

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // İlk açılışta klavyeyi aç - daha güçlü yöntem
    if (widget.isFirstOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && widget.isFirstOpen) {
            // Daha güçlü focus yöntemi
            FocusScope.of(context).requestFocus(_searchFocusNode);
            // Klavyeyi açmak için ekstra try
            _searchFocusNode.requestFocus();
            widget.onKeyboardOpened?.call();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _searchSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
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
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _isLoading = true;
      _showAIButton = false;
      _showNotFound = false;
    });

    try {
      final results = await _firebaseService.searchWords(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
        _selectedWord = null;
        _showAIButton = results.isEmpty; // Sonuç yoksa AI butonunu göster
        _showNotFound = false;
      });
    } catch (e) {
      debugPrint('Arama hatası: $e');
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
    
    // Önce hak kontrolü yap
    final canOpen = await _creditsService.canOpenWord(word.kelime);
    
    if (!canOpen) {
      // Hak yetersiz - Dialog göster
      _showNoCreditsDialog();
      return;
    }
    
    // Hak düşür
    final success = await _creditsService.consumeCredit(word.kelime);
    
    if (!success) {
      _showNoCreditsDialog();
      return;
    }
    
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

  void _showNoCreditsDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.credit_card_off,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Hakkınız Bitti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _creditsService.hasInitialCredits
                  ? '50 ücretsiz hakkınız bitmiştir. Günlük yenilenen 5 hak ile devam edebilir veya Premium\'a yükselterek sınırsız erişim kazanabilirsiniz.'
                  : 'Günlük 5 hakkınız bitmiştir. Yarın saat 00:00\'da yeni haklarınız yüklenecektir.',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Premium üyelik ile sınırsız kelime detaylarına ve reklamsız deneyime erişebilirsiniz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF007AFF),
                        fontWeight: FontWeight.w500,
                      ),
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
            child: Text(
              'Kapat',
              style: TextStyle(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Main screen'deki tab controller'a erişim gerekiyor
              // Parent widget'tan callback veya state management ile çözülmeli
              // Şimdilik basit bir çözüm
              final tabController = DefaultTabController.of(context);
              if (tabController != null) {
                tabController.animateTo(2); // Profil sekmesi
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
            ),
            child: const Text('Premium\'a Bak'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchWithAI() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _selectedWord = null;
      _searchResults = [];
      _showAIButton = false;
      _showNotFound = false;
    });

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
      
      if (aiResult.bulunduMu) {
        // AI sonucunu Firebase'e kaydet
        await _firebaseService.saveWord(aiResult);
        
        setState(() {
          _searchResults = [aiResult]; // AI sonucunu arama sonuçları listesine ekle
          _isLoading = false;
          _isSearching = true; // Arama sonuçları modunu aktif et
          _showNotFound = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _showAIButton = true;
          _showNotFound = true; // Bulunamadı mesajını göster
        });
      }
    } catch (e) {
      debugPrint('❌ AI arama hatası: $e');
      setState(() {
        _isLoading = false;
        _showAIButton = true;
        _showNotFound = true; // Hata durumunda da bulunamadı göster
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
    
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
            bottom: _showArabicKeyboard 
                ? 330 // Arapça klavye (280) + Banner (50)
                : 0, // Normal durumda main.dart banner ve navbar'ı hallediyor
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
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
                return false;
              },
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                    backgroundColor: widget.isDarkMode 
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFF007AFF),
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
                              boxShadow: [
                                BoxShadow(
                                  color: widget.isDarkMode
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ],
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
                                      autofocus: true,
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
                                          boxShadow: _showArabicKeyboard ? [
                                            BoxShadow(
                                              color: const Color(0xFF007AFF).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ] : null,
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
                    flexibleSpace: Container(
                      decoration: BoxDecoration(
                        gradient: widget.isDarkMode
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
                            color: widget.isDarkMode
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFF007AFF).withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._buildMainContentSlivers(),
                ],
              ),
            ),
          ),
          // Arapça klavye
          if (_showArabicKeyboard)
            Positioned(
              bottom: 0, // En altta
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Banner klavyenin üstünde
                  const BannerAdWidget(
                    key: ValueKey('keyboard_banner_ad'),
                    stableKey: 'keyboard_banner',
                  ),
                  // Klavye
                  SizedBox(
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
                ],
              ),
            ),
        ],
      ),
    ), // Scaffold kapanışı
  ); // PopScope kapanışı
  }

  List<Widget> _buildMainContentSlivers() {
    List<Widget> slivers = [];
    
    if (_showAIButton && !_isLoading) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF007AFF),
                    const Color(0xFF0051D5),
                  ],
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
                        Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ara',
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
          ),
        ),
      );
    }
    
    if (_isLoading) {
      slivers.add(
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF007AFF),
                ),
                SizedBox(height: 16),
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
      );
      return slivers;
    }

    if (_isSearching && _searchResults.isNotEmpty) {
      // Native reklam gösterme mantığı
      final int adFrequency = 7; // Her 7 sonuçtan sonra 1 reklam
      final int totalAds = _searchResults.length >= 5 ? (_searchResults.length ~/ adFrequency).clamp(0, 2) : 0; // En fazla 2 reklam, en az 5 sonuç varsa göster
      final int totalItems = _searchResults.length + totalAds;
      
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Reklam pozisyonlarını hesapla
                final int adsBefore = totalAds > 0 ? (index / (adFrequency + 1)).floor() : 0;
                final bool isAdPosition = totalAds > 0 && 
                    adsBefore < totalAds && 
                    (index + 1) % (adFrequency + 1) == 0;
                
                if (isAdPosition) {
                  // Native reklam göster
                  return const NativeAdWidget();
                } else {
                  // Normal arama sonucu
                  final int actualIndex = index - adsBefore;
                  if (actualIndex < _searchResults.length) {
                    return SearchResultCard(
                      word: _searchResults[actualIndex],
                      onTap: () => _selectWord(_searchResults[actualIndex]),
                    );
                  }
                }
                return null;
              },
              childCount: totalItems,
            ),
          ),
        ),
      );
      return slivers;
    }

    if (_selectedWord != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 80),
          sliver: SliverToBoxAdapter(
            child: WordCard(word: _selectedWord!),
          ),
        ),
      );
      return slivers;
    }

    if (_showNotFound) {
      slivers.add(
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Color(0xFF8E8E93),
                ),
                SizedBox(height: 16),
                Text(
                  'Kelime bulunamadı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
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