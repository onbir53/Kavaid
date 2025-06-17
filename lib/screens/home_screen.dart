import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/word_model.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../widgets/word_card.dart';
import '../widgets/search_result_card.dart';
import '../widgets/arabic_keyboard.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/native_ad_widget.dart';


class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final Function(bool)? onArabicKeyboardStateChanged;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    this.onArabicKeyboardStateChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();
  
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
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Widget build edildikten sonra otomatik olarak klavyeyi aç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Kısa bir gecikme ekleyerek klavyenin açılmasını garanti altına al
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    });
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
    return Scaffold(
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
                  if (_searchFocusNode.hasFocus && !_showArabicKeyboard) {
                    _searchFocusNode.unfocus();
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
                    toolbarHeight: 56,
                    title: Text(
                      'Kavaid',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onThemeToggle,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Icon(
                                widget.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(64),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: widget.isDarkMode
                                ? const Color(0xFF2C2C2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: widget.isDarkMode
                                      ? const Color(0xFF8E8E93)
                                      : const Color(0xFF8E8E93),
                                  size: 22,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  autofocus: true,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: widget.isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1C1C1E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Arapça veya Türkçe kelime ara',
                                    hintStyle: TextStyle(
                                      color: widget.isDarkMode
                                          ? const Color(0xFF8E8E93).withOpacity(0.8)
                                          : const Color(0xFF8E8E93),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.only(
                                      top: 16,
                                      bottom: 16,
                                      right: _searchController.text.isNotEmpty ? 72 : 40,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _searchWithAI(),
                                  readOnly: _showArabicKeyboard,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: GestureDetector(
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
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _showArabicKeyboard
                                          ? const Color(0xFF007AFF).withOpacity(0.1)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.keyboard_alt_outlined,
                                      color: _showArabicKeyboard
                                          ? const Color(0xFF007AFF)
                                          : (widget.isDarkMode
                                              ? const Color(0xFF8E8E93).withOpacity(0.8)
                                              : const Color(0xFF8E8E93)),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
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
                                    child: Container(
                                      width: 32,
                                      height: 32,
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
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                  const BannerAdWidget(),
                  // Klavye
                  SizedBox(
                    height: 280,
                    child: ArabicKeyboard(
                      controller: _searchController,
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
    );
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
                color: widget.isDarkMode
                    ? const Color(0xFF007AFF).withOpacity(0.15)
                    : const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDarkMode
                      ? const Color(0xFF007AFF).withOpacity(0.3)
                      : const Color(0xFF007AFF).withOpacity(0.2),
                  width: 0.5,
                ),
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
                          color: widget.isDarkMode
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF007AFF).withOpacity(0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ara',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.isDarkMode
                                ? const Color(0xFF007AFF)
                                : const Color(0xFF007AFF).withOpacity(0.9),
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
                  'Bulunamadı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Kelime bulunamadı. Farklı bir kelime deneyin.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
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