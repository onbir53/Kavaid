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
import '../utils/performance_utils.dart';


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

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
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
    
    // Uygulama açıldığında klavyeyi aç
    // Hem immediate hem delayed focus
    _searchFocusNode.requestFocus();
    
    // Multiple attempts with increasing delays
    for (int i = 1; i <= 5; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted && !_searchFocusNode.hasFocus) {
          FocusScope.of(context).requestFocus(_searchFocusNode);
          _searchFocusNode.requestFocus();
          if (i == 5) {
            // Son denemede callback'i çağır
            widget.onKeyboardOpened?.call();
          }
        }
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
    // 🚀 PERFORMANCE: Adaptif debounce süresi
    _debounceTimer = Timer(PerformanceUtils.searchDebounce, () {
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
      // Tüm sonuçları al, limit yok
      final results = await _firebaseService.searchWords(query, limit: 999); // Limit ekledim
      setState(() {
        _searchResults = results; // Tüm sonuçlar gösterilecek
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
              child: RepaintBoundary(
                child: CustomScrollView(
                  // 🚀 PERFORMANCE: Scroll performans optimizasyonları
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: PerformanceUtils.listCacheExtent, // 🚀 PERFORMANCE: Adaptif cache
                  // 🚀 PERFORMANCE: Scroll optimizasyonu için key
                  key: const PageStorageKey<String>('home_scroll'),
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
    
    if (_showAIButton && !_isLoading) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(12),
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
      final int minCardsBeforeAd = 5; // En az 5 kart geçildikten sonra reklam göster
      final int adFrequency = 10; // Her 10 sonuçtan sonra 1 reklam
      
      // Reklam pozisyonlarını hesapla
      final List<int> adPositions = [];
      if (_searchResults.length > minCardsBeforeAd) {
        // İlk reklam 5. pozisyonda (5 kart sonra)
        int nextAdPosition = minCardsBeforeAd;
        while (nextAdPosition < _searchResults.length) {
          adPositions.add(nextAdPosition);
          nextAdPosition += adFrequency + 1; // 10 kart + 1 reklam
        }
      }
      
      final int totalAds = adPositions.length;
      
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(8, 12, 8, widget.bottomPadding),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Mevcut pozisyonda kaç reklam gösterilmiş
                int adsShown = adPositions.where((pos) => pos <= index).length;
                int actualIndex = index - adsShown;
                
                // Bu pozisyonda reklam gösterilmeli mi?
                if (adPositions.contains(index)) {
                  return RepaintBoundary(
                    key: ValueKey('ad_$index'),
                    child: const NativeAdWidget(),
                  );
                }
                
                // Normal arama sonucu
                if (actualIndex < _searchResults.length) {
                  final word = _searchResults[actualIndex];
                  return RepaintBoundary(
                    key: ValueKey('result_${word.kelime}_$actualIndex'),
                    child: SearchResultCard(
                      word: word,
                      onTap: () => _selectWord(word),
                      onExpand: () {
                        // Arapça klavye açıksa kapat
                        if (_showArabicKeyboard) {
                          setState(() {
                            _showArabicKeyboard = false;
                          });
                          widget.onArabicKeyboardStateChanged?.call(false);
                        }
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              childCount: _searchResults.length + totalAds,
              // 🚀 PERFORMANCE: Widget state'lerini koruma ve RepaintBoundary'leri kapat
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              // 🚀 PERFORMANCE: Semantic index'leri kapat
              addSemanticIndexes: false,
              findChildIndexCallback: (Key key) {
                if (key is ValueKey) {
                  final value = key.value as String;
                  if (value.startsWith('ad_')) {
                    return int.tryParse(value.substring(3));
                  } else if (value.startsWith('result_')) {
                    // Actual index'i bul
                    for (int i = 0; i < _searchResults.length + totalAds; i++) {
                      int adsShown = adPositions.where((pos) => pos <= i).length;
                      int actualIndex = i - adsShown;
                      if (actualIndex >= 0 && actualIndex < _searchResults.length) {
                        final word = _searchResults[actualIndex];
                        if (value == 'result_${word.kelime}_$actualIndex') {
                          return i;
                        }
                      }
                    }
                  }
                }
                return null;
              },
            ),
          ),
        ),
      );
      
      slivers.add(
        const SliverToBoxAdapter(
          child: SizedBox(height: 100), // Scroll performance için buffer
        ),
      );
      
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