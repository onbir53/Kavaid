import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/word_model.dart';
import '../widgets/search_result_card.dart';
import '../services/saved_words_service.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback? onSavedWordsTabRequested;

  const MainScreen({
    super.key,
    this.onSavedWordsTabRequested,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SavedWordsService _savedWordsService = SavedWordsService();
  List<WordModel> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _savedWordsService.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Test verisi - yeni veri yapısına göre
    if (query.toLowerCase().contains('تهنئة') || query.toLowerCase().contains('tebrik')) {
      final testWord = WordModel(
        kelime: 'تهنئة',
        harekeliKelime: 'تَهْنِئَةٌ',
        anlam: 'Tebrik, kutlama',
        koku: 'هنا',
        dilbilgiselOzellikler: {
          'tur': 'Mastar',
          'cogulForm': 'تَهَانِئُ'
        },
        fiilCekimler: {
          'maziForm': 'هَنَّأَ',
          'muzariForm': 'يُهَنِّئُ',
          'mastarForm': 'تَهْنِئَةٌ',
          'emirForm': 'هَنِّئْ'
        },
        ornekCumleler: [
          {
            'arapcaCümle': 'أَرْسَلْتُ تَهْنِئَةً بِالنَّجَاحِ.',
            'turkceAnlam': 'Başarı için tebrik mesajı gönderdim.'
          },
          {
            'arapcaCümle': 'تَلَقَّيْتُ تَهْنِئَةً بِالْعِيدِ.',
            'turkceAnlam': 'Bayram tebriği aldım.'
          }
        ],
        bulunduMu: true,
      );

      setState(() {
        _searchResults = [testWord];
        _isLoading = false;
      });
      return;
    }

    // Diğer test verileri...
    final mockResults = [
      WordModel(
        kelime: 'كتاب',
        harekeliKelime: 'كِتَابٌ',
        anlam: 'Kitap',
        koku: 'كتب',
        dilbilgiselOzellikler: {
          'tur': 'İsim',
          'cogulForm': 'كُتُبٌ'
        },
        ornekCumleler: [
          {
            'arapcaCümle': 'قَرَأْتُ الْكِتَابَ.',
            'turkceAnlam': 'Kitabı okudum.'
          }
        ],
        bulunduMu: true,
      ),
      WordModel(
        kelime: 'قرأ',
        harekeliKelime: 'قَرَأَ',
        anlam: 'Okumak',
        koku: 'قرأ',
        dilbilgiselOzellikler: {
          'tur': 'Fiil'
        },
        fiilCekimler: {
          'maziForm': 'قَرَأَ',
          'muzariForm': 'يَقْرَأُ',
          'mastarForm': 'قِرَاءَةٌ',
          'emirForm': 'اِقْرَأْ'
        },
        ornekCumleler: [
          {
            'arapcaCümle': 'يَقْرَأُ الطَّالِبُ الدَّرْسَ.',
            'turkceAnlam': 'Öğrenci dersi okuyor.'
          }
        ],
        bulunduMu: true,
      ),
    ];

    // Basit arama simülasyonu
    final filteredResults = mockResults.where((word) {
      final searchTerm = query.toLowerCase();
      return word.kelime.toLowerCase().contains(searchTerm) ||
             word.harekeliKelime?.toLowerCase().contains(searchTerm) == true ||
             word.anlam?.toLowerCase().contains(searchTerm) == true;
    }).toList();

    // Arama sonuçlarını skorlayarak sırala
    filteredResults.sort((a, b) => b.searchScore(query).compareTo(a.searchScore(query)));

    setState(() {
      _searchResults = filteredResults;
      _isLoading = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isLoading = false;
    });
  }

  void _selectWord(WordModel word) {
    // Kelime seçildiğinde yapılacak işlemler
    print('Kelime seçildi: ${word.kelime}');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode 
          ? const Color(0xFF000000) 
          : const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // Başlık ve arama çubuğu
            Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  // Başlık
                  Text(
                    'Kavaid',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Arama çubuğu
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? const Color(0xFF1C1C1E) 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode 
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFE5E5EA),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode 
                              ? Colors.black.withOpacity(0.15)
                              : Colors.black.withOpacity(0.02),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _performSearch,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Arapça kelime veya Türkçe anlam ara...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6D6D70),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6D6D70),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: _clearSearch,
                                icon: Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: isDarkMode 
                                      ? const Color(0xFF8E8E93)
                                      : const Color(0xFF6D6D70),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Arama sonuçları
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF007AFF),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 48,
                                color: isDarkMode 
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF6D6D70),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Aramaya başlamak için kelime yazın'
                                    : 'Sonuç bulunamadı',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode 
                                      ? const Color(0xFF8E8E93)
                                      : const Color(0xFF6D6D70),
                                ),
                              ),
                              if (_searchController.text.isEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Test için "تهنئة" veya "tebrik" yazın',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode 
                                        ? const Color(0xFF8E8E93)
                                        : const Color(0xFF6D6D70),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final word = _searchResults[index];
                            return SearchResultCard(
                              word: word,
                              onTap: () => _selectWord(word),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
} 