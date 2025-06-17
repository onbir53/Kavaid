import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/word_model.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../widgets/word_card.dart';
import '../widgets/search_result_card.dart';


class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
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
  Timer? _debounceTimer;
  StreamSubscription<List<WordModel>>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Uygulama açıldığında klavyeyi otomatik aç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
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
      resizeToAvoidBottomInset: true,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            pinned: true,
            floating: true,
            automaticallyImplyLeading: false,
            title: const Text(
              'Kavaid',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: const Icon(Icons.light_mode_outlined, size: 22),
                  onPressed: widget.onThemeToggle,
                  splashRadius: 16,
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textAlign: TextAlign.start,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'Arapça veya Türkçe kelime ara',
                        hintStyle: TextStyle(
                          color: widget.isDarkMode
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6D6D70),
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: widget.isDarkMode
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6D6D70),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: widget.isDarkMode
                                      ? const Color(0xFF8E8E93)
                                      : const Color(0xFF6D6D70),
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _selectedWord = null;
                                    _isSearching = false;
                                    _showAIButton = false;
                                    _showNotFound = false;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: widget.isDarkMode
                              ? const BorderSide(color: Colors.white, width: 1.0)
                              : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: widget.isDarkMode
                              ? const BorderSide(color: Colors.white, width: 1.0)
                              : BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.white,
                            width: 2.5,
                          ),
                        ),
                        filled: true,
                        fillColor: widget.isDarkMode
                            ? const Color(0xFF2C2C2E)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchWithAI(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ..._buildMainContentSlivers(),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searchWithAI,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: const Color(0xFF007AFF).withOpacity(0.3),
                ),
                child: const Text(
                  'Ara',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return SearchResultCard(
                  word: _searchResults[index],
                  onTap: () => _selectWord(_searchResults[index]),
                );
              },
              childCount: _searchResults.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    if (_selectedWord != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
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