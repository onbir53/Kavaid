import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/word_model.dart';
import '../services/saved_words_service.dart';
import '../widgets/word_card.dart';

class SavedWordsScreen extends StatefulWidget {
  final Function(VoidCallback)? onRefreshCallback;
  
  const SavedWordsScreen({
    super.key,
    this.onRefreshCallback,
  });

  @override
  State<SavedWordsScreen> createState() => _SavedWordsScreenState();
}

class _SavedWordsScreenState extends State<SavedWordsScreen> with AutomaticKeepAliveClientMixin {
  final SavedWordsService _savedWordsService = SavedWordsService();
  List<WordModel> _savedWords = [];
  bool _isLoading = true;
  WordModel? _selectedWord;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSavedWords();
    
    // SavedWordsService'i dinle
    _savedWordsService.addListener(_loadSavedWords);
    
    // Callback'i parent'a gönder
    if (widget.onRefreshCallback != null) {
      widget.onRefreshCallback!(_loadSavedWords);
    }
  }

  @override
  void dispose() {
    // Listener'ı kaldır
    _savedWordsService.removeListener(_loadSavedWords);
    super.dispose();
  }

  // Screen'e her gelindiğinde listeyi yenile
  void refreshList() {
    _loadSavedWords();
  }

  Future<void> _loadSavedWords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final savedWords = await _savedWordsService.getSavedWords();
      if (mounted) {
        setState(() {
          _savedWords = savedWords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeWord(WordModel word) async {
    try {
      final success = await _savedWordsService.removeWord(word);
      if (success) {
        await _loadSavedWords(); // Listeyi yenile
      }
    } catch (e) {
      print('Kelime kaldırma hatası: $e');
    }
  }

  Future<void> _clearAllWords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tümünü Temizle'),
        content: const Text('Tüm kaydedilen kelimeleri silmek istediğinizden emin misiniz?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _savedWordsService.clearAllSavedWords();
        await _loadSavedWords();
      } catch (e) {
        print('Tüm kelimeleri temizleme hatası: $e');
      }
    }
  }

  void _selectWord(WordModel word) {
    setState(() {
      _selectedWord = word;
    });
  }

  void _goBackToList() {
    setState(() {
      _selectedWord = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_selectedWord != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kelime Detayı'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackToList,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: WordCard(word: _selectedWord!),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydedilenler'),
        actions: [
          if (_savedWords.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllWords,
              tooltip: 'Tümünü Temizle',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF007AFF),
              ),
            )
          : _savedWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: isDarkMode 
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF8E8E93),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz kaydedilen kelime yok',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _savedWords.length,
                  itemBuilder: (context, index) {
                    final word = _savedWords[index];
                    return _buildSavedWordCard(word, isDarkMode);
                  },
                ),
    );
  }

  Widget _buildSavedWordCard(WordModel word, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _selectWord(word),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF1C1C1E) 
                : Colors.white,
            borderRadius: BorderRadius.circular(6),
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
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Arapça kelime
                        Text(
                          word.harekeliKelime?.isNotEmpty == true 
                              ? word.harekeliKelime! 
                              : word.kelime,
                          style: GoogleFonts.amiri(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(width: 8),
                        // Kelime türü
                        if (word.dilbilgiselOzellikler?.containsKey('tur') == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              word.dilbilgiselOzellikler!['tur'].toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Türkçe anlam
                    if (word.anlam?.isNotEmpty == true) ...[
                      Text(
                        word.anlam!,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93) 
                              : const Color(0xFF6D6D70),
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Silme tuşu
              InkWell(
                onTap: () => _removeWord(word),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.bookmark,
                    color: const Color(0xFF007AFF),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Açılır menü ikonu
              Icon(
                Icons.keyboard_arrow_right,
                color: isDarkMode ? Colors.white54 : const Color(0xFF8E8E93),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 