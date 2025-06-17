import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../models/word_model.dart';
import '../services/saved_words_service.dart';
import '../widgets/word_card.dart';
import '../widgets/search_result_card.dart';

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
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 80), // Banner alanında padding
          child: WordCard(word: _selectedWord!),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kaydedilenler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                        size: 48,
                        color: isDarkMode 
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF8E8E93),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz kaydedilen kelime yok',
                        style: TextStyle(
                          fontSize: 14,
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
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 90), // Banner alanında padding
                  itemCount: _savedWords.length,
                  itemBuilder: (context, index) {
                    final word = _savedWords[index];
                    return SearchResultCard(
                      word: word,
                      onTap: () => _selectWord(word),
                    );
                  },
                ),
    );
  }
} 