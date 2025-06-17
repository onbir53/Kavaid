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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45), // Çok daha kompakt AppBar
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF007AFF),
          ),
          child: SafeArea(
            child: AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 16, // Daha az sol padding
              backgroundColor: Colors.transparent, // Şeffaf arka plan
              foregroundColor: Colors.white, // Beyaz yazı
              title: const Text(
                'Kavaid',
                style: TextStyle(
                  fontSize: 18, // Daha da küçült
                  fontWeight: FontWeight.w600, // Daha hafif
                  letterSpacing: 0.5, // Daha az harf aralığı
                  color: Colors.white, // Beyaz yazı
                ),
              ),
              centerTitle: false, // Sol tarafa yasla
              elevation: 0, // Gölgeyi kaldır
              actions: [
                                  Padding(
                  padding: const EdgeInsets.only(right: 12), // Daha az sağ padding
                  child: IconButton(
                    icon: const Icon(
                      Icons.light_mode_outlined,
                      color: Colors.white, // Beyaz ikon
                      size: 22, // Daha küçük ikon
                    ),
                    onPressed: widget.onThemeToggle,
                    splashRadius: 16, // Daha küçük tap alanı
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ana içerik
          Column(
            children: [
              // Header container - AppBar'dan input alanının altına kadar
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF), // Temada kullanılan mavi renk
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                        textAlign: TextAlign.start, // Sola hizalı
                        textAlignVertical: TextAlignVertical.center, // Dikey ortala
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
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF007AFF),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: widget.isDarkMode 
                              ? const Color(0xFF2C2C2E)
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, 
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchWithAI(),
                                              ),
                        ),
                      
                      // AI ile Ara butonu
                                              if (_showAIButton && !_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 8), // Daha az boşluk
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _searchWithAI,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16), // Daha yüksek
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
                    ],
                  ),
                ),
              ),
              
              // Ana içerik alanı
              Expanded(
                child: _buildMainContent(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
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
      );
    }

    if (_isSearching && _searchResults.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80), // Üst padding artırıldı
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return SearchResultCard(
            word: _searchResults[index],
            onTap: () => _selectWord(_searchResults[index]),
          );
        },
      );
    }

    if (_selectedWord != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80), // Üst padding artırıldı
        child: WordCard(word: _selectedWord!),
      );
    }

    // Kelime bulunamadı durumu
    if (_showNotFound) {
      return const Center(
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
      );
    }

    // Boş durum - görseldeki gibi temiz alan
    return const SizedBox.shrink();
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kavaid Hakkında'),
        content: const Text(
          'Kavaid, AI destekli Arapça-Türkçe sözlük uygulamasıdır.\n\n'
          '🤖 Gemini-2.5-flash-preview ile güçlendirilmiş\n'
          '🔥 Firebase Realtime Database\n'
          '📱 Modern Material Design 3\n'
          '✨ Akıllı kelime önerileri\n\n'
          'Geliştirici: OnBir Software',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
} 